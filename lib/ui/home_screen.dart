import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_controller.dart';
import '../models/server_profile.dart';
import '../models/subscription.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.controller,
    required this.onOpenServers,
    super.key,
  });

  final AppController controller;
  final VoidCallback onOpenServers;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool automatic = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.connectedAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
          child: _ModeSwitch(
            automatic: automatic,
            onChanged: (bool value) => setState(() => automatic = value),
          ),
        ),
        Expanded(
          child: automatic
              ? _AutomaticPanel(
                  controller: widget.controller,
                  onOpenServers: widget.onOpenServers,
                )
              : _ManualPanel(
                  controller: widget.controller,
                  onOpenServers: widget.onOpenServers,
                ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.automatic, required this.onChanged});

  final bool automatic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff17181c) : const Color(0xfff1f2f6),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              label: 'حالت خودکار',
              selected: automatic,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeButton(
              label: 'حالت دستی',
              selected: !automatic,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? (dark ? const Color(0xfff4f5f7) : const Color(0xff17181c))
          : Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected
                  ? (dark ? const Color(0xff17181c) : Colors.white)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomaticPanel extends StatelessWidget {
  const _AutomaticPanel({
    required this.controller,
    required this.onOpenServers,
  });

  final AppController controller;
  final VoidCallback onOpenServers;

  @override
  Widget build(BuildContext context) {
    final ServerProfile? server = controller.selectedServer;
    final Subscription? subscription = controller.selectedSubscription;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 70, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: <Widget>[
              Semantics(
                button: true,
                label: _statusText(controller.connectionState),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: controller.isBusy
                      ? null
                      : () => unawaited(controller.toggleConnection(smart: true)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Image.asset(
                      _imageForState(controller.connectionState),
                      key: ValueKey<VpnConnectionState>(controller.connectionState),
                      width: 236,
                      height: 236,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _statusText(controller.connectionState),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                controller.errorMessage ?? _connectionDetail(controller),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: controller.errorMessage == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              if (server == null)
                OutlinedButton.icon(
                  onPressed: onOpenServers,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('افزودن اشتراک'),
                )
              else
                _SelectedServerLink(
                  server: server,
                  expired: controller.isServerExpired(server.id),
                  onTap: onOpenServers,
                ),
              if (subscription != null) ...<Widget>[
                const SizedBox(height: 26),
                _SubscriptionCard(subscription: subscription),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({
    required this.controller,
    required this.onOpenServers,
  });

  final AppController controller;
  final VoidCallback onOpenServers;

  @override
  Widget build(BuildContext context) {
    final List<ServerProfile> servers = controller.servers;
    if (servers.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: onOpenServers,
          icon: const Icon(Icons.add_link_rounded),
          label: const Text('افزودن اشتراک'),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            itemCount: servers.length,
            itemBuilder: (BuildContext context, int index) {
              final ServerProfile server = servers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ServerTile(
                  server: server,
                  expired: controller.isServerExpired(server.id),
                  selected: controller.selectedServerId == server.id,
                  enabled: controller.connectionState !=
                          VpnConnectionState.connected &&
                      !controller.isServerExpired(server.id) &&
                      !server.isInactive,
                  onTap: () => unawaited(controller.selectServer(server.id)),
                  onShare: () => unawaited(
                    _showServerShareDialog(context, server),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 78,
                height: 78,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: controller.isBusy
                      ? null
                      : () => unawaited(controller.toggleConnection()),
                  child: Image.asset(
                    controller.connectionState == VpnConnectionState.connected
                        ? 'assets/connection/manual_on.webp'
                        : 'assets/connection/manual_off.webp',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.selectedServer?.name ?? 'سروری انتخاب نشده',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 7),
                    OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => unawaited(controller.smartConnect()),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('اتصال خودکار'),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'بررسی سرعت سرورها',
                onPressed: controller.isBusy
                    ? null
                    : () => unawaited(controller.testServers()),
                icon: const Icon(Icons.speed_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedServerLink extends StatelessWidget {
  const _SelectedServerLink({
    required this.server,
    required this.expired,
    required this.onTap,
  });

  final ServerProfile server;
  final bool expired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        expired ? '${server.name} • اشتراک منقضی' : server.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: expired ? Theme.of(context).colorScheme.error : null,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final SubscriptionUsage usage = subscription.usage;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Text(subscription.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (usage.total > 0) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: usage.fraction,
                minHeight: 8,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  usage.isExpired
                      ? 'اشتراک منقضی شده'
                      : usage.daysRemaining == null
                      ? '${subscription.servers.length} سرور'
                      : '${usage.daysRemaining} روز باقی‌مانده',
                  textAlign: TextAlign.start,
                ),
              ),
              if (usage.total > 0)
                Text(
                  '${_bytes(usage.used)} / ${_bytes(usage.total)}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.expired,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onShare,
  });

  final ServerProfile server;
  final bool expired;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (Theme.of(context).brightness == Brightness.light
              ? const Color(0xffeef4ff)
              : const Color(0xff202a3d))
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: server.isInactive
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.62)
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.protocolLabel,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _LatencyChip(latency: server.latencyMs, expired: expired),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'اشتراک‌گذاری سرور',
                onPressed: onShare,
                icon: const Icon(Icons.qr_code_2_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatencyChip extends StatelessWidget {
  const _LatencyChip({required this.latency, this.expired = false});

  final int? latency;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final bool active = latency != null && latency! > 0 && !expired;
    final bool inactive = latency != null && latency! < 0 && !expired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: expired
            ? (Theme.of(context).brightness == Brightness.light
                ? const Color(0xfffdeDEE)
                : const Color(0xff3a2024))
            : inactive
                ? (Theme.of(context).brightness == Brightness.light
                    ? const Color(0xfffdeDEE)
                    : const Color(0xff3a2024))
                : active
                    ? (Theme.of(context).brightness == Brightness.light
                        ? const Color(0xffeef8f1)
                        : const Color(0xff183426))
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        expired
            ? 'منقضی'
            : inactive
                ? 'غیرفعال'
                : active
                    ? '${latency}ms'
                    : '—',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: expired
              ? Theme.of(context).colorScheme.error
              : inactive
                  ? Theme.of(context).colorScheme.error
                  : active
                      ? const Color(0xff16834f)
                      : null,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _imageForState(VpnConnectionState state) {
  return switch (state) {
    VpnConnectionState.disconnected => 'assets/connection/idle.webp',
    VpnConnectionState.testing || VpnConnectionState.connecting =>
      'assets/connection/connecting.webp',
    VpnConnectionState.connected => 'assets/connection/connected.webp',
    VpnConnectionState.failed => 'assets/connection/error.webp',
  };
}

String _statusText(VpnConnectionState state) {
  return switch (state) {
    VpnConnectionState.disconnected => 'فیلترشکن خاموش است',
    VpnConnectionState.testing => 'در حال یافتن بهترین سرور…',
    VpnConnectionState.connecting => 'در حال اتصال…',
    VpnConnectionState.connected => 'متصل شد',
    VpnConnectionState.failed => 'اتصال ناموفق بود',
  };
}

String _connectionDetail(AppController controller) {
  final ServerProfile? server = controller.selectedServer;
  if (controller.connectionState == VpnConnectionState.connected &&
      controller.connectedAt != null) {
    final Duration elapsed = DateTime.now().difference(controller.connectedAt!);
    final String hours = elapsed.inHours.toString().padLeft(2, '0');
    final String minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds • ${server?.name ?? ''}';
  }
  if (controller.connectionState == VpnConnectionState.testing) {
    return 'سرورهای قابل‌دسترسی بررسی می‌شوند';
  }
  if (server?.isInactive ?? false) return 'سرور غیرفعال است';
  if (server?.hasSuccessfulLatency ?? false) {
    return 'پینگ: ${server!.latencyMs} میلی‌ثانیه';
  }
  return server == null ? 'هنوز سروری اضافه نشده است' : 'برای اتصال، دکمه را بزنید';
}

Future<void> _showServerShareDialog(
  BuildContext context,
  ServerProfile server,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(server.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 330,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: server.sourceUri,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              server.protocolLabel,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('بستن'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: server.sourceUri));
            if (!dialogContext.mounted || !context.mounted) return;
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('کانفیگ سرور کپی شد.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('کپی کانفیگ'),
        ),
      ],
    ),
  );
}

String _bytes(int value) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double size = value.toDouble();
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
