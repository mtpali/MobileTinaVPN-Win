import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/server_profile.dart';
import 'portable_store.dart';
import 'windows_platform_service.dart';
import 'xray_config_builder.dart';

class CoreException implements Exception {
  const CoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class XrayCoreService {
  XrayCoreService({
    required PortableStore store,
    required WindowsPlatformService platform,
    XrayConfigBuilder builder = const XrayConfigBuilder(),
  })  : _store = store,
        _platform = platform,
        _builder = builder;

  final PortableStore _store;
  final WindowsPlatformService _platform;
  final XrayConfigBuilder _builder;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  ProxySnapshot? _previousProxy;
  void Function(int exitCode)? onUnexpectedExit;

  bool get isRunning => _process != null;

  String get corePath {
    return '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}core${Platform.pathSeparator}xray.exe';
  }

  Future<void> recoverInterruptedSession() async {
    await _store.initialize();
    if (!await _store.activeSessionFile.exists()) return;
    try {
      final Object? raw = jsonDecode(
        await _store.activeSessionFile.readAsString(),
      );
      if (raw is Map<String, dynamic>) {
        final int? pid = raw['pid'] as int?;
        if (Platform.isWindows && pid != null && pid > 0) {
          await Process.run(
            'taskkill',
            <String>['/PID', '$pid', '/T', '/F'],
            runInShell: false,
          );
        }
      }
      await _restorePreviousProxyFromDisk();
      await _store.appendLog('Recovered an interrupted connection session.');
    } on Object catch (error) {
      await _store.appendLog('Session recovery warning: $error');
    } finally {
      if (await _store.activeSessionFile.exists()) {
        await _store.activeSessionFile.delete();
      }
    }
  }

  Future<void> connect(ServerProfile server, AppSettings settings) async {
    if (_process != null) await disconnect();
    final File executable = File(corePath);
    if (!await executable.exists()) {
      throw const CoreException(
        'هستهٔ Xray کنار برنامه پیدا نشد. نسخهٔ Portable رسمی را دریافت کنید.',
      );
    }

    final Map<String, Object?> config = _builder.build(
      server: server,
      socksPort: settings.socksPort,
      httpPort: settings.httpPort,
    );
    await _store.runtimeConfigFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      flush: true,
    );

    final ProcessResult check = await Process.run(
      corePath,
      <String>['run', '-test', '-config', _store.runtimeConfigFile.path],
      workingDirectory: executable.parent.path,
      runInShell: false,
    );
    if (check.exitCode != 0) {
      await _store.appendLog('Xray config check failed: ${check.stderr}');
      throw const CoreException('تنظیمات این سرور توسط Xray پذیرفته نشد.');
    }

    _previousProxy = await _platform.getSystemProxy();
    await _store.previousProxyFile.writeAsString(
      jsonEncode(_previousProxy!.toJson()),
      flush: true,
    );

    final Process process = await Process.start(
      corePath,
      <String>['run', '-config', _store.runtimeConfigFile.path],
      workingDirectory: executable.parent.path,
      runInShell: false,
    );
    _process = process;
    unawaited(
      process.exitCode.then((int exitCode) async {
        if (identical(_process, process)) {
          _process = null;
          await _restorePreviousProxy();
          if (await _store.activeSessionFile.exists()) {
            await _store.activeSessionFile.delete();
          }
          await _store.appendLog('Xray stopped unexpectedly: $exitCode');
          onUnexpectedExit?.call(exitCode);
        }
      }),
    );
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) => unawaited(_store.appendLog('core: $line')));
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) => unawaited(_store.appendLog('core: $line')));

    await _store.activeSessionFile.writeAsString(
      jsonEncode(<String, Object>{'pid': process.pid}),
      flush: true,
    );

    final bool ready = await _waitForPort(settings.socksPort);
    if (!ready) {
      final int? exitCode = await _tryGetExitCode(process);
      await disconnect();
      throw CoreException(
        exitCode == null
            ? 'هستهٔ اتصال در زمان مناسب آماده نشد.'
            : 'هستهٔ اتصال با خطای $exitCode متوقف شد.',
      );
    }

    if (settings.systemProxy) {
      try {
        await _platform.setSystemProxy(
          ProxySnapshot(
            enabled: true,
            server: 'http=127.0.0.1:${settings.httpPort};'
                'https=127.0.0.1:${settings.httpPort};'
                'socks=127.0.0.1:${settings.socksPort}',
            override: '<local>',
          ),
        );
      } on Object {
        await disconnect();
        rethrow;
      }
    }
    await _store.appendLog('Connected to ${server.protocolLabel}.');
  }

  Future<void> disconnect() async {
    try {
      await _restorePreviousProxy();
    } finally {
      final Process? process = _process;
      _process = null;
      if (process != null) process.kill();
      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();
      _stdoutSubscription = null;
      _stderrSubscription = null;
      if (await _store.activeSessionFile.exists()) {
        await _store.activeSessionFile.delete();
      }
      await _store.appendLog('Disconnected.');
    }
  }

  Future<void> dispose() => disconnect();

  Future<bool> _waitForPort(int port) async {
    for (int attempt = 0; attempt < 20; attempt += 1) {
      if (_process == null) return false;
      try {
        final Socket socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return true;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    return false;
  }

  Future<int?> _tryGetExitCode(Process process) async {
    try {
      return await process.exitCode.timeout(const Duration(milliseconds: 50));
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _restorePreviousProxy() async {
    if (_previousProxy != null) {
      await _platform.setSystemProxy(_previousProxy!);
      _previousProxy = null;
      if (await _store.previousProxyFile.exists()) {
        await _store.previousProxyFile.delete();
      }
      return;
    }
    await _restorePreviousProxyFromDisk();
  }

  Future<void> _restorePreviousProxyFromDisk() async {
    if (!await _store.previousProxyFile.exists()) return;
    final Object? raw = jsonDecode(await _store.previousProxyFile.readAsString());
    if (raw is Map<String, dynamic>) {
      await _platform.setSystemProxy(
        ProxySnapshot.fromJson(raw.cast<String, Object?>()),
      );
    }
    await _store.previousProxyFile.delete();
  }
}
