import '../models/server_profile.dart';

class XrayConfigBuilder {
  const XrayConfigBuilder();

  Map<String, Object?> build({
    required ServerProfile server,
    required int socksPort,
    required int httpPort,
  }) {
    return <String, Object?>{
      'log': <String, Object?>{'loglevel': 'warning'},
      'inbounds': <Object?>[
        <String, Object?>{
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': socksPort,
          'protocol': 'socks',
          'settings': <String, Object?>{'auth': 'noauth', 'udp': true},
          'sniffing': <String, Object?>{
            'enabled': true,
            'destOverride': <String>['http', 'tls', 'quic'],
            'routeOnly': true,
          },
        },
        <String, Object?>{
          'tag': 'http-in',
          'listen': '127.0.0.1',
          'port': httpPort,
          'protocol': 'http',
          'settings': <String, Object?>{},
          'sniffing': <String, Object?>{
            'enabled': true,
            'destOverride': <String>['http', 'tls'],
            'routeOnly': true,
          },
        },
      ],
      'outbounds': <Object?>[
        _proxyOutbound(server),
        <String, Object?>{'tag': 'direct', 'protocol': 'freedom'},
        <String, Object?>{'tag': 'blocked', 'protocol': 'blackhole'},
      ],
      'routing': <String, Object?>{
        'domainStrategy': 'AsIs',
        'rules': <Object?>[
          <String, Object?>{
            'type': 'field',
            'ip': <String>['geoip:private'],
            'outboundTag': 'direct',
          },
        ],
      },
    };
  }

  Map<String, Object?> _proxyOutbound(ServerProfile server) {
    return <String, Object?>{
      'tag': 'proxy',
      'protocol': _protocolName(server.protocol),
      'settings': _protocolSettings(server),
      if (server.protocol != ProxyProtocol.shadowsocks &&
          server.protocol != ProxyProtocol.socks)
        'streamSettings': _streamSettings(server),
    };
  }

  String _protocolName(ProxyProtocol protocol) {
    return switch (protocol) {
      ProxyProtocol.shadowsocks => 'shadowsocks',
      _ => protocol.name,
    };
  }

  Map<String, Object?> _protocolSettings(ServerProfile server) {
    switch (server.protocol) {
      case ProxyProtocol.vmess:
        return <String, Object?>{
          'vnext': <Object?>[
            <String, Object?>{
              'address': server.host,
              'port': server.port,
              'users': <Object?>[
                <String, Object?>{
                  'id': server.secret,
                  'security': server.method.isEmpty ? 'auto' : server.method,
                },
              ],
            },
          ],
        };
      case ProxyProtocol.vless:
        return <String, Object?>{
          'vnext': <Object?>[
            <String, Object?>{
              'address': server.host,
              'port': server.port,
              'users': <Object?>[
                <String, Object?>{
                  'id': server.secret,
                  'encryption': server.method.isEmpty ? 'none' : server.method,
                  if (server.flow.isNotEmpty) 'flow': server.flow,
                },
              ],
            },
          ],
        };
      case ProxyProtocol.trojan:
        return <String, Object?>{
          'servers': <Object?>[
            <String, Object?>{
              'address': server.host,
              'port': server.port,
              'password': server.secret,
            },
          ],
        };
      case ProxyProtocol.shadowsocks:
        return <String, Object?>{
          'servers': <Object?>[
            <String, Object?>{
              'address': server.host,
              'port': server.port,
              'method': server.method,
              'password': server.secret,
            },
          ],
        };
      case ProxyProtocol.socks:
        return <String, Object?>{
          'servers': <Object?>[
            <String, Object?>{
              'address': server.host,
              'port': server.port,
              if (server.method.isNotEmpty)
                'users': <Object?>[
                  <String, Object?>{
                    'user': server.method,
                    'pass': server.secret,
                  },
                ],
            },
          ],
        };
    }
  }

  Map<String, Object?> _streamSettings(ServerProfile server) {
    final String network = switch (server.network) {
      'splithttp' => 'xhttp',
      '' => 'tcp',
      _ => server.network,
    };
    final Map<String, Object?> settings = <String, Object?>{
      'network': network,
      'security': server.security.isEmpty ? 'none' : server.security,
    };

    switch (network) {
      case 'ws':
        settings['wsSettings'] = <String, Object?>{
          if (server.path.isNotEmpty) 'path': server.path,
          if (server.hostHeader.isNotEmpty)
            'headers': <String, Object?>{'Host': server.hostHeader},
        };
      case 'grpc':
        settings['grpcSettings'] = <String, Object?>{
          'serviceName': server.serviceName,
          if (server.authority.isNotEmpty) 'authority': server.authority,
          if (server.headerType == 'multi') 'multiMode': true,
        };
      case 'httpupgrade':
        settings['httpupgradeSettings'] = <String, Object?>{
          if (server.path.isNotEmpty) 'path': server.path,
          if (server.hostHeader.isNotEmpty) 'host': server.hostHeader,
        };
      case 'xhttp':
        settings['xhttpSettings'] = <String, Object?>{
          if (server.path.isNotEmpty) 'path': server.path,
          if (server.hostHeader.isNotEmpty) 'host': server.hostHeader,
        };
      case 'kcp':
        settings['kcpSettings'] = <String, Object?>{
          if (server.path.isNotEmpty) 'seed': server.path,
          'header': <String, Object?>{'type': server.headerType},
        };
      case 'tcp':
        if (server.headerType.isNotEmpty && server.headerType != 'none') {
          settings['tcpSettings'] = <String, Object?>{
            'header': <String, Object?>{'type': server.headerType},
          };
        }
    }

    if (server.security == 'tls') {
      settings['tlsSettings'] = <String, Object?>{
        if (server.sni.isNotEmpty) 'serverName': server.sni,
        if (server.fingerprint.isNotEmpty)
          'fingerprint': server.fingerprint,
        if (server.alpn.isNotEmpty)
          'alpn': server.alpn
              .split(',')
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
        'allowInsecure': server.allowInsecure,
      };
    } else if (server.security == 'reality') {
      settings['realitySettings'] = <String, Object?>{
        if (server.sni.isNotEmpty) 'serverName': server.sni,
        if (server.fingerprint.isNotEmpty)
          'fingerprint': server.fingerprint,
        'publicKey': server.publicKey,
        if (server.shortId.isNotEmpty) 'shortId': server.shortId,
        if (server.spiderX.isNotEmpty) 'spiderX': server.spiderX,
      };
    }
    return settings;
  }
}
