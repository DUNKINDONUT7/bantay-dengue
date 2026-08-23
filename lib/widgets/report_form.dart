import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/image_picker_stub.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/submit_throttle.dart';
import '../utils/ui_helpers.dart';
import 'location_picker_field.dart';
import 'report_form_parts.dart';
import 'section_header.dart';

class ReportForm extends StatefulWidget {
  final String reportType;
  final String title;
  final String description;
  final IconData icon;

  const ReportForm({
    super.key,
    required this.reportType,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> with SubmitThrottle {
  // Marilao, Bulacan — same fallback used by hotspot_map_screen.dart, for
  // the breeding-site weather nudge before any pin is picked.
  static const _fallbackLat = 14.7575;
  static const _fallbackLng = 120.9480;

  static const _symptomOptions = [
    'Fever',
    'Headache',
    'Rash',
    'Joint or muscle pain',
    'Nausea or vomiting',
    'Pain behind the eyes',
    'Bleeding gums or nose',
    'Abdominal pain',
  ];

  static const _containerOptions = [
    'Water drum',
    'Old tire',
    'Flower pot',
    'Gutter',
    'Pail or basin',
    'Discarded container',
    'Construction debris',
  ];

  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Uint8List? _photo;
  bool _submitting = false;
  bool? _nearbyDuplicate;
  final Set<String> _selectedTags = {};
  CaseSeverity? _severity;
  WeatherRisk? _weather;
  DateTime? _appointmentTime;

  bool get _isDengueCase => widget.reportType == 'dengue_case';

  List<String> get _tagOptions =>
      _isDengueCase ? _symptomOptions : _containerOptions;

  @override
  void initState() {
    super.initState();
    // Breeding-site reports get a live weather-risk nudge; case reports
    // don't need it. Fetched once against the barangay fallback point —
    // this is a regional forecast, not tied to the exact pin the resident
    // hasn't chosen yet.
    if (!_isDengueCase) {
      unawaited(_loadWeather());
    }
  }

  Future<void> _loadWeather() async {
    final risk = await WeatherService.instance.fetchRisk(
      latitude: _fallbackLat,
      longitude: _fallbackLng,
    );
    if (mounted) setState(() => _weather = risk);
  }

  String get _detailsLabel =>
      _isDengueCase ? 'Case details' : 'Breeding site details';

  String get _detailsHint => _isDengueCase
      ? 'Symptoms noticed, when they started, age range, and urgent concerns'
      : 'Standing water source, container type, size, and how long it has been there';

  String get _destinationLabel =>
      _isDengueCase ? 'Health personnel queue' : 'Waste personnel queue';

  String get _submitLabel =>
      _isDengueCase ? 'Submit case report' : 'Submit breeding site';

  String get _submittedMessage => _isDengueCase
      ? 'Case report sent to health personnel for verification.'
      : 'Breeding site sent to waste personnel for action.';

  IconData get _destinationIcon =>
      _isDengueCase ? Icons.health_and_safety_outlined : Icons.delete_sweep;

  Color _accentColor(ColorScheme scheme) =>
      _isDengueCase ? scheme.error : AppColors.warning;

  @override
  void dispose() {
    _location.dispose();
    _details.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  /// Fires whenever the location picker resolves a point — from a map tap,
  /// an address search, or the GPS shortcut. Fills the human-readable
  /// location field only if the resident hasn't already typed one, then
  /// checks whether someone already flagged this spot recently, so we can
  /// nudge instead of silently letting duplicate reports pile up.
  void _onLocationPicked(LocationPickResult result) {
    setState(() {
      _latitude.text = result.latitude.toStringAsFixed(6);
      _longitude.text = result.longitude.toStringAsFixed(6);
      if (result.address != null && _location.text.trim().isEmpty) {
        _location.text = result.address!;
      }
    });
    unawaited(_checkNearbyDuplicate(result.latitude, result.longitude));
  }

  void _onLocationCleared() {
    setState(() {
      _latitude.clear();
      _longitude.clear();
      _nearbyDuplicate = null;
    });
  }

  Future<void> _checkNearbyDuplicate(double lat, double lng) async {
    final duplicate = await DatabaseService.instance.nearbyReportExists(
      reportType: widget.reportType,
      latitude: lat,
      longitude: lng,
    );
    if (mounted) setState(() => _nearbyDuplicate = duplicate);
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    });
  }

  /// Same date/time flow as request_appointment_screen.dart, folded in here
  /// so booking a consultation is one more toggle on the case-report form
  /// instead of a second trip through the standalone Appointments screen —
  /// both ultimately land in the same health worker queue anyway.
  Future<void> _pickAppointmentTime() async {
    // Severe self-assessed cases default to the soonest possible slot
    // instead of "tomorrow" — a small nudge, not a substitute for the
    // emergency-care banner shown above when severity is Severe.
    final suggestedGap = _severity == CaseSeverity.severe
        ? const Duration(hours: 2)
        : const Duration(days: 1);
    final date = await showDatePicker(
      context: context,
      initialDate: _appointmentTime ?? DateTime.now().add(suggestedGap),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _appointmentTime ?? DateTime.now().add(const Duration(hours: 1)),
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
        "Choose a time that hasn't already passed today.",
        error: true,
      );
      return;
    }
    setState(() => _appointmentTime = combined);
  }

  /// The reports table has no symptoms/severity/container columns (see
  /// supabase/schema.sql) and adding one needs a hand-applied migration the
  /// grading project may not have run yet — so the quick-tag and severity
  /// picks are folded into the one `description` column as a labelled
  /// header instead of the freeform note, rather than sent as separate
  /// fields that would silently fail to persist.
  String _composeDescription() {
    final buffer = StringBuffer();
    if (_selectedTags.isNotEmpty) {
      final label = _isDengueCase ? 'Reported symptoms' : 'Visible containers';
      buffer.writeln('$label: ${_selectedTags.join(', ')}');
    }
    if (_isDengueCase && _severity != null) {
      buffer.writeln('Reporter-assessed severity: ${_severity!.label}');
    }
    final freeform = _details.text.trim();
    if (freeform.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(freeform);
    }
    return buffer.toString().trim();
  }

  // Dengue-case reports often describe symptoms that never produce anything
  // photographable (fever, pain behind the eyes, nausea) — forcing a photo
  // there meant genuine self-reporters either stalled or uploaded an
  // unrelated image just to get past the check. Breeding sites are visual
  // by nature, so the photo stays required there.
  static const _dengueCaseDailyLimit = 3;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Photo evidence isn't a FormField, so the Form's own validate() can't
    // catch a missing one — checked explicitly here instead. For breeding
    // sites this still raises the cost of a spam/troll submission (typing
    // text is free; producing a relevant photo isn't). Dengue-case reports
    // rely on the daily cap below instead, since a photo isn't always
    // possible for a genuine self-reporter.
    if (!_isDengueCase && _photo == null) {
      showMessage(
        context,
        'Add a photo before submitting — this helps keep reports genuine for the staff reviewing them.',
        error: true,
      );
      return;
    }
    // A dengue-case report IS the appointment request — filing one always
    // requests a consultation slot, not an optional add-on beside it.
    if (_isDengueCase && _appointmentTime == null) {
      showMessage(
        context,
        'Choose a preferred date and time for your consultation.',
        error: true,
      );
      return;
    }
    // Same client-side cooldown caveat as signup_screen.dart's _submit:
    // deters accidental double-submits, not a real abuse control.
    final wait = checkSubmitCooldown();
    if (wait != null) {
      showMessage(
        context,
        'Please wait ${wait}s before submitting again.',
        error: true,
      );
      return;
    }
    // Without a mandatory photo, an account that keeps filing case reports
    // is the next-cheapest abuse signal to catch — cap how many a resident
    // can file in a rolling day. Real deteriorating cases are told to go
    // straight to the health center rather than keep re-filing.
    if (_isDengueCase) {
      final recentCount = await DatabaseService.instance.recentOwnReportCount(
        reportType: widget.reportType,
        window: const Duration(hours: 24),
      );
      if (recentCount >= _dengueCaseDailyLimit) {
        if (!mounted) return;
        showMessage(
          context,
          "You've already filed $recentCount case reports in the last 24 "
          'hours. If your symptoms are getting worse, please go straight '
          'to the Barangay Health Center instead of submitting again.',
          error: true,
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      await DatabaseService.instance.submitReport(
        type: widget.reportType,
        description: _composeDescription(),
        locationText: _location.text.trim(),
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        photoBytes: _photo,
      );
      var message = _submittedMessage;
      // The appointment is a second, independent insert (reports and
      // appointments are separate tables — see supabase/schema.sql, no FK
      // between them). If it fails, the report the resident actually came
      // here to file is already safely submitted, so that isn't rolled
      // back — they're just told to retry from the Appointments tab
      // instead of losing the whole submission.
      if (_isDengueCase && _appointmentTime != null) {
        try {
          await DatabaseService.instance.createAppointment(
            scheduledAt: _appointmentTime!,
            reason: _composeDescription(),
          );
          message = '$message An appointment was requested too.';
        } catch (_) {
          message =
              '$message The appointment could not be requested — try '
              'again from the Appointments tab.';
        }
      }
      if (!mounted) return;
      showMessage(context, message);
      _formKey.currentState!.reset();
      _location.clear();
      _details.clear();
      _latitude.clear();
      _longitude.clear();
      setState(() {
        _photo = null;
        _nearbyDuplicate = null;
        _selectedTags.clear();
        _severity = null;
        _appointmentTime = null;
      });
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;
    // Below this, two side-by-side ~380px columns would be cramped and
    // start wrapping awkwardly — one wide column reads better instead.
    final wide = width >= 980;
    // A flat 760px cap left most of a desktop window empty next to the
    // 240px sidebar. Wide screens get real estate to actually use (two
    // columns instead of one narrow strip); narrow/compact keep the old cap.
    final maxWidth = wide ? 1180.0 : 760.0;
    final accent = _accentColor(scheme);

    final detailsColumn = [
      Align(
        alignment: Alignment.centerLeft,
        child: _RoutingBanner(
          icon: _destinationIcon,
          label: _destinationLabel,
          message: _isDengueCase
              ? 'This goes directly to the health worker verification screen.'
              : 'This goes directly to waste personnel for inspection and cleanup scheduling.',
          accent: accent,
        ),
      ),
      const SizedBox(height: 14),
      _FormIntro(
        icon: widget.icon,
        accent: accent,
        title: _isDengueCase
            ? 'Tell us what happened'
            : 'Show the source of stagnant water',
        message: _isDengueCase
            ? 'Give enough context for health staff to assess and verify.'
            : 'Describe what waste personnel should inspect or remove.',
      ),
      if (!_isDengueCase && _weather != null) ...[
        const SizedBox(height: 12),
        WeatherNudge(risk: _weather!),
      ],
      const SizedBox(height: 20),
      TextFormField(
        controller: _details,
        minLines: 4,
        maxLines: 8,
        maxLength: 1000,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: _detailsLabel,
          alignLabelWithHint: true,
          prefixIcon: const Icon(Icons.notes_outlined),
          hintText: _detailsHint,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.length >= 10) return null;
          if (_selectedTags.isNotEmpty && text.isEmpty) {
            return null;
          }
          return 'Provide at least 10 characters, or pick an option above.';
        },
      ),
      if (_isDengueCase)
        AnimatedBuilder(
          animation: _details,
          builder: (context, _) {
            final flagged = AiService.instance.hasDangerSigns(
              _details.text.toLowerCase(),
            );
            if (!flagged) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.emergency_outlined,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "What you typed may describe a warning "
                        "sign. Don't wait on this report — go to "
                        'the nearest health centre or emergency '
                        "department now, or call 911. Consider "
                        'marking severity as Severe below so '
                        'staff see this first.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 14),
      QuickTagChips(
        title: _isDengueCase ? 'Symptoms noticed' : 'What kind of container?',
        hint: _isDengueCase
            ? 'Tap what applies — this fills in details for you.'
            : 'Tap what applies — helps waste personnel prep the right tools.',
        options: _tagOptions,
        selected: _selectedTags,
        accent: accent,
        enabled: !_submitting,
        onToggle: _toggleTag,
      ),
      if (_isDengueCase) ...[
        const SizedBox(height: 18),
        SeveritySelector(
          value: _severity,
          enabled: !_submitting,
          onChanged: (value) => setState(() => _severity = value),
        ),
      ],
    ];

    final logisticsColumn = [
      _FormSection(
        title: 'Location',
        message:
            'Type a landmark, then set an exact pin so the assigned team can find the spot without back-and-forth.',
        icon: Icons.location_on_outlined,
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _location,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Landmark or description',
                hintText: 'House number, street, sitio, or nearby landmark',
              ),
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Enter a recognizable location.'
                  : null,
            ),
            const SizedBox(height: 12),
            LocationPickerField(
              latitude: double.tryParse(_latitude.text.trim()),
              longitude: double.tryParse(_longitude.text.trim()),
              enabled: !_submitting,
              onChanged: _onLocationPicked,
              onCleared: _onLocationCleared,
            ),
            if (_nearbyDuplicate == true) ...[
              const SizedBox(height: 8),
              const _StatusPanel(
                icon: Icons.info_outline,
                title: 'Nearby report already exists',
                message:
                    'Another report near this spot was filed in the last two '
                    'weeks. You can still submit — staff will check for duplicates.',
              ),
            ],
          ],
        ),
      ),
      if (_isDengueCase) ...[
        const SizedBox(height: 16),
        _FormSection(
          title: 'Consultation appointment',
          message:
              'This report requests a health worker to see you in '
              'person — pick when. Your case details above are sent '
              'as the reason, so this appointment starts in the same '
              'queue as the report, not a separate one.',
          icon: Icons.calendar_month_outlined,
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickAppointmentTime,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _appointmentTime == null
                      ? 'Choose date & time'
                      : formatDateTime(_appointmentTime),
                ),
              ),
              if (_appointmentTime != null) ...[
                const SizedBox(height: 8),
                _StatusPanel(
                  icon: Icons.event_available_outlined,
                  title: 'Consultation requested',
                  message: formatDateTime(_appointmentTime),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      _FormSection(
        title: _isDengueCase
            ? 'Photo evidence (optional)'
            : 'Photo evidence (required)',
        message: _isDengueCase
            ? 'Private and visible only to you and authorized personnel. '
                  "Not every symptom can be photographed, so it's optional — "
                  'but a photo of a rash, swelling, or similar can help '
                  'staff assess your case faster.'
            : 'Private and visible only to you and authorized personnel. '
                  'Required so staff can trust the reports in their queue.',
        icon: Icons.photo_camera_outlined,
        accent: accent,
        child: _photo == null
            ? OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () async {
                        final bytes = await pickEvidenceImage(context);
                        if (bytes != null && mounted) {
                          setState(() => _photo = bytes);
                        }
                      },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _isDengueCase ? 'Add a photo (optional)' : 'Add required photo',
                ),
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.memory(
                      _photo!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evidence attached',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uploaded securely with your report.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            final bytes = await pickEvidenceImage(context);
                            if (bytes != null && mounted) {
                              setState(() => _photo = bytes);
                            }
                          },
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Replace photo',
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _photo = null),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove photo',
                  ),
                ],
              ),
      ),
    ];

    return Scaffold(
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SectionHeader(
                title: widget.title,
                subtitle: widget.description,
                onBack: () => context.go('/civilian/report'),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Card(
                    margin: EdgeInsets.fromLTRB(
                      compact ? 12 : 16,
                      12,
                      compact ? 12 : 16,
                      16,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 18 : 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Only _location and _details drive step 1's
                            // "complete" state, so only this small subtree
                            // rebuilds on keystroke — not the whole form.
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _location,
                                _details,
                              ]),
                              builder: (context, _) => ReportStepIndicator(
                                accent: accent,
                                steps: [
                                  ReportStep(
                                    label: 'Details',
                                    icon: widget.icon,
                                    complete:
                                        _location.text.trim().length >= 3 &&
                                        (_details.text.trim().length >= 10 ||
                                            _selectedTags.isNotEmpty),
                                  ),
                                  ReportStep(
                                    label: 'Exact pin',
                                    icon: Icons.pin_drop_outlined,
                                    complete:
                                        _latitude.text.trim().isNotEmpty &&
                                        _longitude.text.trim().isNotEmpty,
                                    optional: true,
                                  ),
                                  ReportStep(
                                    label: 'Evidence',
                                    icon: Icons.photo_camera_outlined,
                                    complete: _photo != null,
                                    optional: _isDengueCase,
                                  ),
                                  if (_isDengueCase)
                                    ReportStep(
                                      label: 'Appointment',
                                      icon: Icons.calendar_month_outlined,
                                      complete: _appointmentTime != null,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Desktop gets the two form halves side by side
                            // instead of one narrow column stretched down a
                            // mostly-empty page; phone/tablet keep reading
                            // top-to-bottom.
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: detailsColumn,
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: logisticsColumn,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...detailsColumn,
                                  const SizedBox(height: 16),
                                  ...logisticsColumn,
                                ],
                              ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(
                                _submitting ? 'Submitting...' : _submitLabel,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isDengueCase
                                  ? 'Health personnel will review this before it affects official records.'
                                  : 'Waste personnel will handle this as an operational request.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
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
      ),
    );
  }

}

class _FormIntro extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;

  const _FormIntro({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onSurface, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: scheme.onSurface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RoutingBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final String message;
  final Color accent;

  const _RoutingBanner({
    required this.icon,
    required this.label,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: message, style: theme.textTheme.labelMedium),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 1),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

