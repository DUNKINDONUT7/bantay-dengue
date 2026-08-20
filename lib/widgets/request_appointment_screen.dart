import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../utils/submit_throttle.dart';
import '../utils/ui_helpers.dart';
import 'section_header.dart';

/// Dedicated appointment-request screen — same visual language as
/// request_waste_screen.dart and report_form.dart, instead of a cramped
/// AlertDialog with a date/time picker crammed inside it.
class RequestAppointmentScreen extends StatefulWidget {
  const RequestAppointmentScreen({super.key});

  @override
  State<RequestAppointmentScreen> createState() =>
      _RequestAppointmentScreenState();
}

class _RequestAppointmentScreenState extends State<RequestAppointmentScreen>
    with SubmitThrottle {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime? _selected;
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selected ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selected ?? DateTime.now().add(const Duration(hours: 1)),
      ),
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
      showMessage(
        context,
        'Choose a time that hasn\'t already passed today.',
        error: true,
      );
      return;
    }
    setState(() => _selected = combined);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected == null) {
      showMessage(context, 'Choose a preferred date and time.', error: true);
      return;
    }
    final wait = checkSubmitCooldown();
    if (wait != null) {
      showMessage(
        context,
        'Please wait ${wait}s before submitting again.',
        error: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await DatabaseService.instance.createAppointment(
        scheduledAt: _selected!,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'Appointment request sent.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SectionHeader(
              title: 'Request an appointment',
              subtitle:
                  'Book a consultation slot at the Barangay Health Center.',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _reason,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              labelText: 'Reason for consultation',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_outlined),
                              hintText:
                                  'Symptoms, concerns, or what you\'d like checked',
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 5
                                ? 'Briefly describe the reason for your visit.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Preferred date & time',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickDateTime,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              _selected == null
                                  ? 'Choose date & time'
                                  : formatDateTime(_selected),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(_submitting ? 'Sending…' : 'Request appointment'),
                          ),
                        ],
                      ),
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
