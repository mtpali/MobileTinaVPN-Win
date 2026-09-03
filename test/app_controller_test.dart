import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobiletina_vpn/app_controller.dart';
import 'package:mobiletina_vpn/models/server_profile.dart';
import 'package:mobiletina_vpn/models/subscription.dart';
import 'package:mobiletina_vpn/services/latency_service.dart';
import 'package:mobiletina_vpn/services/portable_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mobiletina-controller-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('imports direct server links from clipboard and deduplicates them', () async {
    final AppController controller = AppController(
      store: PortableStore(executableDirectory: temporaryDirectory),
    );
    const String link =
        'vless://11111111-1111-1111-1111-111111111111@example.com:443'
        '?security=tls&sni=example.com#Clipboard';

    expect(await controller.importServersFromClipboard('$link\n$link'), 1);
    expect(controller.subscriptions, hasLength(1));
    expect(controller.subscriptions.single.isRemote, isFalse);
    expect(controller.subscriptions.single.name, 'instagram : mobile.tina');
    expect(controller.servers, hasLength(1));
  });

  test('failed end-to-end probes mark servers inactive', () async {
    final AppController controller = AppController(
      store: PortableStore(executableDirectory: temporaryDirectory),
      latencyService: _RecordingLatencyService(result: null),
    );
    controller.subscriptions = <Subscription>[
      Subscription(
        id: 'active',
        name: 'Active',
        url: 'https://example.com/sub',
        servers: <ServerProfile>[_server()],
        updatedAt: DateTime.now(),
      ),
    ];

    await controller.testServers();

    expect(controller.servers.single.latencyMs, -1);
    expect(controller.servers.single.isInactive, isTrue);
  });

  test('expired subscriptions are excluded from latency tests', () async {
    final _RecordingLatencyService latency = _RecordingLatencyService();
    final AppController controller = AppController(
      store: PortableStore(executableDirectory: temporaryDirectory),
      latencyService: latency,
    );
    final ServerProfile server = _server();
    controller.subscriptions = <Subscription>[
      Subscription(
        id: 'expired',
        name: 'Expired',
        url: 'https://example.com/sub',
        servers: <ServerProfile>[server.copyWith(latencyMs: 120)],
        updatedAt: DateTime.now(),
        usage: SubscriptionUsage(
          expiryUnix: DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        ),
      ),
    ];

    await controller.testServers();

    expect(latency.tested, isEmpty);
    expect(controller.servers.single.latencyMs, isNull);
  });
}

class _RecordingLatencyService extends LatencyService {
  _RecordingLatencyService({this.result = 42});

  final int? result;
  final List<ServerProfile> tested = <ServerProfile>[];

  @override
  Future<Map<String, int?>> testAll(
    Iterable<ServerProfile> servers, {
    required String corePath,
    required Directory runtimeDirectory,
    int concurrency = 4,
  }) async {
    tested.addAll(servers);
    return <String, int?>{
      for (final ServerProfile server in servers) server.id: result,
    };
  }
}

ServerProfile _server() {
  return const ServerProfile(
    id: 'server',
    name: 'Server',
    protocol: ProxyProtocol.vless,
    host: 'example.com',
    port: 443,
    secret: '11111111-1111-1111-1111-111111111111',
    sourceUri:
        'vless://11111111-1111-1111-1111-111111111111@example.com:443',
    security: 'tls',
  );
}
