import 'dart:convert';

import '../models/server_profile.dart';
import 'codec_utils.dart';

class SubscriptionParseResult {
  const SubscriptionParseResult({
    required this.servers,
    required this.rejectedCount,
  });

  final List<ServerProfile> servers;
  final int rejectedCount;
}

class SubscriptionParser {
  static final RegExp _schemePattern = RegExp(
    r'(?:^|\s)(vmess|vless|trojan|ss|socks)://',
    caseSensitive: false,
    multiLine: true,
  );

  SubscriptionParseResult parse(String payload) {
    String decoded = payload.trim().replaceFirst('\u{feff}', '');
    if (!_schemePattern.hasMatch(decoded)) {
      try {
        decoded = decodeBase64Flexible(decoded).trim();
      } on FormatException {
        return const SubscriptionParseResult(
          servers: <ServerProfile>[],
          rejectedCount: 1,
        );
      }
    }

    final Iterable<String> candidates = decoded
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty);

    final Map<String, ServerProfile> unique = <String, ServerProfile>{};
    int rejected = 0;
    for (final String candidate in candidates) {
      try {
        final ServerProfile? profile = parseUri(candidate);
        if (profile == null) {
          rejected += 1;
        } else {
          unique[profile.id] = profile;
        }
      } on FormatException {
        rejected += 1;
      } on ArgumentError {
        rejected += 1;
      }
    }

    return SubscriptionParseResult(
      servers: unique.values.toList(growable: false),
      rejectedCount: rejected,
    );
  }

  ServerProfile? parseUri(String source) {
    final String uri = source.trim();
    if (uri.startsWith('vmess://')) return _parseVmess(uri);
    if (uri.startsWith('vless://')) {
      return _parseStandard(uri, ProxyProtocol.vless);
    }
    if (uri.startsWith('trojan://')) {
      return _parseStandard(uri, ProxyProtocol.trojan);
    }
    if (uri.startsWith('socks://')) {
      return _parseStandard(uri, ProxyProtocol.socks);
    }
    if (uri.startsWith('ss://')) return _parseShadowsocks(uri);
    return null;
  }

  ServerProfile _parseVmess(String source) {
    final String body = source.substring('vmess://'.length);
    if (body.contains('@') && body.contains('?')) {
      return _parseStandard(source, ProxyProtocol.vmess);
    }

    final Object? raw = jsonDecode(decodeBase64Flexible(body));
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid VMess JSON');
    }
    final String host = '${raw['add'] ?? ''}'.trim();
    final int port = int.tryParse('${raw['port'] ?? ''}') ?? 0;
    final String secret = '${raw['id'] ?? ''}'.trim();
    if (host.isEmpty || port < 1 || port > 65535 || secret.isEmpty) {
      throw const FormatException('Incomplete VMess profile');
    }

    final String name = '${raw['ps'] ?? ''}'.trim();
    final String network = '${raw['net'] ?? 'tcp'}'.trim().toLowerCase();
    final String tls = '${raw['tls'] ?? ''}'.trim().toLowerCase();
    return ServerProfile(
      id: stableId(source),
      name: name.isEmpty ? host : name,
      protocol: ProxyProtocol.vmess,
      host: host,
      port: port,
      secret: secret,
      sourceUri: source,
      method: '${raw['scy'] ?? 'auto'}',
      network: network.isEmpty ? 'tcp' : network,
      security: tls,
      sni: '${raw['sni'] ?? ''}',
      hostHeader: '${raw['host'] ?? ''}',
      path: '${raw['path'] ?? ''}',
      headerType: '${raw['type'] ?? 'none'}',
      fingerprint: '${raw['fp'] ?? ''}',
      alpn: '${raw['alpn'] ?? ''}',
      serviceName: network == 'grpc' ? '${raw['path'] ?? ''}' : '',
      authority: network == 'grpc' ? '${raw['host'] ?? ''}' : '',
      allowInsecure: parseBoolean('${raw['allowInsecure'] ?? raw['insecure'] ?? ''}'),
    );
  }

  ServerProfile _parseStandard(String source, ProxyProtocol protocol) {
    final Uri uri = Uri.parse(source);
    final String host = uri.host;
    final int port = uri.hasPort ? uri.port : _defaultPort(protocol);
    String secret = decodeComponent(uri.userInfo);
    String method = '';

    if (protocol == ProxyProtocol.socks && secret.contains(':')) {
      final int separator = secret.indexOf(':');
      method = decodeComponent(secret.substring(0, separator));
      secret = decodeComponent(secret.substring(separator + 1));
    }
    if (host.isEmpty || port < 1 || port > 65535 || secret.isEmpty) {
      throw const FormatException('Incomplete proxy URI');
    }

    final Map<String, String> query = uri.queryParameters;
    final String network = (query['type'] ?? 'tcp').toLowerCase();
    final String fragment = uri.fragment.isEmpty
        ? host
        : decodeComponent(uri.fragment);

    return ServerProfile(
      id: stableId(source),
      name: fragment,
      protocol: protocol,
      host: host,
      port: port,
      secret: secret,
      sourceUri: source,
      method: protocol == ProxyProtocol.vless
          ? query['encryption'] ?? 'none'
          : method,
      network: network,
      security: (query['security'] ??
              (protocol == ProxyProtocol.trojan ? 'tls' : ''))
          .toLowerCase(),
      sni: query['sni'] ?? query['serverName'] ?? '',
      hostHeader: query['host'] ?? '',
      path: query['path'] ?? '',
      headerType: query['headerType'] ?? 'none',
      flow: query['flow'] ?? '',
      fingerprint: query['fp'] ?? '',
      alpn: query['alpn'] ?? '',
      publicKey: query['pbk'] ?? query['publicKey'] ?? '',
      shortId: query['sid'] ?? query['shortId'] ?? '',
      spiderX: query['spx'] ?? query['spiderX'] ?? '',
      serviceName: query['serviceName'] ?? query['path'] ?? '',
      authority: query['authority'] ?? query['host'] ?? '',
      allowInsecure: parseBoolean(
        query['allowInsecure'] ?? query['insecure'],
      ),
    );
  }

  ServerProfile _parseShadowsocks(String source) {
    final String withoutScheme = source.substring('ss://'.length);
    final int fragmentIndex = withoutScheme.indexOf('#');
    final String name = fragmentIndex >= 0
        ? decodeComponent(withoutScheme.substring(fragmentIndex + 1))
        : '';
    final String withoutFragment = fragmentIndex >= 0
        ? withoutScheme.substring(0, fragmentIndex)
        : withoutScheme;
    final int queryIndex = withoutFragment.indexOf('?');
    final String authority = queryIndex >= 0
        ? withoutFragment.substring(0, queryIndex)
        : withoutFragment;

    String credentials;
    String endpoint;
    final int at = authority.lastIndexOf('@');
    if (at >= 0) {
      credentials = authority.substring(0, at);
      endpoint = authority.substring(at + 1);
      if (!credentials.contains(':')) {
        credentials = decodeBase64Flexible(credentials);
      }
    } else {
      final String decoded = decodeBase64Flexible(authority);
      final int decodedAt = decoded.lastIndexOf('@');
      if (decodedAt < 0) throw const FormatException('Invalid SS profile');
      credentials = decoded.substring(0, decodedAt);
      endpoint = decoded.substring(decodedAt + 1);
    }

    final int separator = credentials.indexOf(':');
    if (separator <= 0) throw const FormatException('Invalid SS credentials');
    final ({String host, int port}) address = _parseHostPort(endpoint);
    return ServerProfile(
      id: stableId(source),
      name: name.isEmpty ? address.host : name,
      protocol: ProxyProtocol.shadowsocks,
      host: address.host,
      port: address.port,
      secret: decodeComponent(credentials.substring(separator + 1)),
      sourceUri: source,
      method: decodeComponent(credentials.substring(0, separator)).toLowerCase(),
    );
  }

  ({String host, int port}) _parseHostPort(String endpoint) {
    final Uri uri = Uri.parse('scheme://$endpoint');
    if (uri.host.isEmpty || !uri.hasPort || uri.port < 1 || uri.port > 65535) {
      throw const FormatException('Invalid host or port');
    }
    return (host: uri.host, port: uri.port);
  }

  int _defaultPort(ProxyProtocol protocol) {
    return switch (protocol) {
      ProxyProtocol.trojan => 443,
      ProxyProtocol.socks => 1080,
      ProxyProtocol.vmess ||
      ProxyProtocol.vless ||
      ProxyProtocol.shadowsocks => 0,
    };
  }
}
