import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
      setState(() => item['read'] = true);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _readAll() async {
    try {
      await DatabaseService.instance.markAllNotificationsRead();
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

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => item['read'] != true).length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Notifications',
              subtitle: '$unread unread update${unread == 1 ? '' : 's'}',
              action: TextButton.icon(
                onPressed: unread == 0 ? null : _readAll,
                icon: const Icon(Icons.done_all),
                label: const Text('Read all'),
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: _items.isEmpty,
                emptyTitle: 'You’re all caught up',
                emptyMessage:
                    'Report, appointment, waste, and advisory updates will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final unreadItem = item['read'] != true;
                      return Card(
                        color: unreadItem
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: .35)
                            : null,
                        child: ListTile(
                          onTap: () => _read(item),
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
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: unreadItem
                              ? const Icon(Icons.circle, size: 12)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
