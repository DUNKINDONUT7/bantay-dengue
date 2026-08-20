import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/appointment_qr_checkin.dart';
import '../widgets/section_header.dart';

class StaffAppointmentsScreen extends StatefulWidget {
  const StaffAppointmentsScreen({super.key});

  @override
  State<StaffAppointmentsScreen> createState() =>
      _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen> {
  List<Map<String, dynamic>> _items = [];
  final Set<String> _busyIds = {};
  Object? _error;
  bool _loading = true;
  String _filter = 'all';

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
      _items = await DatabaseService.instance.fetchAppointments();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String id, String status) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await DatabaseService.instance.updateAppointmentStatus(id, status);
      if (mounted) {
        showMessage(
          context,
          'Appointment marked ${humanize(status).toLowerCase()}.',
        );
      }
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _scanCheckIn() async {
    final scannedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AppointmentScanScreen()),
    );
    if (scannedId == null || !mounted) return;

    final match = _items.where((item) => '${item['id']}' == scannedId);
    if (match.isEmpty) {
      showMessage(
        context,
        "That code doesn't match any appointment in this list. Refresh and try again.",
        error: true,
      );
      return;
    }
    final appointment = match.first;
    final status = '${appointment['status']}';
    if (status != 'approved') {
      showMessage(
        context,
        'This appointment is $status, not approved — nothing to check in.',
        error: true,
      );
      return;
    }

    final patient = appointment['profiles'] as Map<String, dynamic>?;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm check-in'),
        content: Text(
          '${patient?['full_name'] ?? 'This resident'} — '
          '${formatDateTime(appointment['scheduled_at'])}\n\n'
          'Mark this appointment as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Check in'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _update(scannedId, 'completed');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _items
        : _items.where((item) => item['status'] == _filter).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Appointment management',
              subtitle:
                  'Review resident consultation requests and maintain their status.',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _scanCheckIn,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scan check-in',
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final value in const [
                    'all',
                    'pending',
                    'approved',
                    'completed',
                    'rejected',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        selected: _filter == value,
                        label: Text(humanize(value)),
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: filtered.isEmpty,
                emptyTitle: 'No matching appointments',
                emptyMessage: 'Resident requests will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final patient = item['profiles'] as Map<String, dynamic>?;
                      final status = '${item['status']}';
                      final id = '${item['id']}';
                      final busy = _busyIds.contains(id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.person_outline),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${patient?['full_name'] ?? 'Resident'}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          formatDateTime(item['scheduled_at']),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusChip(status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('${item['reason'] ?? 'No reason supplied'}'),
                              if (status == 'pending') ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => _update(id, 'rejected'),
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => _update(id, 'approved'),
                                      child: busy
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.onPrimary,
                                              ),
                                            )
                                          : const Text('Approve'),
                                    ),
                                  ],
                                ),
                              ] else if (status == 'approved') ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => _update(id, 'completed'),
                                  icon: busy
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onPrimary,
                                          ),
                                        )
                                      : const Icon(Icons.done),
                                  label: const Text('Mark completed'),
                                ),
                              ],
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
