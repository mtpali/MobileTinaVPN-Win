import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';
import '../services/protected_assets.dart';
import 'about_mobile_tina_screen.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'protected_image.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

class MobileTinaApp extends StatelessWidget {
  const MobileTinaApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'MobileTinaVPN',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (controller.settings.theme) {
            ThemePreference.system => ThemeMode.system,
            ThemePreference.light => ThemeMode.light,
            ThemePreference.dark => ThemeMode.dark,
          },
          locale: const Locale('fa'),
          builder: (BuildContext context, Widget? child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: AppShell(controller: controller),
        );
      },
    );
  }
}

enum AppPage { home, about, servers, settings }

enum _ConfigOperation {
  importClipboard,
  testSpeed,
  updateSubscriptions,
  removeDuplicates,
  removeInactive,
  removeAll,
}

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage page = AppPage.home;
  bool operationRunning = false;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (page) {
      AppPage.home => HomeScreen(
          controller: widget.controller,
          onOpenServers: () => setState(() => page = AppPage.servers),
        ),
      AppPage.about => AboutMobileTinaScreen(
          platform: widget.controller.platform,
        ),
      AppPage.servers => ServersScreen(controller: widget.controller),
      AppPage.settings => SettingsScreen(
          controller: widget.controller,
          onOpenAbout: () => setState(() => page = AppPage.about),
        ),
    };
    final bool promotionalPage = page == AppPage.about;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (page) {
            AppPage.home => 'فیلترشکن',
            AppPage.about => 'درباره موبایل تینا',
            AppPage.servers => 'سرورها و اشتراک‌ها',
            AppPage.settings => 'تنظیمات',
          },
        ),
        backgroundColor: promotionalPage ? const Color(0xff111315) : null,
        foregroundColor: promotionalPage ? Colors.white : null,
        actions: <Widget>[
          if (page == AppPage.home)
            Builder(
              builder: (BuildContext context) => IconButton(
                tooltip: 'مدیریت کانفیگ‌ها',
                onPressed: operationRunning
                    ? null
                    : () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _SideBar(
            page: page,
            state: widget.controller.connectionState,
            onReset: () {
              Navigator.of(context).pop();
              unawaited(_confirmReset());
            },
            onSelected: (AppPage value) {
              Navigator.of(context).pop();
              setState(() => page = value);
            },
          ),
        ),
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: _OperationsDrawer(
            busy: operationRunning || widget.controller.isBusy,
            canTest: widget.controller.servers.isNotEmpty &&
                widget.controller.connectionState !=
                    VpnConnectionState.connected,
            canUpdate: widget.controller.subscriptions.any(
              (subscription) => subscription.isRemote,
            ),
            onSelected: (_ConfigOperation operation) {
              Navigator.of(context).pop();
              unawaited(_runConfigOperation(operation));
            },
          ),
        ),
      ),
      body: SafeArea(top: false, child: content),
    );
  }

  Future<void> _runConfigOperation(_ConfigOperation operation) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    if (operation == _ConfigOperation.removeDuplicates &&
        !await _confirm(
          title: 'حذف کانفیگ مشابه',
          message: 'کانفیگ‌های مشابه حذف شوند؟ یک نسخه از هر کانفیگ باقی می‌ماند.',
        )) {
      return;
    }
    if (operation == _ConfigOperation.removeInactive &&
        !await _confirm(
          title: 'حذف کانفیگ غیرفعال',
          message: 'کانفیگ‌هایی که در آخرین تست غیرفعال شناخته شده‌اند حذف شوند؟',
        )) {
      return;
    }
    if (operation == _ConfigOperation.removeAll &&
        !await _confirm(
          title: 'حذف تمام کانفیگ‌ها',
          message: 'تمام کانفیگ‌ها حذف شوند؟ این عملیات قابل بازگشت نیست.',
        )) {
      return;
    }

    setState(() => operationRunning = true);
    try {
      switch (operation) {
        case _ConfigOperation.importClipboard:
          final ClipboardData? data = await Clipboard.getData(
            Clipboard.kTextPlain,
          );
          final int imported = await widget.controller
              .importServersFromClipboard(data?.text ?? '');
          _message('$imported سرور از کلیپ‌بورد اضافه شد.');
          break;
        case _ConfigOperation.testSpeed:
          if (widget.controller.servers.isEmpty) {
            throw const _OperationException('هنوز کانفیگی اضافه نشده است.');
          }
          await widget.controller.testServers();
          _message('تست سرعت سرورها پایان یافت.');
          break;
        case _ConfigOperation.updateSubscriptions:
          final int count = widget.controller.subscriptions
              .where((subscription) => subscription.isRemote)
              .length;
          if (count == 0) {
            throw const _OperationException(
              'اشتراک قابل بروزرسانی وجود ندارد.',
            );
          }
          await widget.controller.updateAllSubscriptions();
          _message('$count اشتراک بروزرسانی شد.');
          break;
        case _ConfigOperation.removeDuplicates:
          final int removed = await widget.controller.removeDuplicateServers();
          _message(
            removed == 0
                ? 'کانفیگ مشابهی پیدا نشد.'
                : '$removed کانفیگ مشابه حذف شد.',
          );
          break;
        case _ConfigOperation.removeInactive:
          final int removed = await widget.controller.removeInactiveServers();
          _message(
            removed == 0
                ? 'کانفیگ غیرفعالی پیدا نشد.'
                : '$removed کانفیگ غیرفعال حذف شد.',
          );
          break;
        case _ConfigOperation.removeAll:
          final int removed = await widget.controller.removeAllServers();
          _message(
            removed == 0
                ? 'کانفیگی برای حذف وجود ندارد.'
                : '$removed کانفیگ حذف شد.',
          );
          break;
      }
    } on Object catch (error) {
      _message('$error', error: true);
    } finally {
      if (mounted) setState(() => operationRunning = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('بیخیال'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmReset() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final bool confirmed = await _confirm(
      title: 'حذف فیلترشکن',
      message: 'تمام اشتراک‌ها، کانفیگ‌ها و تنظیمات برنامه پاک شوند؟',
    );
    if (!confirmed || !mounted) return;
    await widget.controller.reset();
    if (mounted) setState(() => page = AppPage.home);
    _message('اطلاعات فیلترشکن حذف شد.');
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _OperationException implements Exception {
  const _OperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.page,
    required this.state,
    required this.onReset,
    required this.onSelected,
  });

  final AppPage page;
  final VpnConnectionState state;
  final VoidCallback onReset;
  final ValueChanged<AppPage> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Transform.scale(
                    scale: 1.12,
                    child: const ProtectedImage(
                      ProtectedImageAsset.brandIcon,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'MobileTinaVPN',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text('نسخهٔ ویندوز', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          _NavButton(
            selected: page == AppPage.about,
            icon: Icons.storefront_rounded,
            label: 'درباره موبایل تینا',
            onTap: () => onSelected(AppPage.about),
          ),
          const Divider(height: 24),
          _NavButton(
            selected: page == AppPage.home,
            icon: Icons.home_rounded,
            label: 'خانه',
            onTap: () => onSelected(AppPage.home),
          ),
          _NavButton(
            selected: page == AppPage.servers,
            icon: Icons.dns_rounded,
            label: 'سرورها و اشتراک‌ها',
            onTap: () => onSelected(AppPage.servers),
          ),
          _NavButton(
            selected: page == AppPage.settings,
            icon: Icons.settings_rounded,
            label: 'تنظیمات',
            onTap: () => onSelected(AppPage.settings),
          ),
          const Divider(height: 24),
          _NavButton(
            selected: false,
            danger: true,
            icon: Icons.delete_forever_outlined,
            label: 'حذف فیلترشکن',
            onTap: onReset,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  state == VpnConnectionState.connected
                      ? Icons.verified_rounded
                      : Icons.shield_outlined,
                  color: state == VpnConnectionState.connected
                      ? const Color(0xff17a05d)
                      : colors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state == VpnConnectionState.connected
                        ? 'اتصال سیستم فعال است'
                        : 'اتصال سیستم خاموش است',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : danger
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : danger
                            ? Theme.of(context).colorScheme.error
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationsDrawer extends StatelessWidget {
  const _OperationsDrawer({
    required this.busy,
    required this.canTest,
    required this.canUpdate,
    required this.onSelected,
  });

  final bool busy;
  final bool canTest;
  final bool canUpdate;
  final ValueChanged<_ConfigOperation> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
      children: <Widget>[
        const ListTile(
          leading: Icon(Icons.tune_rounded),
          title: Text(
            'مدیریت کانفیگ‌ها',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const Divider(),
        _operationTile(
          context,
          operation: _ConfigOperation.importClipboard,
          icon: Icons.content_paste_go_rounded,
          label: 'افزودن کانفیگ از کلیپ‌بورد',
        ),
        _operationTile(
          context,
          operation: _ConfigOperation.testSpeed,
          icon: Icons.speed_rounded,
          label: 'تست سرعت',
          enabled: canTest,
        ),
        _operationTile(
          context,
          operation: _ConfigOperation.updateSubscriptions,
          icon: Icons.refresh_rounded,
          label: 'بروزرسانی اشتراک',
          enabled: canUpdate,
        ),
        const Divider(height: 24),
        _operationTile(
          context,
          operation: _ConfigOperation.removeDuplicates,
          icon: Icons.copy_all_rounded,
          label: 'حذف کانفیگ مشابه',
          destructive: true,
        ),
        _operationTile(
          context,
          operation: _ConfigOperation.removeInactive,
          icon: Icons.block_rounded,
          label: 'حذف کانفیگ غیرفعال',
          destructive: true,
        ),
        _operationTile(
          context,
          operation: _ConfigOperation.removeAll,
          icon: Icons.delete_sweep_outlined,
          label: 'حذف تمام کانفیگ‌ها',
          destructive: true,
        ),
      ],
    );
  }

  Widget _operationTile(
    BuildContext context, {
    required _ConfigOperation operation,
    required IconData icon,
    required String label,
    bool enabled = true,
    bool destructive = false,
  }) {
    final bool active = enabled && !busy;
    final Color? color = destructive && active
        ? Theme.of(context).colorScheme.error
        : null;
    return ListTile(
      enabled: active,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_left_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: active ? () => onSelected(operation) : null,
    );
  }
}
