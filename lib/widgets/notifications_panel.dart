// lib/widgets/notifications_panel.dart
//
// Notifications used to be their own routed page per role. Replaced with a
// bell + panel: a bottom sheet on phones, an anchored dropdown on tablet/web
// — so checking updates doesn't cost a full navigation round-trip, and
// whatever page you were on is still right there underneath when you close
// it.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import 'liquid_glass.dart';

Future<void> openNotificationsPanel(BuildContext context) {
  final compact = MediaQuery.sizeOf(context).width < 600;
  if (compact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: _NotificationsPanel(),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) => Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 68, right: 24),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
            child: LiquidGlass(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: const _NotificationsPanel(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotificationsPanel extends StatefulWidget {
  const _NotificationsPanel();

  @override
  State<_NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<_NotificationsPanel> {
  List<Map<String, dynamic>> _items = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await DatabaseService.instance.fetchNotifications();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    if (item['read'] == true) return;
    try {
      await DatabaseService.instance.markNotificationRead('${item['id']}');
      if (!mounted) return;
      setState(() => item['read'] = true);
    } catch (_) {
      // Best-effort — a failed read-receipt shouldn't block opening the item.
    }
  }

  Future<void> _readAll() async {
    try {
      await DatabaseService.instance.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final item in _items) {
          item['read'] = true;
        }
      });
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'outbreak_alert':
        return Icons.warning_amber_outlined;
      case 'appointment':
        return Icons.event_outlined;
      case 'report_status':
        return Icons.fact_check_outlined;
      case 'waste':
        return Icons.delete_sweep_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Where a tap should land, based on notification type and the signed-in
  /// user's role. Null means "no sensible destination" — the tap still
  /// marks it read and closes the panel.
  String? _destinationFor(String? type) {
    final role = authService.profile?.role ?? UserRole.civilian;
    switch (type) {
      case 'outbreak_alert':
      case 'advisory':
        switch (role) {
          case UserRole.civilian:
            return '/civilian/advisories';
          case UserRole.doctor:
            return '/doctor/advisories';
          case UserRole.wastePersonnel:
            return '/waste-management/advisories';
          case UserRole.admin:
            return '/admin/advisories';
        }
      case 'appointment':
        switch (role) {
          case UserRole.civilian:
            return '/civilian/appointments';
          case UserRole.doctor:
            return '/doctor/appointments';
          default:
            return null;
        }
      case 'report_status':
        switch (role) {
          case UserRole.civilian:
            return '/civilian/report/history';
          case UserRole.doctor:
            return '/doctor/verification';
          case UserRole.admin:
            return '/admin/verification';
          default:
            return null;
        }
      case 'waste':
        switch (role) {
          case UserRole.civilian:
            return '/civilian/waste';
          case UserRole.doctor:
            return '/doctor/waste';
          case UserRole.wastePersonnel:
            return '/waste-management';
          case UserRole.admin:
            return '/admin/waste';
        }
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => item['read'] != true).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      unread == 0
                          ? 'You\'re all caught up'
                          : '$unread unread',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: unread == 0 ? null : _readAll,
                child: const Text('Mark all read'),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: AsyncStateView(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            emptyTitle: 'You\'re all caught up',
            emptyMessage:
                'Report, appointment, waste, and advisory updates will appear here.',
            onRetry: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = _items[index];
                final unreadItem = item['read'] != true;
                return ListTile(
                  tileColor: unreadItem
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .25)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: CircleAvatar(
                    child: Icon(_icon(item['type'] as String?)),
                  ),
                  title: Text(
                    '${item['title']}',
                    style: TextStyle(
                      fontWeight: unreadItem ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(
                    '${item['body'] ?? ''}\n${formatDateTime(item['created_at'])}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: unreadItem
                      ? const Icon(Icons.circle, size: 10)
                      : null,
                  onTap: () {
                    _read(item);
                    final destination = _destinationFor(
                      item['type'] as String?,
                    );
                    Navigator.of(context).maybePop();
                    if (destination != null) context.go(destination);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
