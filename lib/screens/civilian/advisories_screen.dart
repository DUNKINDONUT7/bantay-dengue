import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class AdvisoriesScreen extends StatefulWidget {
  const AdvisoriesScreen({super.key});

  @override
  State<AdvisoriesScreen> createState() => _AdvisoriesScreenState();
}

class _AdvisoriesScreenState extends State<AdvisoriesScreen> {
  List<Map<String, dynamic>> _items = [];
  Object? _error;
  bool _loading = true;
  bool get _canPublish =>
      authService.currentUser?.role == UserRole.doctor ||
      authService.currentUser?.role == UserRole.admin;

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
      _items = await DatabaseService.instance.fetchAdvisories();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish health advisory'),
        content: SizedBox(
          width: min(500, MediaQuery.sizeOf(context).width - 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: body,
                maxLength: 2000,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(
                  labelText: 'Advisory',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        title.text.trim().isNotEmpty &&
        body.text.trim().length >= 10) {
      try {
        await DatabaseService.instance.publishAdvisory(
          title: title.text.trim(),
          body: body.text.trim(),
        );
        if (mounted) showMessage(context, 'Advisory published.');
        await _load();
      } catch (error) {
        if (mounted) showMessage(context, errorMessage(error), error: true);
      }
    }
    title.dispose();
    body.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              onPressed: _publish,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Publish'),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Health advisories',
              subtitle:
                  'Official updates from authorized local health personnel.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: _items.isEmpty,
                emptyTitle: 'No advisories published',
                emptyMessage:
                    'New Barangay Health Center advisories will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item['title']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('${item['body']}'),
                              const SizedBox(height: 12),
                              Text(
                                formatDateTime(item['created_at']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
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
