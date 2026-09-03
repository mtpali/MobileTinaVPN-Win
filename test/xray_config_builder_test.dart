import 'package:flutter_test/flutter_test.dart';
import 'package:mobiletina_vpn/models/server_profile.dart';
import 'package:mobiletina_vpn/services/xray_config_builder.dart';

void main() {
  const XrayConfigBuilder builder = XrayConfigBuilder();

  test('builds VLESS Reality outbound and local inbounds', () {
    const ServerProfile server = ServerProfile(
      id: 'id',
      name: 'Reality',
      protocol: ProxyProtocol.vless,
      host: 'server.example',
      port: 443,
      secret: '11111111-1111-1111-1111-111111111111',
      sourceUri: 'vless://redacted',
      method: 'none',
      security: 'reality',
      sni: 'www.example.com',
      fingerprint: 'chrome',
      publicKey: 'public-key',
      shortId: 'abcd',
    );

    final Map<String, Object?> config = builder.build(
      server: server,
      socksPort: 10808,
      httpPort: 10809,
    );
    final List<Object?> inbounds = config['inbounds']! as List<Object?>;
    final List<Object?> outbounds = config['outbounds']! as List<Object?>;
    final Map<String, Object?> proxy = outbounds.first! as Map<String, Object?>;
    final Map<String, Object?> stream =
        proxy['streamSettings']! as Map<String, Object?>;
    final Map<String, Object?> reality =
        stream['realitySettings']! as Map<String, Object?>;

    expect(inbounds, hasLength(2));
    expect((inbounds.first! as Map<String, Object?>)['port'], 10808);
    expect(proxy['protocol'], 'vless');
    expect(stream['security'], 'reality');
    expect(reality['publicKey'], 'public-key');
    expect(reality['serverName'], 'www.example.com');
  });

  test('builds VMess websocket TLS settings', () {
    const ServerProfile server = ServerProfile(
      id: 'id',
      name: 'WS',
      protocol: ProxyProtocol.vmess,
      host: 'server.example',
      port: 443,
      secret: '11111111-1111-1111-1111-111111111111',
      sourceUri: 'vmess://redacted',
      method: 'auto',
      network: 'ws',
      security: 'tls',
      sni: 'server.example',
      hostHeader: 'cdn.example',
      path: '/ws',
    );

    final Map<String, Object?> config = builder.build(
      server: server,
      socksPort: 10808,
      httpPort: 10809,
    );
    final Map<String, Object?> proxy =
        (config['outbounds']! as List<Object?>).first! as Map<String, Object?>;
    final Map<String, Object?> stream =
        proxy['streamSettings']! as Map<String, Object?>;
    final Map<String, Object?> ws =
        stream['wsSettings']! as Map<String, Object?>;

    expect(stream['network'], 'ws');
    expect(ws['path'], '/ws');
    expect((ws['headers']! as Map<String, Object?>)['Host'], 'cdn.example');
  });
}
