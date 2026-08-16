import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
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
      _items = await DatabaseService.instance.fetchAppointments(ownOnly: true);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    final reason = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(days: 1));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request an appointment'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: reason,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Reason for consultation',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(formatDateTime(selected)),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selected,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 120)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selected),
                    );
                    if (time == null) return;
                    setDialogState(
                      () => selected = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  },
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
              child: const Text('Request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    if (reason.text.trim().length < 5) {
      if (mounted) {
        showMessage(
          context,
          'Please provide a short consultation reason.',
          error: true,
        );
      }
      reason.dispose();
      return;
    }
    try {
      await DatabaseService.instance.createAppointment(
        scheduledAt: selected,
        reason: reason.text.trim(),
      );
      if (mounted) showMessage(context, 'Appointment request sent.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      reason.dispose();
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await DatabaseService.instance.updateAppointmentStatus(id, 'cancelled');
      if (mounted) showMessage(context, 'Appointment cancelled.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        icon: const Icon(Icons.add),
        label: const Text('Book'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Health appointments',
              subtitle:
                  'Request and track Barangay Health Center consultations.',
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
                emptyTitle: 'No appointments',
                emptyMessage: 'Tap Book to request a consultation schedule.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final canCancel = [
                        'pending',
                        'approved',
                      ].contains(item['status']);
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.event_outlined),
                          ),
                          title: Text(
                            '${item['reason'] ?? 'Health consultation'}',
                          ),
                          subtitle: Text(formatDateTime(item['scheduled_at'])),
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
