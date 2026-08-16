import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../services/database_service.dart';
import '../services/image_picker_stub.dart';
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

class _ReportFormState extends State<ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Uint8List? _photo;
  bool _submitting = false;
  bool _locating = false;
  DateTime? _lastSubmitAttempt;
  bool _manualCoordsExpanded = false;

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
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showMessage(
            context,
            'Location permission was denied. You can still enter '
            'coordinates manually below, or just describe the landmark.',
            error: true,
          );
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          showMessage(
            context,
            'Turn on location services to use this, or enter coordinates '
            'manually below.',
            error: true,
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      _latitude.text = position.latitude.toStringAsFixed(6);
      _longitude.text = position.longitude.toStringAsFixed(6);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          "Couldn't get your location. You can enter coordinates manually "
          'below instead.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Same client-side cooldown caveat as signup_screen.dart's _submit —
    // deters accidental double-submits, not a real abuse control.
    final now = DateTime.now();
    if (_lastSubmitAttempt != null &&
        now.difference(_lastSubmitAttempt!) < const Duration(seconds: 10)) {
      showMessage(
        context,
        'Please wait a few seconds before submitting again.',
        error: true,
      );
      return;
    }
    _lastSubmitAttempt = now;
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
      showMessage(
        context,
        'Report submitted securely for health-center verification.',
      );
      _formKey.currentState!.reset();
      _location.clear();
      _details.clear();
      _latitude.clear();
      _longitude.clear();
      setState(() => _photo = null);
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
              title: widget.title,
              subtitle: widget.description,
              onBack: () => context.go('/civilian/report'),
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
                          CircleAvatar(
                            radius: 30,
                            child: Icon(widget.icon, size: 30),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _location,
                            decoration: const InputDecoration(
                              labelText: 'Location or landmark',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              hintText: 'Street, sitio, or barangay landmark',
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
                            decoration: const InputDecoration(
                              labelText: 'Details',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 10
                                ? 'Provide at least 10 characters so staff can verify the report.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Exact location',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pinpoints the report for staff dispatch. '
                            'Optional, but much more reliable than typing '
                            'coordinates from memory.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          if (_latitude.text.isNotEmpty &&
                              _longitude.text.isNotEmpty &&
                              !_manualCoordsExpanded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Location captured (${_latitude.text}, ${_longitude.text})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(() {
                                            _latitude.clear();
                                            _longitude.clear();
                                          }),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            )
                          else ...[
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
                                  : const Icon(Icons.my_location_outlined),
                              label: Text(
                                _locating
                                    ? 'Getting your location…'
                                    : 'Use my current location',
                              ),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () => _manualCoordsExpanded = true,
                                    ),
                              child: const Text(
                                'Or enter coordinates manually',
                              ),
                            ),
                            if (_manualCoordsExpanded) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _latitude,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                            signed: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Latitude',
                                      ),
                                      validator: _coordinateValidator,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _longitude,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                            signed: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Longitude',
                                      ),
                                      validator: _coordinateValidator,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    final bytes = await pickEvidenceImage(
                                      context,
                                    );
                                    if (bytes != null && mounted) {
                                      setState(() => _photo = bytes);
                                    }
                                  },
                            icon: Icon(
                              _photo == null
                                  ? Icons.add_a_photo_outlined
                                  : Icons.check_circle,
                            ),
                            label: Text(
                              _photo == null
                                  ? 'Add private photo evidence'
                                  : 'Photo ready · Tap to replace',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Evidence is stored in a private Supabase bucket and is visible only to you and authorized personnel.',
                            style: Theme.of(context).textTheme.bodySmall,
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
                              _submitting ? 'Submitting…' : 'Submit report',
                            ),
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

  String? _coordinateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null
        ? 'Enter a valid number.'
        : null;
  }
}
