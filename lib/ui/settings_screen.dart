import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.onOpenAbout,
    super.key,
  });

  final AppController controller;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = controller.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      children: <Widget>[
        _Section(
          title: 'اتصال',
          children: <Widget>[
            SwitchListTile(
              value: settings.systemProxy,
              onChanged: controller.connectionState == VpnConnectionState.connected
                  ? null
                  : (bool value) => unawaited(
                        controller.updateSettings(
                          settings.copyWith(systemProxy: value),
                        ),
                      ),
              secondary: const Icon(Icons.laptop_windows_rounded),
              title: const Text('فعال‌سازی اتصال سیستم'),
              subtitle: const Text(
                'ترافیک برنامه‌هایی که از Proxy ویندوز پیروی می‌کنند عبور داده می‌شود.',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cable_rounded),
              title: const Text('پورت‌های محلی'),
              subtitle: Text(
                'SOCKS: ${settings.socksPort}   •   HTTP: ${settings.httpPort}',
                textDirection: TextDirection.ltr,
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: controller.connectionState == VpnConnectionState.connected
                  ? null
                  : () => _editPorts(context),
            ),
            const Divider(height: 1),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.vpn_lock_outlined),
              title: Text('حالت TUN'),
              subtitle: Text('در نسخهٔ بعدی؛ نیازمند دسترسی Administrator و Wintun'),
              trailing: Chip(label: Text('به‌زودی')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'برنامه',
          children: <Widget>[
            SwitchListTile(
              value: settings.startWithWindows,
              onChanged: (bool value) => unawaited(
                controller.updateSettings(
                  settings.copyWith(startWithWindows: value),
                ),
              ),
              secondary: const Icon(Icons.rocket_launch_outlined),
              title: const Text('اجرا همراه ویندوز'),
              subtitle: const Text('MobileTinaVPN بعد از ورود به ویندوز اجرا شود.'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('ظاهر برنامه'),
              subtitle: Text(_themeLabel(settings.theme)),
              trailing: DropdownButton<ThemePreference>(
                value: settings.theme,
                underline: const SizedBox.shrink(),
                onChanged: (ThemePreference? value) {
                  if (value != null) {
                    unawaited(
                      controller.updateSettings(settings.copyWith(theme: value)),
                    );
                  }
                },
                items: const <DropdownMenuItem<ThemePreference>>[
                  DropdownMenuItem(
                    value: ThemePreference.system,
                    child: Text('سیستم'),
                  ),
                  DropdownMenuItem(
                    value: ThemePreference.light,
                    child: Text('روشن'),
                  ),
                  DropdownMenuItem(
                    value: ThemePreference.dark,
                    child: Text('تیره'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('گزارش برنامه'),
              subtitle: const Text('نمایش گزارش‌های فنی بدون لینک یا رمز اشتراک'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showLogs(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'درباره',
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('MobileTinaVPN for Windows'),
              subtitle: Text(
                'نسخه 0.4.0 • نسخهٔ پرتابل ویندوز\n'
                'داده‌ها به‌صورت پرتابل در پوشهٔ portable-data نگهداری می‌شوند.',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: const Text('درباره موبایل تینا'),
              subtitle: const Text('شبکه‌های اجتماعی و آدرس فروشگاه‌ها'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: onOpenAbout,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editPorts(BuildContext context) async {
    final TextEditingController socks = TextEditingController(
      text: '${controller.settings.socksPort}',
    );
    final TextEditingController http = TextEditingController(
      text: '${controller.settings.httpPort}',
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('پورت‌های محلی'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: socks,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(labelText: 'SOCKS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: http,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(labelText: 'HTTP'),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('بیخیال'),
          ),
          FilledButton(
            onPressed: () async {
              final int? socksPort = int.tryParse(socks.text);
              final int? httpPort = int.tryParse(http.text);
              if (socksPort == null ||
                  httpPort == null ||
                  socksPort < 1024 ||
                  socksPort > 65535 ||
                  httpPort < 1024 ||
                  httpPort > 65535 ||
                  socksPort == httpPort) {
                return;
              }
              await controller.updateSettings(
                controller.settings.copyWith(
                  socksPort: socksPort,
                  httpPort: httpPort,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    socks.dispose();
    http.dispose();
  }

  Future<void> _showLogs(BuildContext context) async {
    final String log = await controller.store.readLog();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('گزارش برنامه'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 390),
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Text(
                log.isEmpty ? 'هنوز گزارشی ثبت نشده است.' : log,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => unawaited(
              Clipboard.setData(ClipboardData(text: log)),
            ),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('کپی'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 5, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

String _themeLabel(ThemePreference preference) {
  return switch (preference) {
    ThemePreference.system => 'هماهنگ با ویندوز',
    ThemePreference.light => 'روشن',
    ThemePreference.dark => 'تیره',
  };
}
