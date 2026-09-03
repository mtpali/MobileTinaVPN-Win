import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';
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

enum AppPage { home, servers, settings }

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
    final bool compact = MediaQuery.sizeOf(context).width < 780;
    final Widget content = switch (page) {
      AppPage.home => HomeScreen(
          controller: widget.controller,
          onOpenServers: () => setState(() => page = AppPage.servers),
        ),
      AppPage.servers => ServersScreen(controller: widget.controller),
      AppPage.settings => SettingsScreen(controller: widget.controller),
    };

    return Scaffold(
      body: SafeArea(
        child: compact
            ? content
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: content,
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: _SideBar(
                        page: page,
                        state: widget.controller.connectionState,
                        onSelected: (AppPage value) =>
                            setState(() => page = value),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: page.index,
              onDestinationSelected: (int value) =>
                  setState(() => page = AppPage.values[value]),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'خانه',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dns_outlined),
                  selectedIcon: Icon(Icons.dns_rounded),
                  label: 'سرورها',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'تنظیمات',
                ),
              ],
            )
          : null,
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
      width: 226,
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
                child: Image.asset(
                  'assets/branding/icon.webp',
                  width: 48,
                  height: 48,
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
