import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/appointment_qr_checkin.dart';
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
    final booked = await context.push<bool>('/civilian/appointments/new');
    if (booked == true) _load();
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
                tooltip: 'Refresh',
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
                      final status = '${item['status'] ?? 'pending'}';
                      final canCancel = [
                        'pending',
                        'approved',
                      ].contains(status);
                      final canCheckIn = status == 'approved';
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
                              StatusChip(status),
                              if (canCheckIn)
                                IconButton(
                                  onPressed: () => showAppointmentQrDialog(
                                    context,
                                    appointmentId: '${item['id']}',
                                    reason:
                                        '${item['reason'] ?? 'Health consultation'}',
                                    scheduledLabel: formatDateTime(
                                      item['scheduled_at'],
                                    ),
                                  ),
                                  icon: const Icon(Icons.qr_code_2),
                                  tooltip: 'Show check-in code',
                                ),
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
