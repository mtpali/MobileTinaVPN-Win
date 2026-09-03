import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'vault_cipher.dart';

enum ProtectedImageAsset {
  brandIcon,
  disconnected,
  connecting,
  connected,
  failed,
  manualOff,
  manualOn,
}

class ProtectedAssets {
  ProtectedAssets._();

  static const Map<ProtectedImageAsset, String> _imagePaths =
      <ProtectedImageAsset, String>{
    ProtectedImageAsset.brandIcon: 'assets/protected/p0.mtv',
    ProtectedImageAsset.disconnected: 'assets/protected/p1.mtv',
    ProtectedImageAsset.connecting: 'assets/protected/p2.mtv',
    ProtectedImageAsset.connected: 'assets/protected/p3.mtv',
    ProtectedImageAsset.failed: 'assets/protected/p4.mtv',
    ProtectedImageAsset.manualOff: 'assets/protected/p5.mtv',
    ProtectedImageAsset.manualOn: 'assets/protected/p6.mtv',
  };
  static const Map<String, String> _fontPaths = <String, String>{
    'regular': 'assets/protected/f0.mtv',
    'semibold': 'assets/protected/f1.mtv',
    'bold': 'assets/protected/f2.mtv',
  };
  static final Map<ProtectedImageAsset, Uint8List> _images =
      <ProtectedImageAsset, Uint8List>{};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    for (final MapEntry<ProtectedImageAsset, String> entry
        in _imagePaths.entries) {
      _images[entry.key] = await _load(
        entry.value,
        context: 'asset:image:${entry.key.name}',
      );
    }

    final FontLoader loader = FontLoader('MobileTina');
    for (final MapEntry<String, String> entry in _fontPaths.entries) {
      final Uint8List bytes = await _load(
        entry.value,
        context: 'asset:font:${entry.key}',
      );
      loader.addFont(
        Future<ByteData>.value(ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
    _initialized = true;
  }

  static Uint8List image(ProtectedImageAsset asset) {
    final Uint8List? bytes = _images[asset];
    if (!_initialized || bytes == null) {
      throw StateError('Protected assets have not been initialized.');
    }
    return bytes;
  }

  static Future<Uint8List> _load(
    String path, {
    required String context,
  }) async {
    final ByteData data = await rootBundle.load(path);
    return VaultCipher.instance.open(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      context: context,
    );
  }
}
