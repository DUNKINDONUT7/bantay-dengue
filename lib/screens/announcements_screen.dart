// lib/screens/announcements_screen.dart
//
// Admin feature: publish and view system-wide announcements. Everyone can
// read announcements (RLS: read = true), only admin can write.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

enum _LoadState { loading, loaded, error }

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  _LoadState _state = _LoadState.loading;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() => _state = _LoadState.error);
      return;
    }
    setState(() => _state = _LoadState.loading);
    try {
      final rows = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      _items = List<Map<String, dynamic>>.from(rows as List);
      setState(() => _state = _LoadState.loaded);
    } catch (_) {
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _createAnnouncement() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'New announcement',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        await Supabase.instance.client.from('announcements').insert({
          'author_id': userId,
          'title': titleController.text.trim(),
          'body': bodyController.text.trim(),
        });
        _load();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to publish. Please try again.')),
        );
      }
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
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case _LoadState.error:
        return ListView(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to load announcements.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                onPressed: _load,
                child: const Text('Try Again'),
              ),
            ),
          ],
        );
      case _LoadState.loaded:
        if (_items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              Icon(
                Icons.campaign_outlined,
                color: AppColors.textMuted,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'No announcements yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
        }
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
}
