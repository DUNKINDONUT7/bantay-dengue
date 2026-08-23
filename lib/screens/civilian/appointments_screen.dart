import 'package:flutter/material.dart';

import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/appointment_qr_checkin.dart';
import '../../widgets/section_header.dart';

/// View-and-manage screen for consultation appointments. There is no
/// "book new" entry point here on purpose — every appointment now starts as
/// part of a dengue-case report (see report_form.dart's Consultation
/// Appointment section), so a resident always lands here with the schedule
/// already requested and only needs to track, adjust, or cancel it.
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

  Future<void> _cancel(String id) async {
    try {
      await DatabaseService.instance.updateAppointmentStatus(id, 'cancelled');
      if (mounted) showMessage(context, 'Appointment cancelled.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditAppointmentSheet(item: item),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Health appointments',
              subtitle:
                  'Requested when you file a case report. Track, adjust, or cancel here.',
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
                emptyTitle: 'No appointments yet',
                emptyMessage:
                    'Report a dengue case and choose a preferred '
                    'time — an appointment shows up here automatically.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _AppointmentCard(
                          item: _items[index],
                          onCancel: _cancel,
                          onEdit: _edit,
                        ),
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

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final ValueChanged<String> onCancel;
  final ValueChanged<Map<String, dynamic>> onEdit;

  const _AppointmentCard({
    required this.item,
    required this.onCancel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = '${item['status'] ?? 'pending'}';
    final pending = status == 'pending';
    final canCancel = pending || status == 'approved';
    final canCheckIn = status == 'approved';
    final color = statusColor(status, scheme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(item['scheduled_at']),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['reason'] ?? 'Health consultation'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pending)
                OutlinedButton.icon(
                  onPressed: () => onEdit(item),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                  label: const Text('Edit'),
                ),
              if (canCheckIn)
                OutlinedButton.icon(
                  onPressed: () => showAppointmentQrDialog(
                    context,
                    appointmentId: '${item['id']}',
                    reason: '${item['reason'] ?? 'Health consultation'}',
                    scheduledLabel: formatDateTime(item['scheduled_at']),
                  ),
                  icon: const Icon(Icons.qr_code_2, size: 17),
                  label: const Text('Check-in code'),
                ),
              if (canCancel)
                TextButton.icon(
                  onPressed: () => onCancel('${item['id']}'),
                  icon: const Icon(Icons.cancel_outlined, size: 17),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// The appointment's `reason` starts as an exact copy of the report's
// composed description (see report_form.dart's `_composeDescription`):
// an optional "Reported symptoms: ..." line, an optional
// "Reporter-assessed severity: ..." line, then a blank line and the
// resident's freeform note. Only dengue-case reports ever create an
// appointment, so these are the only two structured prefixes that can
// appear — breeding-site reports have no "Visible containers:" equivalent
// here. Splitting on load lets the edit sheet show that context as a
// read-only summary instead of dumping the raw joined string into one
// editable box, while still saving back in the exact same plain-text shape
// every other reader of `reason` (profile_screen.dart, staff_appointments_
// screen.dart) already expects.
const _reasonHeaderPrefixes = [
  'Reported symptoms:',
  'Reporter-assessed severity:',
];

class _ParsedReason {
  final List<String> structured;
  final String freeform;
  const _ParsedReason(this.structured, this.freeform);
}

_ParsedReason _parseReason(String raw) {
  final lines = raw.split('\n');
  final structured = <String>[];
  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (_reasonHeaderPrefixes.any((prefix) => trimmed.startsWith(prefix))) {
      structured.add(trimmed);
      i++;
    } else {
      break;
    }
  }
  // The composer leaves one blank line between the header and the freeform
  // note only when both are present — skip it if it's there.
  if (i < lines.length && lines[i].trim().isEmpty) i++;
  final freeform = lines.sublist(i).join('\n').trim();
  return _ParsedReason(structured, freeform);
}

String _combineReason(List<String> structured, String freeform) {
  final buffer = StringBuffer();
  if (structured.isNotEmpty) buffer.writeln(structured.join('\n'));
  final trimmedFreeform = freeform.trim();
  if (trimmedFreeform.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.write(trimmedFreeform);
  }
  return buffer.toString().trim();
}

/// Reschedule/edit sheet for a still-pending appointment. Kept distinct from
/// staff status changes (updateAppointmentStatus) — this only ever touches
/// the fields the resident themself owns: when, and why.
class _EditAppointmentSheet extends StatefulWidget {
  final Map<String, dynamic> item;

  const _EditAppointmentSheet({required this.item});

  @override
  State<_EditAppointmentSheet> createState() => _EditAppointmentSheetState();
}

class _EditAppointmentSheetState extends State<_EditAppointmentSheet> {
  late final List<String> _structuredContext;
  late final TextEditingController _reason;
  late DateTime _scheduled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final parsed = _parseReason('${widget.item['reason'] ?? ''}');
    _structuredContext = parsed.structured;
    _reason = TextEditingController(text: parsed.freeform);
    _scheduled =
        DateTime.tryParse('${widget.item['scheduled_at']}') ??
        DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled),
    );
    if (time == null || !mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (combined.isBefore(DateTime.now())) {
      showMessage(context, "Choose a time that hasn't already passed.", error: true);
      return;
    }
    setState(() => _scheduled = combined);
  }

  Future<void> _save() async {
    // The structured symptoms/severity lines (if any) are carried over
    // unedited, so they alone are enough context to save on — only demand
    // freeform text when there's no structured context backing this
    // appointment at all (mirrors report_form.dart's own validator: tags
    // selected OR enough freeform text, never both required).
    if (_structuredContext.isEmpty && _reason.text.trim().length < 5) {
      showMessage(context, 'Briefly describe the reason for your visit.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.updateAppointmentDetails(
        id: '${widget.item['id']}',
        scheduledAt: _scheduled,
        reason: _combineReason(_structuredContext, _reason.text),
      );
      if (!mounted) return;
      showMessage(context, 'Appointment updated.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit appointment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Only pending appointments can be changed here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_structuredContext.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'From your report',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _structuredContext)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: line == _structuredContext.last ? 0 : 4,
                      ),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "To change your symptoms or severity, file a new report — this "
              "just adjusts when you're seen and any extra notes.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: _structuredContext.isEmpty
                  ? 'Reason for consultation'
                  : 'Additional notes (optional)',
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.notes_outlined),
              hintText: _structuredContext.isEmpty
                  ? null
                  : 'Anything else the health worker should know',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickTime,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(formatDateTime(_scheduled)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
