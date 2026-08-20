import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/database_service.dart';
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
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.delete_sweep_outlined),
                          ),
                          title: Text(
                            '${item['location_text'] ?? 'Pickup request'}',
                          ),
                          subtitle: Text(
                            '${item['description'] ?? ''}\nPreferred ${formatDateTime(item['scheduled_at'])}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusChip('${item['status'] ?? 'pending'}'),
                              if (canCancel)
                                IconButton(
                                  onPressed: () => _cancel('${item['id']}'),
                                  icon: const Icon(Icons.cancel_outlined),
                                  tooltip: 'Cancel request',
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
