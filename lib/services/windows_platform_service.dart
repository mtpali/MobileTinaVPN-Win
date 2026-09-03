import 'dart:io';

import 'package:flutter/services.dart';

class ProxySnapshot {
  const ProxySnapshot({
    required this.enabled,
    required this.server,
    required this.override,
  });

  final bool enabled;
  final String server;
  final String override;

  Map<String, Object> toJson() => <String, Object>{
        'enabled': enabled,
        'server': server,
        'override': override,
      };

  factory ProxySnapshot.fromJson(Map<String, Object?> json) {
    return ProxySnapshot(
      enabled: json['enabled'] as bool? ?? false,
      server: json['server'] as String? ?? '',
      override: json['override'] as String? ?? '',
    );
  }
}

class WindowsPlatformService {
  WindowsPlatformService();

  static const MethodChannel _channel = MethodChannel(
    'com.mobiletina.vpn/windows',
  );

  Future<void> Function()? onTrayExit;

  void initialize() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'trayExit') await onTrayExit?.call();
    });
  }

  Future<ProxySnapshot> getSystemProxy() async {
    if (!Platform.isWindows) {
      return const ProxySnapshot(enabled: false, server: '', override: '');
    }
    final Map<Object?, Object?> raw =
        await _channel.invokeMapMethod<Object?, Object?>('getSystemProxy') ??
            <Object?, Object?>{};
    return ProxySnapshot(
      enabled: raw['enabled'] as bool? ?? false,
      server: raw['server'] as String? ?? '',
      override: raw['override'] as String? ?? '',
    );
  }

  Future<void> setSystemProxy(ProxySnapshot value) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>('setSystemProxy', value.toJson());
  }

  Future<void> setAutoStart(bool enabled) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>(
      'setAutoStart',
      <String, Object>{
        'enabled': enabled,
        'executable': Platform.resolvedExecutable,
      },
    );
  }

  Future<void> showWindow() async {
    if (Platform.isWindows) await _channel.invokeMethod<void>('showWindow');
  }

  Future<void> openUrl(String url) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod<void>('openUrl', url);
  }

  Future<void> quitApplication() async {
    if (Platform.isWindows) await _channel.invokeMethod<void>('quitApplication');
  }
}
