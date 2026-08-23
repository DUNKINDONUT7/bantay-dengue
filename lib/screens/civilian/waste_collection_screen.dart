import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class WasteCollectionScreen extends StatefulWidget {
  const WasteCollectionScreen({super.key});

  @override
  State<WasteCollectionScreen> createState() => _WasteCollectionScreenState();
}

class _WasteCollectionScreenState extends State<WasteCollectionScreen> {
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
      _items = await DatabaseService.instance.fetchWasteRequests(ownOnly: true);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request() async {
    final submitted = await context.push<bool>('/civilian/waste/new');
    if (submitted == true) _load();
  }

  Future<void> _cancel(String id) async {
    try {
      await DatabaseService.instance.updateWasteStatus(id, 'cancelled');
      if (mounted) showMessage(context, 'Request cancelled.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  /// [pathKey] picks which photo to show: the resident's own submitted
  /// evidence (`photo_url`) or the waste personnel's proof of pickup
  /// (`completion_photo_url`) — both already round-trip through
  /// fetchWasteRequests, just never rendered back to the resident before.
  Future<void> _viewPhoto(
    Map<String, dynamic> item, {
    required String pathKey,
    required String title,
    required String emptyMessage,
  }) async {
    final path = item[pathKey] as String?;
    final signedUrl = await DatabaseService.instance.createEvidenceUrl(
      bucket: 'waste-evidence',
      path: path,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: SizedBox(
          width: min(520, MediaQuery.sizeOf(context).width - 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: signedUrl == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          path == null
                              ? emptyMessage
                              : 'The private preview could not be created. Try again shortly.',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          color: AppColors.surfaceElevated,
                          constraints: const BoxConstraints(
                            maxHeight: 420,
                            minHeight: 160,
                          ),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Image.network(
                              signedUrl,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: SizedBox.square(
                                      dimension: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => const SizedBox(
                                height: 160,
                                child: Center(
                                  child: Text('Photo could not be displayed.'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _request,
        icon: const Icon(Icons.add),
        label: const Text('Request pickup'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Waste collection',
              subtitle:
                  'Request collection of waste that may hold mosquito-breeding water.',
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
                emptyTitle: 'No collection requests',
                emptyMessage:
                    'Tap Request pickup when unmanaged waste needs collection.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final canCancel = item['status'] == 'pending';
                      final collected = item['status'] == 'collected';
                      final assigned = item['handled_by'] != null;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                isThreeLine: true,
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.surfaceElevated,
                                  child: Icon(
                                    Icons.delete_sweep_outlined,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                title: Text(
                                  '${item['location_text'] ?? 'Pickup request'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item['description'] ?? ''}\nPreferred ${formatDateTime(item['scheduled_at'])}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: StatusChip(
                                  '${item['status'] ?? 'pending'}',
                                ),
                              ),
                              if (assigned)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.assignment_ind_outlined,
                                        size: 14,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Waste personnel assigned',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _viewPhoto(
                                        item,
                                        pathKey: 'photo_url',
                                        title: 'Your submitted evidence',
                                        emptyMessage:
                                            'No photo evidence was attached to this request.',
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        item['photo_url'] == null
                                            ? 'No evidence'
                                            : 'View evidence',
                                      ),
                                    ),
                                    if (collected)
                                      TextButton.icon(
                                        onPressed: () => _viewPhoto(
                                          item,
                                          pathKey: 'completion_photo_url',
                                          title: 'Proof of collection',
                                          emptyMessage:
                                              'Waste personnel did not attach a completion photo.',
                                        ),
                                        icon: const Icon(
                                          Icons.task_alt_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          item['completion_photo_url'] == null
                                              ? 'No completion photo'
                                              : 'View proof of collection',
                                        ),
                                      ),
                                    if (canCancel)
                                      TextButton.icon(
                                        onPressed: () =>
                                            _cancel('${item['id']}'),
                                        icon: Icon(
                                          Icons.cancel_outlined,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                        label: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
