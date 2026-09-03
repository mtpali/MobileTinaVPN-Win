import 'dart:convert';

String decodeBase64Flexible(String input) {
  final String compact = input.replaceAll(RegExp(r'\s'), '');
  if (compact.isEmpty) return '';
  final String normalized = base64.normalize(
    compact.replaceAll('-', '+').replaceAll('_', '/'),
  );
  return utf8.decode(base64.decode(normalized), allowMalformed: false);
}

String stableId(String input) {
  // FNV-1a 64-bit. IDs only need to be deterministic; this is not used for
  // cryptographic decisions.
  int hash = 0xcbf29ce484222325;
  for (final int byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

bool parseBoolean(String? value) {
  return switch (value?.toLowerCase()) {
    '1' || 'true' || 'yes' => true,
    _ => false,
  };
}

String decodeComponent(String value) {
  try {
    return Uri.decodeComponent(value.replaceAll('+', '%20'));
  } on FormatException {
    return value;
  }
}
