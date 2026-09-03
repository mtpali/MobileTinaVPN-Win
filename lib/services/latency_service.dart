import 'dart:async';
import 'dart:io';

import '../models/server_profile.dart';

class LatencyService {
  const LatencyService();

  Future<int?> test(
    ServerProfile server, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        server.host,
        server.port,
        timeout: timeout,
      );
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.clamp(1, 9999).toInt();
    } on Object {
      return null;
    } finally {
      await socket?.close();
    }
  }

  Future<Map<String, int?>> testAll(
    Iterable<ServerProfile> servers, {
    int concurrency = 12,
  }) async {
    final List<ServerProfile> pending = servers.toList(growable: false);
    final Map<String, int?> results = <String, int?>{};
    int cursor = 0;

    Future<void> worker() async {
      while (cursor < pending.length) {
        final ServerProfile server = pending[cursor];
        cursor += 1;
        results[server.id] = await test(server);
      }
    }

    final int workerCount =
        pending.length < concurrency ? pending.length : concurrency;
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results;
  }
}
