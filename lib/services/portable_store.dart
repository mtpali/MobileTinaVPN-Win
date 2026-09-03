import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/subscription.dart';

class StoredState {
  const StoredState({
    required this.settings,
    required this.subscriptions,
    this.selectedServerId,
  });

  final AppSettings settings;
  final List<Subscription> subscriptions;
  final String? selectedServerId;
}

class PortableStore {
  PortableStore({Directory? executableDirectory})
      : root = Directory(
          '${(executableDirectory ?? File(Platform.resolvedExecutable).parent).path}'
          '${Platform.pathSeparator}portable-data',
        );

  final Directory root;

  File get stateFile => File('${root.path}${Platform.pathSeparator}state.json');
  File get runtimeConfigFile => File(
        '${root.path}${Platform.pathSeparator}runtime'
        '${Platform.pathSeparator}xray.json',
      );
  File get activeSessionFile => File(
        '${root.path}${Platform.pathSeparator}runtime'
        '${Platform.pathSeparator}active-session.json',
      );
  File get previousProxyFile => File(
        '${root.path}${Platform.pathSeparator}runtime'
        '${Platform.pathSeparator}previous-proxy.json',
      );
  File get logFile => File(
        '${root.path}${Platform.pathSeparator}logs'
        '${Platform.pathSeparator}mobiletina.log',
      );

  Future<void> initialize() async {
    await root.create(recursive: true);
    await runtimeConfigFile.parent.create(recursive: true);
    await logFile.parent.create(recursive: true);
  }

  Future<StoredState> load() async {
    await initialize();
    if (!await stateFile.exists()) {
      return const StoredState(
        settings: AppSettings(),
        subscriptions: <Subscription>[],
      );
    }
    try {
      final Object? decoded = jsonDecode(await stateFile.readAsString());
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final List<Object?> rawSubscriptions =
          decoded['subscriptions'] as List<Object?>? ?? <Object?>[];
      return StoredState(
        settings: AppSettings.fromJson(
          decoded['settings']! as Map<String, Object?>,
        ),
        subscriptions: rawSubscriptions
            .map(
              (Object? value) =>
                  Subscription.fromJson(value! as Map<String, Object?>),
            )
            .toList(),
        selectedServerId: decoded['selectedServerId'] as String?,
      );
    } on Object catch (error) {
      await appendLog('State file could not be read: $error');
      return const StoredState(
        settings: AppSettings(),
        subscriptions: <Subscription>[],
      );
    }
  }

  Future<void> save(StoredState state) async {
    await initialize();
    final File temporary = File('${stateFile.path}.tmp');
    final String contents = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'schemaVersion': 1,
        'settings': state.settings.toJson(),
        'subscriptions': state.subscriptions
            .map((Subscription item) => item.toJson())
            .toList(),
        'selectedServerId': state.selectedServerId,
      },
    );
    await temporary.writeAsString(contents, flush: true);
    if (await stateFile.exists()) await stateFile.delete();
    await temporary.rename(stateFile.path);
  }

  Future<void> appendLog(String message) async {
    await initialize();
    final String sanitized = message.replaceAll(RegExp(r'[\r\n]+'), ' ');
    await logFile.writeAsString(
      '${DateTime.now().toUtc().toIso8601String()} $sanitized\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<String> readLog({int maxCharacters = 30000}) async {
    if (!await logFile.exists()) return '';
    final String value = await logFile.readAsString();
    if (value.length <= maxCharacters) return value;
    return value.substring(value.length - maxCharacters);
  }

  Future<void> reset() async {
    if (await root.exists()) await root.delete(recursive: true);
    await initialize();
  }
}
