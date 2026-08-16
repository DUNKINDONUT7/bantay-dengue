import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../services/image_picker_stub.dart';
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
    final description = TextEditingController();
    final location = TextEditingController();
    DateTime preferredDate = DateTime.now().add(const Duration(days: 1));
    Uint8List? photo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request waste collection'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Pickup location or landmark',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Waste details',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await pickEvidenceImage(context);
                      if (result != null) setDialogState(() => photo = result);
                    },
                    icon: Icon(
                      photo == null
                          ? Icons.add_a_photo_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(
                      photo == null ? 'Add private evidence' : 'Photo ready',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: preferredDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (date != null) {
                        setDialogState(() => preferredDate = date);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      'Preferred: ${formatDateTime(preferredDate).split(' ·').first}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      description.dispose();
      location.dispose();
      return;
    }
    if (location.text.trim().length < 3 || description.text.trim().length < 5) {
      if (mounted) {
        showMessage(
          context,
          'Enter a pickup location and waste details.',
          error: true,
        );
      }
      description.dispose();
      location.dispose();
      return;
    }
    try {
      await DatabaseService.instance.createWasteRequest(
        description: description.text.trim(),
        locationText: location.text.trim(),
        preferredDate: preferredDate,
        photoBytes: photo,
      );
      if (mounted) showMessage(context, 'Waste collection request submitted.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      description.dispose();
      location.dispose();
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
                          trailing: StatusChip(
                            '${item['status'] ?? 'pending'}',
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
