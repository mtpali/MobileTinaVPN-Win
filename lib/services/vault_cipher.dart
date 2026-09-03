import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authenticated encryption used for bundled artwork/fonts and portable state.
///
/// The split application key is intentional release hardening, not a claim of
/// hardware-backed secrecy: any key required for unattended decryption can be
/// recovered by a determined reverse engineer. AES-GCM still prevents casual
/// extraction and detects modified or corrupted payloads.
class VaultCipher {
  VaultCipher._();

  static final VaultCipher instance = VaultCipher._();

  static const List<int> _keyPartA = <int>[
    0x6e,
    0x2a,
    0xb7,
    0xc1,
    0x09,
    0x5d,
    0xf4,
    0x40,
    0xa3,
    0xc8,
    0x6d,
    0x12,
    0x86,
    0xfb,
    0x3a,
    0x55,
    0xd1,
    0x04,
    0xe9,
    0xbb,
    0x32,
    0xca,
    0x7f,
    0x60,
    0x98,
    0x17,
    0x4c,
    0xda,
    0xf0,
    0xe1,
    0x26,
    0x99,
  ];
  static const List<int> _keyPartB = <int>[
    0xfd,
    0xed,
    0x16,
    0x9f,
    0x4b,
    0xa5,
    0xff,
    0x93,
    0xc9,
    0xd7,
    0x11,
    0xcb,
    0xa3,
    0x4b,
    0x74,
    0xdd,
    0xc8,
    0xd6,
    0x86,
    0x81,
    0x4c,
    0xcf,
    0xbe,
    0xd6,
    0xd1,
    0x98,
    0x61,
    0x3e,
    0x83,
    0x4d,
    0x70,
    0x92,
  ];
  static const List<int> _magic = <int>[0x4d, 0x54, 0x56, 0x32];
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  final AesGcm _algorithm = AesGcm.with256bits();
  late final SecretKey _secretKey = SecretKey(
    List<int>.generate(
      _keyPartA.length,
      (int index) => _keyPartA[index] ^ _keyPartB[index],
      growable: false,
    ),
  );

  Future<Uint8List> seal(
    List<int> clearText, {
    required String context,
  }) async {
    final List<int> compressed = gzip.encode(clearText);
    final List<int> nonce = _algorithm.newNonce();
    final SecretBox box = await _algorithm.encrypt(
      compressed,
      secretKey: _secretKey,
      nonce: nonce,
      aad: utf8.encode(context),
    );
    return Uint8List.fromList(<int>[
      ..._magic,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  Future<Uint8List> open(
    List<int> payload, {
    required String context,
  }) async {
    final int headerLength = _magic.length + _nonceLength + _macLength;
    if (payload.length <= headerLength ||
        !_constantTimePrefixMatches(payload, _magic)) {
      throw const VaultException('Protected payload has an invalid format.');
    }
    final int nonceStart = _magic.length;
    final int macStart = nonceStart + _nonceLength;
    final int cipherStart = macStart + _macLength;
    final SecretBox box = SecretBox(
      payload.sublist(cipherStart),
      nonce: payload.sublist(nonceStart, macStart),
      mac: Mac(payload.sublist(macStart, cipherStart)),
    );
    try {
      final List<int> compressed = await _algorithm.decrypt(
        box,
        secretKey: _secretKey,
        aad: utf8.encode(context),
      );
      return Uint8List.fromList(gzip.decode(compressed));
    } on SecretBoxAuthenticationError {
      throw const VaultException(
        'Protected payload authentication failed.',
      );
    } on FormatException {
      throw const VaultException('Protected payload is corrupted.');
    } on ZLibException {
      throw const VaultException('Protected payload is corrupted.');
    }
  }

  Future<Uint8List> sealText(
    String value, {
    required String context,
  }) {
    return seal(utf8.encode(value), context: context);
  }

  Future<String> openText(
    List<int> payload, {
    required String context,
  }) async {
    return utf8.decode(await open(payload, context: context));
  }

  bool _constantTimePrefixMatches(List<int> value, List<int> prefix) {
    if (value.length < prefix.length) return false;
    int difference = 0;
    for (int index = 0; index < prefix.length; index += 1) {
      difference |= value[index] ^ prefix[index];
    }
    return difference == 0;
  }
}
