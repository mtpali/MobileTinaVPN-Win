import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';
import 'about_mobile_tina_screen.dart';
import 'app_theme.dart';
import 'home_screen.dart';
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

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage page = AppPage.home;

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
            IconButton(
              tooltip: 'بررسی سرعت سرورها',
              onPressed: widget.controller.isBusy
                  ? null
                  : widget.controller.testServers,
              icon: const Icon(Icons.speed_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _SideBar(
            page: page,
            state: widget.controller.connectionState,
            onSelected: (AppPage value) {
              Navigator.of(context).pop();
              setState(() => page = value);
            },
          ),
        ),
      ),
      body: SafeArea(top: false, child: content),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.page,
    required this.state,
    required this.onSelected,
  });

  final AppPage page;
  final VpnConnectionState state;
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
                    child: Image.asset(
                      'assets/branding/icon.webp',
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
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
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
