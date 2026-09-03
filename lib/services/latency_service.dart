import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/server_profile.dart';
import 'xray_config_builder.dart';

class LatencyService {
  const LatencyService({
    this.probeUrls = const <String>[
      'https://www.gstatic.com/generate_204',
      'https://www.google.com/generate_204',
    ],
    this.builder = const XrayConfigBuilder(),
  });

  final List<String> probeUrls;
  final XrayConfigBuilder builder;

  Future<int?> test(
    ServerProfile server, {
    required String corePath,
    required Directory runtimeDirectory,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final File executable = File(corePath);
    if (!await executable.exists()) return null;

    final List<int> ports = await _reservePorts();
    final File configFile = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}'
      'probe-${DateTime.now().microsecondsSinceEpoch}-${server.id.hashCode}.json',
    );
    Process? process;
    HttpClient? client;
    try {
      await runtimeDirectory.create(recursive: true);
      final Map<String, Object?> config = builder.build(
        server: server,
        socksPort: ports.first,
        httpPort: ports.last,
      );
      await configFile.writeAsString(jsonEncode(config), flush: true);

      process = await Process.start(
        corePath,
        <String>['run', '-config', configFile.path],
        workingDirectory: executable.parent.path,
        runInShell: false,
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      if (!await _waitForPort(process, ports.last, timeout)) return null;

      client = HttpClient()
        ..connectionTimeout = timeout
        ..findProxy = (_) => 'PROXY 127.0.0.1:${ports.last}'
        ..userAgent = 'MobileTinaVPN-Windows-Latency/0.2';
      for (final String probeUrl in probeUrls) {
        final int? latency = await _probe(client, probeUrl, timeout);
        if (latency != null) return latency;
      }
      return null;
    } on Object {
      return null;
    } finally {
      client?.close(force: true);
      process?.kill();
      if (process != null) {
        try {
          await process.exitCode.timeout(const Duration(seconds: 1));
        } on Object {
          // The process was already terminated or Windows is still releasing it.
        }
      }
      if (await configFile.exists()) await configFile.delete();
    }
  }

  Future<int?> _probe(
    HttpClient client,
    String url,
    Duration timeout,
  ) async {
    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      final HttpClientRequest request = await client
          .getUrl(Uri.parse(url))
          .timeout(timeout);
      request.followRedirects = false;
      final HttpClientResponse response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      stopwatch.stop();

      // A login, renewal, or captive-portal page can still return 200/3xx while
      // the proxy is unusable. Only the expected no-content response proves
      // that this Xray outbound carried a real Internet request end to end.
      if (response.statusCode != HttpStatus.noContent) return null;
      return stopwatch.elapsedMilliseconds.clamp(1, 9999).toInt();
    } on Object {
      return null;
    }
  }

  Future<Map<String, int?>> testAll(
    Iterable<ServerProfile> servers, {
    required String corePath,
    required Directory runtimeDirectory,
    int concurrency = 4,
  }) async {
    final List<ServerProfile> pending = servers.toList(growable: false);
    final Map<String, int?> results = <String, int?>{};
    int cursor = 0;

    Future<void> worker() async {
      while (cursor < pending.length) {
        final ServerProfile server = pending[cursor];
        cursor += 1;
        results[server.id] = await test(
          server,
          corePath: corePath,
          runtimeDirectory: runtimeDirectory,
        );
      }
    }

    final int workerCount =
        pending.length < concurrency ? pending.length : concurrency;
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results;
  }

  Future<List<int>> _reservePorts() async {
    final ServerSocket socks = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final ServerSocket http = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final List<int> ports = <int>[socks.port, http.port];
    await socks.close();
    await http.close();
    return ports;
  }

  Future<bool> _waitForPort(
    Process process,
    int port,
    Duration timeout,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      try {
        final Socket socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return true;
      } on Object {
        try {
          await process.exitCode.timeout(const Duration(milliseconds: 20));
          return false;
        } on TimeoutException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    return false;
  }
}
