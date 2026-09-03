import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobiletina_vpn/models/app_settings.dart';
import 'package:mobiletina_vpn/models/subscription.dart';
import 'package:mobiletina_vpn/services/portable_store.dart';
import 'package:mobiletina_vpn/services/vault_cipher.dart';

void main() {
  test('vault round trip authenticates context and rejects tampering', () async {
    const String clearText = 'sensitive subscription payload';
    final List<int> sealed = await VaultCipher.instance.sealText(
      clearText,
      context: 'test-context',
    );

    expect(utf8.decode(sealed, allowMalformed: true), isNot(contains(clearText)));
    expect(
      await VaultCipher.instance.openText(sealed, context: 'test-context'),
      clearText,
    );

    sealed[sealed.length ~/ 2] ^= 1;
    await expectLater(
      VaultCipher.instance.openText(sealed, context: 'test-context'),
      throwsA(isA<VaultException>()),
    );
  });

  test('portable state is encrypted and remains readable', () async {
    final Directory temporary = await Directory.systemTemp.createTemp(
      'mobiletina-vault-test-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final PortableStore store = PortableStore(executableDirectory: temporary);
    const String subscriptionUrl = 'https://private.example/subscription-token';
    final StoredState state = StoredState(
      settings: const AppSettings(httpPort: 19090),
      subscriptions: <Subscription>[
        Subscription(
          id: 'private',
          name: 'Private',
          url: subscriptionUrl,
          servers: const [],
          updatedAt: DateTime.utc(2026),
        ),
      ],
      selectedServerId: 'server-id',
    );

    await store.save(state);

    expect(store.stateFile.path, endsWith('state.dat'));
    final String raw = utf8.decode(
      await store.stateFile.readAsBytes(),
      allowMalformed: true,
    );
    expect(raw, isNot(contains(subscriptionUrl)));
    final StoredState restored = await store.load();
    expect(restored.settings.httpPort, 19090);
    expect(restored.subscriptions.single.url, subscriptionUrl);
    expect(restored.selectedServerId, 'server-id');
  });

  test('legacy plaintext state migrates once to protected storage', () async {
    final Directory temporary = await Directory.systemTemp.createTemp(
      'mobiletina-migration-test-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final PortableStore store = PortableStore(executableDirectory: temporary);
    await store.initialize();
    final File legacy = File(
      '${store.root.path}${Platform.pathSeparator}state.json',
    );
    await legacy.writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'settings': const AppSettings().toJson(),
        'subscriptions': <Object>[],
        'selectedServerId': null,
      }),
    );

    final StoredState restored = await store.load();

    expect(restored.subscriptions, isEmpty);
    expect(await store.stateFile.exists(), isTrue);
    expect(await legacy.exists(), isFalse);
  });
}
