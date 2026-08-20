// lib/screens/announcements_screen.dart
//
// Admin feature: publish and view system-wide announcements. Everyone can
// read announcements (RLS: read = true), only admin can write.
import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/shared_widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _items = [];

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
    if (!SupabaseConfig.isConfigured) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = StateError('Supabase is not configured.');
        });
      }
      return;
    }
    try {
      _items = await DatabaseService.instance.fetchAnnouncements();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAnnouncement() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Message'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );

      if (result == true && titleController.text.trim().isNotEmpty) {
        try {
          await DatabaseService.instance.publishAnnouncement(
            title: titleController.text.trim(),
            body: bodyController.text.trim(),
          );
          _load();
        } catch (error) {
          if (!mounted) return;
          showMessage(context, errorMessage(error), error: true);
        }
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const BantayDengueAppBar(title: 'Announcements'),
      floatingActionButton: FloatingActionButton(
        onPressed: _createAnnouncement,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
      body: AsyncStateView(
        loading: _loading,
        error: _error,
        empty: _items.isEmpty,
        emptyTitle: 'No announcements yet',
        emptyMessage: 'Published announcements will appear here.',
        onRetry: _load,
        child: RefreshIndicator(onRefresh: _load, child: _buildList()),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.campaign,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['title'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if ((item['body'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  item['body'],
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
