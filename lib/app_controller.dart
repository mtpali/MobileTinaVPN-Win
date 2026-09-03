import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/app_settings.dart';
import 'models/server_profile.dart';
import 'models/subscription.dart';
import 'services/latency_service.dart';
import 'services/portable_store.dart';
import 'services/subscription_parser.dart';
import 'services/subscription_service.dart';
import 'services/windows_platform_service.dart';
import 'services/xray_core_service.dart';

enum VpnConnectionState { disconnected, testing, connecting, connected, failed }

class AppController extends ChangeNotifier {
  AppController({
    PortableStore? store,
    WindowsPlatformService? platform,
    SubscriptionService? subscriptionService,
    SubscriptionParser subscriptionParser = const SubscriptionParser(),
    LatencyService latencyService = const LatencyService(),
  })  : store = store ?? PortableStore(),
        platform = platform ?? WindowsPlatformService(),
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _subscriptionParser = subscriptionParser,
        _latencyService = latencyService {
    core = XrayCoreService(store: this.store, platform: this.platform);
    core.onUnexpectedExit = _handleUnexpectedCoreExit;
  }

  final PortableStore store;
  final WindowsPlatformService platform;
  final SubscriptionService _subscriptionService;
  final SubscriptionParser _subscriptionParser;
  final LatencyService _latencyService;
  late final XrayCoreService core;

  AppSettings settings = const AppSettings();
  List<Subscription> subscriptions = <Subscription>[];
  String? selectedServerId;
  VpnConnectionState connectionState = VpnConnectionState.disconnected;
  String? errorMessage;
  DateTime? connectedAt;
  bool initialized = false;

  List<ServerProfile> get servers => subscriptions
      .expand((Subscription item) => item.servers)
      .toList(growable: false);

  ServerProfile? get selectedServer {
    final String? id = selectedServerId;
    if (id == null) return null;
    for (final ServerProfile server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  Subscription? get selectedSubscription {
    final String? id = selectedServerId;
    if (id == null) return subscriptions.firstOrNull;
    for (final Subscription subscription in subscriptions) {
      if (subscription.servers.any((ServerProfile item) => item.id == id)) {
        return subscription;
      }
    }
    return subscriptions.firstOrNull;
  }

  Subscription? subscriptionForServer(String serverId) {
    for (final Subscription subscription in subscriptions) {
      if (subscription.containsServer(serverId)) return subscription;
    }
    return null;
  }

  bool isServerExpired(String serverId) {
    return subscriptionForServer(serverId)?.isExpired ?? false;
  }

  bool get isBusy => connectionState == VpnConnectionState.testing ||
      connectionState == VpnConnectionState.connecting;

  Future<void> initialize() async {
    platform.initialize();
    platform.onTrayExit = shutdown;
    await core.recoverInterruptedSession();
    final StoredState loaded = await store.load();
    settings = loaded.settings;
    subscriptions = loaded.subscriptions;
    subscriptions = subscriptions.map((Subscription subscription) {
      if (!subscription.isExpired) return subscription;
      return subscription.copyWith(
        servers: subscription.servers
            .map((ServerProfile server) => server.copyWith(clearLatency: true))
            .toList(),
      );
    }).toList();
    selectedServerId = loaded.selectedServerId;
    if (selectedServer == null) selectedServerId = servers.firstOrNull?.id;
    initialized = true;
    notifyListeners();
  }

  Future<void> addSubscription({
    required String name,
    required String url,
  }) async {
    final Subscription fresh = await _subscriptionService.fetch(
      name: name,
      url: url,
    );
    final int existing = subscriptions.indexWhere(
      (Subscription item) => item.id == fresh.id,
    );
    if (existing >= 0) {
      subscriptions = <Subscription>[
        ...subscriptions.take(existing),
        fresh,
        ...subscriptions.skip(existing + 1),
      ];
    } else {
      subscriptions = <Subscription>[...subscriptions, fresh];
    }
    selectedServerId ??= fresh.servers.first.id;
    await _persist();
    notifyListeners();
  }

  Future<int> importServersFromClipboard(String contents) async {
    final String payload = contents.trim();
    if (payload.isEmpty) {
      throw const SubscriptionException('کلیپ‌بورد خالی است.');
    }

    final Uri? uri = Uri.tryParse(payload);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        !payload.contains(RegExp(r'[\r\n]'))) {
      await addSubscription(name: 'اشتراک کلیپ‌بورد', url: payload);
      return subscriptions
          .firstWhere((Subscription item) => item.url == uri.toString())
          .servers
          .length;
    }

    final SubscriptionParseResult parsed = _subscriptionParser.parse(payload);
    if (parsed.servers.isEmpty) {
      throw const SubscriptionException(
        'هیچ لینک سرور پشتیبانی‌شده‌ای در کلیپ‌بورد پیدا نشد.',
      );
    }

    const String localId = 'local-clipboard';
    final int index = subscriptions.indexWhere(
      (Subscription item) => item.id == localId,
    );
    final List<ServerProfile> previous =
        index < 0 ? <ServerProfile>[] : subscriptions[index].servers;
    final Map<String, ServerProfile> merged = <String, ServerProfile>{
      for (final ServerProfile server in previous) server.id: server,
      for (final ServerProfile server in parsed.servers) server.id: server,
    };
    final Subscription local = Subscription(
      id: localId,
      name: 'سرورهای کلیپ‌بورد',
      url: '',
      servers: merged.values.toList(growable: false),
      updatedAt: DateTime.now(),
    );
    if (index < 0) {
      subscriptions = <Subscription>[...subscriptions, local];
    } else {
      subscriptions = <Subscription>[
        ...subscriptions.take(index),
        local,
        ...subscriptions.skip(index + 1),
      ];
    }
    selectedServerId ??= parsed.servers.first.id;
    await _persist();
    notifyListeners();
    return parsed.servers.length;
  }

  Future<void> updateSubscription(String id) async {
    final int index = subscriptions.indexWhere(
      (Subscription item) => item.id == id,
    );
    if (index < 0) return;
    final Subscription current = subscriptions[index];
    if (!current.isRemote) return;
    final Subscription fresh = await _subscriptionService.fetch(
      name: current.name,
      url: current.url,
    );
    subscriptions = <Subscription>[
      ...subscriptions.take(index),
      fresh,
      ...subscriptions.skip(index + 1),
    ];
    if (selectedServer == null) selectedServerId = fresh.servers.first.id;
    await _persist();
    notifyListeners();
  }

  Future<void> updateAllSubscriptions() async {
    for (final Subscription subscription in List<Subscription>.from(
      subscriptions,
    )) {
      if (!subscription.isRemote) continue;
      await updateSubscription(subscription.id);
    }
  }

  Future<void> removeSubscription(String id) async {
    if (connectionState == VpnConnectionState.connected) await disconnect();
    subscriptions = subscriptions
        .where((Subscription item) => item.id != id)
        .toList(growable: false);
    if (selectedServer == null) selectedServerId = servers.firstOrNull?.id;
    await _persist();
    notifyListeners();
  }

  Future<void> selectServer(String id) async {
    if (isBusy || connectionState == VpnConnectionState.connected) return;
    selectedServerId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> testServers() async {
    if (servers.isEmpty || isBusy || connectionState == VpnConnectionState.connected) {
      return;
    }
    connectionState = VpnConnectionState.testing;
    errorMessage = null;
    notifyListeners();
    final List<ServerProfile> eligibleServers = subscriptions
        .where((Subscription subscription) => !subscription.isExpired)
        .expand((Subscription subscription) => subscription.servers)
        .toList(growable: false);
    final Map<String, int?> results =
        await _latencyService.testAll(eligibleServers);
    subscriptions = subscriptions.map((Subscription subscription) {
      return subscription.copyWith(
        servers: subscription.servers.map((ServerProfile server) {
          if (subscription.isExpired) {
            return server.copyWith(clearLatency: true);
          }
          return server.copyWith(
            latencyMs: results[server.id],
            clearLatency: results[server.id] == null,
          );
        }).toList(),
      );
    }).toList();
    connectionState = VpnConnectionState.disconnected;
    await _persist();
    notifyListeners();
  }

  Future<void> smartConnect() async {
    if (connectionState == VpnConnectionState.connected) return;
    if (servers.isEmpty || isBusy) {
      if (servers.isEmpty) {
        errorMessage = 'ابتدا یک اشتراک اضافه کنید.';
        connectionState = VpnConnectionState.failed;
        notifyListeners();
      }
      return;
    }
    await testServers();
    final List<ServerProfile> usable = servers
        .where(
          (ServerProfile item) =>
              item.latencyMs != null && !isServerExpired(item.id),
        )
        .toList()
      ..sort(
        (ServerProfile a, ServerProfile b) =>
            a.latencyMs!.compareTo(b.latencyMs!),
      );
    if (usable.isEmpty) {
      errorMessage = 'هیچ سرور فعالی پیدا نشد.';
      connectionState = VpnConnectionState.failed;
      notifyListeners();
      return;
    }
    selectedServerId = usable.first.id;
    await _persist();
    await connectSelected();
  }

  Future<void> toggleConnection({bool smart = false}) async {
    if (connectionState == VpnConnectionState.connected) {
      await disconnect();
    } else if (smart) {
      await smartConnect();
    } else {
      await connectSelected();
    }
  }

  Future<void> connectSelected() async {
    final ServerProfile? server = selectedServer;
    if (server == null || isBusy) {
      if (server == null) {
        errorMessage = 'ابتدا یک سرور انتخاب کنید.';
        connectionState = VpnConnectionState.failed;
        notifyListeners();
      }
      return;
    }
    final Subscription? subscription = subscriptionForServer(server.id);
    if (subscription?.isExpired ?? false) {
      errorMessage = 'اشتراک «${subscription!.name}» منقضی شده است.';
      connectionState = VpnConnectionState.failed;
      notifyListeners();
      return;
    }
    connectionState = VpnConnectionState.connecting;
    errorMessage = null;
    notifyListeners();
    try {
      await core.connect(server, settings);
      connectedAt = DateTime.now();
      connectionState = VpnConnectionState.connected;
    } on Object catch (error) {
      errorMessage = '$error';
      connectionState = VpnConnectionState.failed;
      await store.appendLog('Connection failed: $error');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await core.disconnect();
    connectedAt = null;
    connectionState = VpnConnectionState.disconnected;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    final bool startupChanged = settings.startWithWindows != value.startWithWindows;
    settings = value;
    if (startupChanged) await platform.setAutoStart(value.startWithWindows);
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    if (connectionState == VpnConnectionState.connected) await disconnect();
    await platform.setAutoStart(false);
    await store.reset();
    settings = const AppSettings();
    subscriptions = <Subscription>[];
    selectedServerId = null;
    connectionState = VpnConnectionState.disconnected;
    notifyListeners();
  }

  Future<void> shutdown() async {
    await core.dispose();
    await platform.quitApplication();
  }

  Future<void> _persist() {
    return store.save(
      StoredState(
        settings: settings,
        subscriptions: subscriptions,
        selectedServerId: selectedServerId,
      ),
    );
  }

  void _handleUnexpectedCoreExit(int exitCode) {
    connectedAt = null;
    errorMessage = 'هستهٔ اتصال با خطای $exitCode متوقف شد.';
    connectionState = VpnConnectionState.failed;
    notifyListeners();
  }
}
