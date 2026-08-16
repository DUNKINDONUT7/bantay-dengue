import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/database_service.dart';
import '../services/image_picker_stub.dart';
import '../utils/ui_helpers.dart';
import 'section_header.dart';

/// Lets a resident edit a report they filed themselves. Only ever shown for
/// their own reports while status is still 'pending' — report_history_screen
/// hides the entry point otherwise, and the database enforces the same rule
/// server-side (supabase/APPLY_THIS_NOW.sql) so it can't be bypassed.
class EditReportScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const EditReportScreen({super.key, required this.report});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _location;
  late final TextEditingController _details;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  Uint8List? _newPhoto;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    _location = TextEditingController(
      text: '${report['location_text'] ?? ''}',
    );
    _details = TextEditingController(text: '${report['description'] ?? ''}');
    _latitude = TextEditingController(
      text: report['latitude'] == null ? '' : '${report['latitude']}',
    );
    _longitude = TextEditingController(
      text: report['longitude'] == null ? '' : '${report['longitude']}',
    );
  }

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
            'Location permission was denied.',
            error: true,
          );
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          showMessage(context, 'Turn on location services first.', error: true);
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
        showMessage(context, "Couldn't get your location.", error: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.updateReport(
        reportId: widget.report['id'] as String,
        description: _details.text.trim(),
        locationText: _location.text.trim(),
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        newPhotoBytes: _newPhoto,
      );
      if (!mounted) return;
      showMessage(context, 'Report updated.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _coordinateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null
        ? 'Enter a valid number.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final reportType = humanize(widget.report['report_type'] as String?);
    return Scaffold(
      appBar: AppBar(title: Text('Edit report · $reportType')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SectionHeader(
              title: 'Edit your report',
              subtitle:
                  'You can update this while it is still pending review. '
                  'Once a health worker starts reviewing it, editing locks.',
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
                            'Coordinates (optional)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving || _locating
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
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final bytes = await pickEvidenceImage(
                                      context,
                                    );
                                    if (bytes != null && mounted) {
                                      setState(() => _newPhoto = bytes);
                                    }
                                  },
                            icon: Icon(
                              _newPhoto == null
                                  ? Icons.add_a_photo_outlined
                                  : Icons.check_circle,
                            ),
                            label: Text(
                              _newPhoto == null
                                  ? (widget.report['photo_url'] == null
                                        ? 'Add private photo evidence'
                                        : 'Replace existing photo')
                                  : 'New photo ready · Tap to replace again',
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _saving ? 'Saving…' : 'Save changes',
                                  ),
                                ),
                              ),
                            ],
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
