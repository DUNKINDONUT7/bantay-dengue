import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import '../services/image_picker_stub.dart';
import '../services/location_helper.dart';
import '../theme/app_theme.dart';
import '../utils/submit_throttle.dart';
import '../utils/ui_helpers.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Uint8List? _photo;
  bool _submitting = false;
  bool _locating = false;
  bool _geocoding = false;
  bool? _nearbyDuplicate;
  bool _manualCoordsExpanded = false;

  bool get _hasCoordinates =>
      _latitude.text.trim().isNotEmpty && _longitude.text.trim().isNotEmpty;

  bool get _isDengueCase => widget.reportType == 'dengue_case';

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

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationHelper.getCurrentLocation();
      _latitude.text = loc.latitude.toStringAsFixed(6);
      _longitude.text = loc.longitude.toStringAsFixed(6);
      if (mounted) setState(() => _manualCoordsExpanded = false);
      unawaited(_afterCoordinatesResolved());
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      final message = switch (failure.reason) {
        LocationFailureReason.permissionDenied =>
          'Location permission was denied. You can still enter '
              'coordinates manually below, or just describe the landmark.',
        LocationFailureReason.serviceDisabled =>
          'Turn on location services to use this, or enter coordinates '
              'manually below.',
        LocationFailureReason.other =>
          "Couldn't get your location. You can enter coordinates manually "
              'below instead.',
      };
      showMessage(context, message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Runs once GPS coordinates are captured: fills in a human-readable
  /// location (if the resident hasn't already typed one) and checks whether
  /// someone already flagged this spot recently, so we can nudge instead of
  /// silently letting duplicate reports pile up. Both are best-effort and
  /// never block submission if they fail or time out.
  Future<void> _afterCoordinatesResolved() async {
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    if (lat == null || lng == null) return;

    if (_location.text.trim().isEmpty) {
      setState(() => _geocoding = true);
      final address = await GeocodingService.instance.reverseGeocode(
        latitude: lat,
        longitude: lng,
      );
      if (mounted) {
        setState(() {
          _geocoding = false;
          if (address != null && _location.text.trim().isEmpty) {
            _location.text = address;
          }
        });
      }
    }

    final duplicate = await DatabaseService.instance.nearbyReportExists(
      reportType: widget.reportType,
      latitude: lat,
      longitude: lng,
    );
    if (mounted) setState(() => _nearbyDuplicate = duplicate);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
    setState(() => _submitting = true);
    try {
      await DatabaseService.instance.submitReport(
        type: widget.reportType,
        description: _details.text.trim(),
        locationText: _location.text.trim(),
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        photoBytes: _photo,
      );
      if (!mounted) return;
      showMessage(context, _submittedMessage);
      _formKey.currentState!.reset();
      _location.clear();
      _details.clear();
      _latitude.clear();
      _longitude.clear();
      setState(() {
        _photo = null;
        _manualCoordsExpanded = false;
        _nearbyDuplicate = null;
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
    final accent = _accentColor(scheme);

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
                  constraints: const BoxConstraints(maxWidth: 760),
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
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _location,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Location or landmark',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                ),
                                hintText:
                                    'House number, street, sitio, or nearby landmark',
                                suffixIcon: _geocoding
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                helperText: _geocoding
                                    ? 'Filling this in from your GPS pin...'
                                    : null,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 3
                                  ? 'Enter a recognizable location.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
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
                              validator: (value) =>
                                  value == null || value.trim().length < 10
                                  ? 'Provide at least 10 characters so staff can verify the report.'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            _FormSection(
                              title: 'Exact location',
                              message:
                                  'A precise pin helps the assigned team find the spot without back-and-forth.',
                              icon: Icons.pin_drop_outlined,
                              accent: accent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_hasCoordinates &&
                                      !_manualCoordsExpanded) ...[
                                    _StatusPanel(
                                      icon: Icons.check_circle,
                                      title: 'GPS location captured',
                                      message:
                                          '${_latitude.text}, ${_longitude.text}',
                                      trailing: TextButton(
                                        onPressed: _submitting
                                            ? null
                                            : () => setState(() {
                                                _latitude.clear();
                                                _longitude.clear();
                                                _nearbyDuplicate = null;
                                              }),
                                        child: const Text('Clear'),
                                      ),
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
                                    const SizedBox(height: 10),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: _submitting || _locating
                                        ? null
                                        : _useCurrentLocation,
                                    icon: _locating
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.my_location_outlined,
                                          ),
                                    label: Text(
                                      _locating
                                          ? 'Getting your location...'
                                          : _hasCoordinates
                                          ? 'Update current location'
                                          : 'Use my current location',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.center,
                                    child: TextButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () => setState(
                                              () => _manualCoordsExpanded =
                                                  !_manualCoordsExpanded,
                                            ),
                                      icon: Icon(
                                        _manualCoordsExpanded
                                            ? Icons.expand_less
                                            : Icons.edit_location_alt_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _manualCoordsExpanded
                                            ? 'Hide manual coordinates'
                                            : 'Enter coordinates manually',
                                      ),
                                    ),
                                  ),
                                  if (_manualCoordsExpanded) ...[
                                    const SizedBox(height: 8),
                                    if (compact)
                                      Column(
                                        children: [
                                          _CoordinateField(
                                            controller: _latitude,
                                            label: 'Latitude',
                                            validator: _latitudeValidator,
                                          ),
                                          const SizedBox(height: 12),
                                          _CoordinateField(
                                            controller: _longitude,
                                            label: 'Longitude',
                                            validator: _longitudeValidator,
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _CoordinateField(
                                              controller: _latitude,
                                              label: 'Latitude',
                                              validator: _latitudeValidator,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _CoordinateField(
                                              controller: _longitude,
                                              label: 'Longitude',
                                              validator: _longitudeValidator,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FormSection(
                              title: 'Photo evidence',
                              message:
                                  'Private and visible only to you and authorized personnel.',
                              icon: Icons.photo_camera_outlined,
                              accent: accent,
                              child: _photo == null
                                  ? OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () async {
                                              final bytes =
                                                  await pickEvidenceImage(
                                                    context,
                                                  );
                                              if (bytes != null && mounted) {
                                                setState(() => _photo = bytes);
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.add_a_photo_outlined,
                                      ),
                                      label: const Text('Add private photo'),
                                    )
                                  : Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.md,
                                          ),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Evidence attached',
                                                style:
                                                    theme.textTheme.labelLarge,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Uploaded securely with your report.',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _submitting
                                              ? null
                                              : () async {
                                                  final bytes =
                                                      await pickEvidenceImage(
                                                        context,
                                                      );
                                                  if (bytes != null &&
                                                      mounted) {
                                                    setState(
                                                      () => _photo = bytes,
                                                    );
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                          ),
                                          tooltip: 'Replace photo',
                                        ),
                                        IconButton(
                                          onPressed: _submitting
                                              ? null
                                              : () =>
                                                    setState(
                                                      () => _photo = null,
                                                    ),
                                          icon: const Icon(Icons.close),
                                          tooltip: 'Remove photo',
                                        ),
                                      ],
                                    ),
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

  String? _latitudeValidator(String? value) {
    return _coordinateValidator(
      value,
      otherValue: _longitude.text,
      rangeLabel: 'Latitude',
      min: -90,
      max: 90,
    );
  }

  String? _longitudeValidator(String? value) {
    return _coordinateValidator(
      value,
      otherValue: _latitude.text,
      rangeLabel: 'Longitude',
      min: -180,
      max: 180,
    );
  }

  String? _coordinateValidator(
    String? value, {
    required String otherValue,
    required String rangeLabel,
    required double min,
    required double max,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return otherValue.trim().isEmpty ? null : 'Enter both coordinates.';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid number.';
    if (parsed < min || parsed > max) {
      return '$rangeLabel must be between ${min.toInt()} and ${max.toInt()}.';
    }
    return null;
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
  final Widget? trailing;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.trailing,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _CoordinateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;

  const _CoordinateField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
