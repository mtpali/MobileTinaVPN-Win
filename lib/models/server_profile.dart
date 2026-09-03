enum ProxyProtocol { vmess, vless, trojan, shadowsocks, socks }

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    required this.secret,
    required this.sourceUri,
    this.method = '',
    this.network = 'tcp',
    this.security = '',
    this.sni = '',
    this.hostHeader = '',
    this.path = '',
    this.headerType = 'none',
    this.flow = '',
    this.fingerprint = '',
    this.alpn = '',
    this.publicKey = '',
    this.shortId = '',
    this.spiderX = '',
    this.serviceName = '',
    this.authority = '',
    this.allowInsecure = false,
    this.latencyMs,
  });

  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String secret;
  final String sourceUri;
  final String method;
  final String network;
  final String security;
  final String sni;
  final String hostHeader;
  final String path;
  final String headerType;
  final String flow;
  final String fingerprint;
  final String alpn;
  final String publicKey;
  final String shortId;
  final String spiderX;
  final String serviceName;
  final String authority;
  final bool allowInsecure;
  final int? latencyMs;

  bool get hasSuccessfulLatency => latencyMs != null && latencyMs! > 0;

  bool get isInactive => latencyMs != null && latencyMs! < 0;

  String get protocolLabel => switch (protocol) {
        ProxyProtocol.vmess => 'VMess',
        ProxyProtocol.vless => 'VLESS',
        ProxyProtocol.trojan => 'Trojan',
        ProxyProtocol.shadowsocks => 'Shadowsocks',
        ProxyProtocol.socks => 'SOCKS',
      };

  ServerProfile copyWith({int? latencyMs, bool clearLatency = false}) {
    return ServerProfile(
      id: id,
      name: name,
      protocol: protocol,
      host: host,
      port: port,
      secret: secret,
      sourceUri: sourceUri,
      method: method,
      network: network,
      security: security,
      sni: sni,
      hostHeader: hostHeader,
      path: path,
      headerType: headerType,
      flow: flow,
      fingerprint: fingerprint,
      alpn: alpn,
      publicKey: publicKey,
      shortId: shortId,
      spiderX: spiderX,
      serviceName: serviceName,
      authority: authority,
      allowInsecure: allowInsecure,
      latencyMs: clearLatency ? null : latencyMs ?? this.latencyMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'secret': secret,
        'sourceUri': sourceUri,
        'method': method,
        'network': network,
        'security': security,
        'sni': sni,
        'hostHeader': hostHeader,
        'path': path,
        'headerType': headerType,
        'flow': flow,
        'fingerprint': fingerprint,
        'alpn': alpn,
        'publicKey': publicKey,
        'shortId': shortId,
        'spiderX': spiderX,
        'serviceName': serviceName,
        'authority': authority,
        'allowInsecure': allowInsecure,
        'latencyMs': latencyMs,
      };

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      protocol: ProxyProtocol.values.byName(json['protocol']! as String),
      host: json['host']! as String,
      port: json['port']! as int,
      secret: json['secret']! as String,
      sourceUri: json['sourceUri']! as String,
      method: json['method'] as String? ?? '',
      network: json['network'] as String? ?? 'tcp',
      security: json['security'] as String? ?? '',
      sni: json['sni'] as String? ?? '',
      hostHeader: json['hostHeader'] as String? ?? '',
      path: json['path'] as String? ?? '',
      headerType: json['headerType'] as String? ?? 'none',
      flow: json['flow'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      alpn: json['alpn'] as String? ?? '',
      publicKey: json['publicKey'] as String? ?? '',
      shortId: json['shortId'] as String? ?? '',
      spiderX: json['spiderX'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      authority: json['authority'] as String? ?? '',
      allowInsecure: json['allowInsecure'] as bool? ?? false,
      latencyMs: json['latencyMs'] as int?,
    );
  }
}
