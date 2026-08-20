import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/image_picker_stub.dart';
import '../services/location_helper.dart';
import '../utils/submit_throttle.dart';
import '../utils/ui_helpers.dart';
import 'section_header.dart';

/// A dedicated screen for requesting waste collection — mirrors
/// report_form.dart's layout and interaction patterns (GPS location, photo
/// evidence, validated fields) so the two "file something for staff to act
/// on" flows in the app feel like the same product, not two different apps
/// stitched together.
class RequestWasteScreen extends StatefulWidget {
  const RequestWasteScreen({super.key});

  @override
  State<RequestWasteScreen> createState() => _RequestWasteScreenState();
}

class _RequestWasteScreenState extends State<RequestWasteScreen>
    with SubmitThrottle {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _details = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  Uint8List? _photo;
  bool _submitting = false;
  bool _locating = false;
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
      final loc = await LocationHelper.getCurrentLocation();
      _latitude.text = loc.latitude.toStringAsFixed(6);
      _longitude.text = loc.longitude.toStringAsFixed(6);
      if (mounted) setState(() {});
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      final message = switch (failure.reason) {
        LocationFailureReason.permissionDenied =>
          'Location permission was denied.',
        LocationFailureReason.serviceDisabled =>
          'Turn on location services first.',
        LocationFailureReason.other => "Couldn't get your location.",
      };
      showMessage(context, message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _coordinateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null ? 'Enter a valid number.' : null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null) setState(() => _preferredDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      await DatabaseService.instance.createWasteRequest(
        description: _details.text.trim(),
        locationText: _location.text.trim(),
        preferredDate: _preferredDate,
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        photoBytes: _photo,
      );
      if (!mounted) return;
      showMessage(context, 'Waste collection request submitted.');
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
              title: 'Request waste collection',
              subtitle:
                  'Report waste that may collect standing water, for pickup '
                  'scheduling by the waste management team.',
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
                            controller: _location,
                            decoration: const InputDecoration(
                              labelText: 'Pickup location or landmark',
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
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              labelText: 'Waste details',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_outlined),
                              hintText:
                                  'What kind of waste, how much, how long it\'s been there',
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 5
                                ? 'Add a short description so the crew knows what to expect.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Exact location',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Optional, but helps the collection team find the spot directly.',
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
                                      style: Theme.of(context).textTheme.bodySmall,
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
                                      child: CircularProgressIndicator(strokeWidth: 2),
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
                                  : () => setState(() => _manualCoordsExpanded = true),
                              child: const Text('Or enter coordinates manually'),
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
                                      decoration: const InputDecoration(labelText: 'Latitude'),
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
                                      decoration: const InputDecoration(labelText: 'Longitude'),
                                      validator: _coordinateValidator,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Preferred pickup date',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              formatDateTime(_preferredDate).split(' ·').first,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    final bytes = await pickEvidenceImage(context);
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
                          const SizedBox(height: 4),
                          Text(
                            'Evidence is stored in a private bucket and is visible only '
                            'to you and authorized personnel.',
                            style: Theme.of(context).textTheme.bodySmall,
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
                            label: Text(_submitting ? 'Submitting…' : 'Submit request'),
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
