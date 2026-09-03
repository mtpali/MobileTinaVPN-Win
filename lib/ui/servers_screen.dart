import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/server_profile.dart';
import '../models/subscription.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  bool updating = false;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final List<ServerProfile> servers = widget.controller.servers
        .where(
          (ServerProfile item) => item.name.toLowerCase().contains(
                query.trim().toLowerCase(),
              ),
        )
        .toList();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('افزودن اشتراک'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'افزودن سرور از کلیپ‌بورد',
                onPressed: updating ? null : _importFromClipboard,
                icon: const Icon(Icons.content_paste_go_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'بروزرسانی همه',
                onPressed: updating ||
                        !widget.controller.subscriptions.any(
                          (Subscription item) => item.isRemote,
                        )
                    ? null
                    : _updateAll,
                icon: updating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
          child: TextField(
            onChanged: (String value) => setState(() => query = value),
            decoration: const InputDecoration(
              hintText: 'جست‌وجوی سرور…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: widget.controller.subscriptions.isEmpty
              ? _EmptyState(onAdd: _showAddDialog)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  children: <Widget>[
                    ...widget.controller.subscriptions.map(
                      (Subscription item) => _SubscriptionHeader(
                        subscription: item,
                        onUpdate: () => _updateOne(item.id),
                        onDelete: () => _confirmDelete(item),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Text(
                          '${servers.length} سرور',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: widget.controller.isBusy
                              ? null
                              : () => unawaited(widget.controller.testServers()),
                          icon: const Icon(Icons.speed_rounded),
                          label: const Text('بررسی سرعت'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ...servers.map(
                      (ServerProfile server) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _ServerCard(
                          server: server,
                          expired: widget.controller.isServerExpired(server.id),
                          selected:
                              widget.controller.selectedServerId == server.id,
                          enabled: widget.controller.connectionState !=
                                  VpnConnectionState.connected &&
                              !widget.controller.isServerExpired(server.id) &&
                              !server.isInactive,
                          onTap: () => unawaited(
                            widget.controller.selectServer(server.id),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController url = TextEditingController();
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('افزودن اشتراک'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'نام اشتراک',
                        hintText: 'مثلاً اشتراک من',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: url,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'لینک اشتراک',
                        hintText: 'https://…',
                      ),
                    ),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('بیخیال'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await widget.controller.addSubscription(
                              name: name.text,
                              url: url.text,
                            );
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                          } on Object catch (exception) {
                            setDialogState(() {
                              saving = false;
                              error = '$exception';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('افزودن'),
                ),
              ],
            );
          },
        );
      },
    );
    name.dispose();
    url.dispose();
  }

  Future<void> _updateAll() async {
    setState(() => updating = true);
    try {
      await widget.controller.updateAllSubscriptions();
      if (mounted) _message('همهٔ اشتراک‌ها بروزرسانی شدند.');
    } on Object catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> _importFromClipboard() async {
    setState(() => updating = true);
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final int imported = await widget.controller.importServersFromClipboard(
        data?.text ?? '',
      );
      if (mounted) {
        _message('$imported سرور از کلیپ‌بورد اضافه شد.');
      }
    } on Object catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> _updateOne(String id) async {
    setState(() => updating = true);
    try {
      await widget.controller.updateSubscription(id);
      if (mounted) _message('اشتراک بروزرسانی شد.');
    } on Object catch (error) {
      if (mounted) _message('$error', error: true);
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> _confirmDelete(Subscription subscription) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('حذف اشتراک'),
        content: Text('اشتراک «${subscription.name}» حذف شود؟'),
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
    if (accepted ?? false) await widget.controller.removeSubscription(subscription.id);
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            size: 66,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          const Text(
            'هنوز اشتراکی اضافه نشده است',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('لینک اشتراک خود را اضافه کنید تا سرورها نمایش داده شوند.'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('افزودن اشتراک'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({
    required this.subscription,
    required this.onUpdate,
    required this.onDelete,
  });

  final Subscription subscription;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link_rounded),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  subscription.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subscription.isExpired
                      ? '${subscription.servers.length} سرور • اشتراک منقضی شده'
                      : subscription.isRemote
                          ? '${subscription.servers.length} سرور • بروزرسانی '
                              '${_date(subscription.updatedAt)}'
                          : '${subscription.servers.length} سرور محلی',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'بروزرسانی',
            onPressed: subscription.isRemote ? onUpdate : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'حذف',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.expired,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ServerProfile server;
  final bool expired;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Theme.of(context).colorScheme.secondary : null,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${server.protocolLabel} • ${server.host}:${server.port}',
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: expired
                      ? (Theme.of(context).brightness == Brightness.light
                          ? const Color(0xfffdeDEE)
                          : const Color(0xff3a2024))
                      : server.isInactive
                          ? (Theme.of(context).brightness == Brightness.light
                              ? const Color(0xfffdeDEE)
                              : const Color(0xff3a2024))
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expired
                      ? 'منقضی'
                      : server.isInactive
                          ? 'غیرفعال'
                          : server.latencyMs == null
                              ? '—'
                              : '${server.latencyMs}ms',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: expired || server.isInactive
                        ? Theme.of(context).colorScheme.error
                        : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}
