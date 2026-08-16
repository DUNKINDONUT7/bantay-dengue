import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/weather_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class HotspotMapScreen extends StatefulWidget {
  const HotspotMapScreen({super.key});

  @override
  State<HotspotMapScreen> createState() => _HotspotMapScreenState();
}

class _HotspotMapScreenState extends State<HotspotMapScreen> {
  static const _marilao = LatLng(14.7575, 120.9480);
  List<Map<String, dynamic>> _hotspots = [];
  WeatherRisk? _weather;
  Object? _error;
  bool _loading = true;
  Map<String, dynamic>? _selected;

  bool get _canManage =>
      authService.currentUser?.role == UserRole.doctor ||
      authService.currentUser?.role == UserRole.admin;

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
      final values = await Future.wait<dynamic>([
        DatabaseService.instance.fetchHotspots(),
        WeatherService.instance.fetchRisk(
          latitude: _marilao.latitude,
          longitude: _marilao.longitude,
        ),
      ]);
      _hotspots = values[0] as List<Map<String, dynamic>>;
      _weather = values[1] as WeatherRisk;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveHotspot() async {
    final barangay = TextEditingController(
      text: '${_selected?['barangay'] ?? ''}',
    );
    final latitude = TextEditingController(
      text: '${_selected?['latitude'] ?? _marilao.latitude}',
    );
    final longitude = TextEditingController(
      text: '${_selected?['longitude'] ?? _marilao.longitude}',
    );
    final cases = TextEditingController(
      text: '${_selected?['case_count'] ?? 0}',
    );
    var risk = '${_selected?['risk_level'] ?? 'low'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            _selected == null ? 'Add verified hotspot' : 'Update hotspot',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: barangay,
                    decoration: const InputDecoration(
                      labelText: 'Barangay / area',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latitude,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: longitude,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cases,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Verified case count',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: risk,
                    decoration: const InputDecoration(
                      labelText: 'Risk classification',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => risk = value ?? risk),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      final lat = double.tryParse(latitude.text);
      final lng = double.tryParse(longitude.text);
      final count = int.tryParse(cases.text);
      if (barangay.text.trim().isEmpty ||
          lat == null ||
          lng == null ||
          count == null) {
        if (mounted) {
          showMessage(
            context,
            'Complete all hotspot fields with valid values.',
            error: true,
          );
        }
      } else {
        try {
          await DatabaseService.instance.upsertHotspot(
            id: _selected?['id'] as String?,
            barangay: barangay.text.trim(),
            riskLevel: risk,
            caseCount: count,
            latitude: lat,
            longitude: lng,
          );
          if (mounted) showMessage(context, 'Hotspot saved.');
          await _load();
        } catch (error) {
          if (mounted) showMessage(context, errorMessage(error), error: true);
        }
      }
    }
    barangay.dispose();
    latitude.dispose();
    longitude.dispose();
    cases.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() => _selected = null);
                _saveHotspot();
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add hotspot'),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Dengue hotspot map',
              subtitle:
                  'Verified local records shown on OpenStreetMap. Avoid drawing conclusions from unverified reports.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (_weather != null)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.water_drop_outlined),
                  ),
                  title: Text(
                    'Breeding-condition indicator: ${_weather!.label}',
                  ),
                  subtitle: Text(_weather!.summary),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(errorMessage(_error!)),
                  actions: [
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _marilao,
                      initialZoom: 13,
                      onTap: (_, __) => setState(() => _selected = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.bantaydengue.app',
                        maxZoom: 19,
                      ),
                      CircleLayer(
                        circles: _hotspots.map((row) {
                          final point = LatLng(
                            (row['latitude'] as num).toDouble(),
                            (row['longitude'] as num).toDouble(),
                          );
                          final color = statusColor(
                            '${row['risk_level']}',
                            Theme.of(context).colorScheme,
                          );
                          return CircleMarker(
                            point: point,
                            radius:
                                26 +
                                ((row['case_count'] as num?)?.toDouble() ?? 0)
                                    .clamp(0, 24),
                            color: color.withValues(alpha: .22),
                            borderColor: color,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: false,
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: _hotspots.map((row) {
                          return Marker(
                            point: LatLng(
                              (row['latitude'] as num).toDouble(),
                              (row['longitude'] as num).toDouble(),
                            ),
                            width: 48,
                            height: 48,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: statusColor(
                                  '${row['risk_level']}',
                                  Theme.of(context).colorScheme,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.location_on),
                              onPressed: () => setState(() => _selected = row),
                            ),
                          );
                        }).toList(),
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_selected != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 36,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Card(
                            elevation: 8,
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.shield_outlined),
                              ),
                              title: Text(
                                '${_selected!['barangay'] ?? 'Mapped area'}',
                              ),
                              subtitle: Text(
                                '${_selected!['case_count'] ?? 0} verified case(s) · Updated ${formatDateTime(_selected!['updated_at'])}',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  StatusChip(
                                    '${_selected!['risk_level'] ?? 'low'}',
                                  ),
                                  if (_canManage)
                                    IconButton(
                                      onPressed: _saveHotspot,
                                      icon: const Icon(Icons.edit_outlined),
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
          ],
        ),
      ),
    );
  }
}
