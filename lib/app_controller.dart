import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/app_settings.dart';
import 'models/server_profile.dart';
import 'models/subscription.dart';
import 'services/latency_service.dart';
import 'services/portable_store.dart';
import 'services/subscription_service.dart';
import 'services/windows_platform_service.dart';
import 'services/xray_core_service.dart';

enum ConnectionState { disconnected, testing, connecting, connected, failed }

class AppController extends ChangeNotifier {
  AppController({
    PortableStore? store,
    WindowsPlatformService? platform,
    SubscriptionService? subscriptionService,
    LatencyService latencyService = const LatencyService(),
  })  : store = store ?? PortableStore(),
        platform = platform ?? WindowsPlatformService(),
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _latencyService = latencyService {
    core = XrayCoreService(store: this.store, platform: this.platform);
    core.onUnexpectedExit = _handleUnexpectedCoreExit;
  }

  final PortableStore store;
  final WindowsPlatformService platform;
  final SubscriptionService _subscriptionService;
  final LatencyService _latencyService;
  late final XrayCoreService core;

  AppSettings settings = const AppSettings();
  List<Subscription> subscriptions = <Subscription>[];
  String? selectedServerId;
  ConnectionState connectionState = ConnectionState.disconnected;
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

  bool get isBusy => connectionState == ConnectionState.testing ||
      connectionState == ConnectionState.connecting;

  Future<void> initialize() async {
    platform.initialize();
    platform.onTrayExit = shutdown;
    await core.recoverInterruptedSession();
    final StoredState loaded = await store.load();
    settings = loaded.settings;
    subscriptions = loaded.subscriptions;
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

  Future<void> updateSubscription(String id) async {
    final int index = subscriptions.indexWhere(
      (Subscription item) => item.id == id,
    );
    if (index < 0) return;
    final Subscription current = subscriptions[index];
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
      await updateSubscription(subscription.id);
    }
  }

  Future<void> removeSubscription(String id) async {
    if (connectionState == ConnectionState.connected) await disconnect();
    subscriptions = subscriptions
        .where((Subscription item) => item.id != id)
        .toList(growable: false);
    if (selectedServer == null) selectedServerId = servers.firstOrNull?.id;
    await _persist();
    notifyListeners();
  }

  Future<void> selectServer(String id) async {
    if (isBusy || connectionState == ConnectionState.connected) return;
    selectedServerId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> testServers() async {
    if (servers.isEmpty || isBusy || connectionState == ConnectionState.connected) {
      return;
    }
    connectionState = ConnectionState.testing;
    errorMessage = null;
    notifyListeners();
    final Map<String, int?> results = await _latencyService.testAll(servers);
    subscriptions = subscriptions.map((Subscription subscription) {
      return subscription.copyWith(
        servers: subscription.servers.map((ServerProfile server) {
          return server.copyWith(
            latencyMs: results[server.id],
            clearLatency: results[server.id] == null,
          );
        }).toList(),
      );
    }).toList();
    connectionState = ConnectionState.disconnected;
    await _persist();
    notifyListeners();
  }

  Future<void> smartConnect() async {
    if (connectionState == ConnectionState.connected) return;
    if (servers.isEmpty || isBusy) {
      if (servers.isEmpty) {
        errorMessage = 'ابتدا یک اشتراک اضافه کنید.';
        connectionState = ConnectionState.failed;
        notifyListeners();
      }
      return;
    }
    await testServers();
    final List<ServerProfile> usable = servers
        .where((ServerProfile item) => item.latencyMs != null)
        .toList()
      ..sort(
        (ServerProfile a, ServerProfile b) =>
            a.latencyMs!.compareTo(b.latencyMs!),
      );
    if (usable.isEmpty) {
      errorMessage = 'هیچ سرور فعالی پیدا نشد.';
      connectionState = ConnectionState.failed;
      notifyListeners();
      return;
    }
    selectedServerId = usable.first.id;
    await _persist();
    await connectSelected();
  }

  Future<void> toggleConnection({bool smart = false}) async {
    if (connectionState == ConnectionState.connected) {
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
        connectionState = ConnectionState.failed;
        notifyListeners();
      }
      return;
    }
    connectionState = ConnectionState.connecting;
    errorMessage = null;
    notifyListeners();
    try {
      await core.connect(server, settings);
      connectedAt = DateTime.now();
      connectionState = ConnectionState.connected;
    } on Object catch (error) {
      errorMessage = '$error';
      connectionState = ConnectionState.failed;
      await store.appendLog('Connection failed: $error');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await core.disconnect();
    connectedAt = null;
    connectionState = ConnectionState.disconnected;
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
    if (connectionState == ConnectionState.connected) await disconnect();
    await platform.setAutoStart(false);
    await store.reset();
    settings = const AppSettings();
    subscriptions = <Subscription>[];
    selectedServerId = null;
    connectionState = ConnectionState.disconnected;
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
    connectionState = ConnectionState.failed;
    notifyListeners();
  }
}
