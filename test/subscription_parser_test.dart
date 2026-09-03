import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobiletina_vpn/models/server_profile.dart';
import 'package:mobiletina_vpn/services/subscription_parser.dart';

void main() {
  final SubscriptionParser parser = SubscriptionParser();

  test('parses base64 encoded mixed subscription', () {
    final String vmess = 'vmess://${base64Encode(utf8.encode(jsonEncode(<String, String>{
          'v': '2',
          'ps': 'Germany',
          'add': 'example.com',
          'port': '443',
          'id': '11111111-1111-1111-1111-111111111111',
          'scy': 'auto',
          'net': 'ws',
          'host': 'cdn.example.com',
          'path': '/socket',
          'tls': 'tls',
          'sni': 'example.com',
        })))}';
    const String vless =
        'vless://22222222-2222-2222-2222-222222222222@server.example:443'
        '?encryption=none&security=reality&type=tcp&sni=www.example.com'
        '&fp=chrome&pbk=public-key&sid=abcd#Finland';
    final String payload = base64Encode(utf8.encode('$vmess\n$vless'));

    final SubscriptionParseResult result = parser.parse(payload);

    expect(result.rejectedCount, 0);
    expect(result.servers, hasLength(2));
    expect(result.servers.first.protocol, ProxyProtocol.vmess);
    expect(result.servers.first.network, 'ws');
    expect(result.servers.first.hostHeader, 'cdn.example.com');
    expect(result.servers.last.protocol, ProxyProtocol.vless);
    expect(result.servers.last.security, 'reality');
    expect(result.servers.last.publicKey, 'public-key');
  });

  test('parses SIP002 and legacy Shadowsocks forms', () {
    final String credentials = base64Url
        .encode(utf8.encode('aes-256-gcm:password'))
        .replaceAll('=', '');
    final ServerProfile sip = parser.parseUri(
      'ss://$credentials@ss.example:8388#Netherlands',
    )!;
    final String legacyBody = base64Url
        .encode(utf8.encode('chacha20-ietf-poly1305:secret@legacy.example:443'))
        .replaceAll('=', '');
    final ServerProfile legacy = parser.parseUri('ss://$legacyBody')!;

    expect(sip.method, 'aes-256-gcm');
    expect(sip.secret, 'password');
    expect(sip.name, 'Netherlands');
    expect(legacy.host, 'legacy.example');
    expect(legacy.port, 443);
  });

  test('deduplicates profiles and counts rejected lines', () {
    const String server =
        'trojan://password@example.com:443?security=tls#Server';
    final SubscriptionParseResult result = parser.parse(
      '$server\n$server\nnot-a-config',
    );

    expect(result.servers, hasLength(1));
    expect(result.rejectedCount, 1);
  });
}
