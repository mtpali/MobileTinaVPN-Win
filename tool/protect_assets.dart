import 'dart:io';

import 'package:mobiletina_vpn/services/vault_cipher.dart';

const Map<String, ({String output, String context})> _manifest =
    <String, ({String output, String context})>{
  'branding/icon.webp': (
    output: 'p0.mtv',
    context: 'asset:image:brandIcon',
  ),
  'connection/idle.webp': (
    output: 'p1.mtv',
    context: 'asset:image:disconnected',
  ),
  'connection/connecting.webp': (
    output: 'p2.mtv',
    context: 'asset:image:connecting',
  ),
  'connection/connected.webp': (
    output: 'p3.mtv',
    context: 'asset:image:connected',
  ),
  'connection/error.webp': (
    output: 'p4.mtv',
    context: 'asset:image:failed',
  ),
  'connection/manual_off.webp': (
    output: 'p5.mtv',
    context: 'asset:image:manualOff',
  ),
  'connection/manual_on.webp': (
    output: 'p6.mtv',
    context: 'asset:image:manualOn',
  ),
  'fonts/Vazirmatn-UI-Regular.ttf': (
    output: 'f0.mtv',
    context: 'asset:font:regular',
  ),
  'fonts/Vazirmatn-UI-SemiBold.ttf': (
    output: 'f1.mtv',
    context: 'asset:font:semibold',
  ),
  'fonts/Vazirmatn-UI-Bold.ttf': (
    output: 'f2.mtv',
    context: 'asset:font:bold',
  ),
};

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/protect_assets.dart <source-dir> <output-dir>',
    );
    exitCode = 64;
    return;
  }
  final Directory source = Directory(arguments.first);
  final Directory output = Directory(arguments.last);
  await output.create(recursive: true);

  for (final MapEntry<String, ({String output, String context})> entry
      in _manifest.entries) {
    final File input = File(
      '${source.path}${Platform.pathSeparator}'
      '${entry.key.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await input.exists()) {
      throw FileSystemException('Source asset not found', input.path);
    }
    final File target = File(
      '${output.path}${Platform.pathSeparator}${entry.value.output}',
    );
    await target.writeAsBytes(
      await VaultCipher.instance.seal(
        await input.readAsBytes(),
        context: entry.value.context,
      ),
      flush: true,
    );
  }
}
