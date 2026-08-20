import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/analytics_widgets.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/section_header.dart';

class HotspotMapScreen extends StatefulWidget {
  const HotspotMapScreen({super.key});

  @override
  State<HotspotMapScreen> createState() => _HotspotMapScreenState();
}

class _HotspotMapScreenState extends State<HotspotMapScreen> {
  static const _marilao = LatLng(14.7575, 120.9480);
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _hotspots = [];
  List<Map<String, dynamic>> _reports = [];
  WeatherRisk? _weather;
  LatLng? _userLocation;
  Object? _error;
  bool _loading = true;
  bool _locating = false;
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _selectedReport;

  bool get _canManage =>
      authService.currentUser?.role == UserRole.doctor ||
      authService.currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _load();
    _locateMe(recenter: true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final center = _userLocation ?? _marilao;
      final values = await Future.wait<dynamic>([
        DatabaseService.instance.fetchHotspots(),
        // RLS already scopes this: residents only ever get their own
        // reports back, staff (health_worker/admin) get everyone's — so
        // this is safe to plot individually without a client-side check.
        // Both report types (case + breeding site) are plotted; see the
        // marker builder below for the per-type icon.
        DatabaseService.instance.fetchReports(),
        WeatherService.instance.fetchRisk(
          latitude: center.latitude,
          longitude: center.longitude,
        ),
      ]);
      _hotspots = values[0] as List<Map<String, dynamic>>;
      _reports = (values[1] as List<Map<String, dynamic>>)
          .where((row) => row['latitude'] != null && row['longitude'] != null)
          .toList();
      _weather = values[2] as WeatherRisk;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Best-effort: finds the resident's current position and, on first
  /// launch, recenters the map there instead of the fixed Marilao fallback.
  /// A denied permission or disabled GPS just leaves the fallback center —
  /// this never blocks the map from loading.
  Future<void> _locateMe({bool recenter = false}) async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted && recenter == false) {
          showMessage(context, 'Location permission was denied.', error: true);
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted && recenter == false) {
          showMessage(context, 'Turn on location services first.', error: true);
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _userLocation = point);
      _mapController.move(point, 15);
    } catch (_) {
      if (mounted && recenter == false) {
        showMessage(context, "Couldn't get your location.", error: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (routeContext, animation, __) => FadeTransition(
          opacity: animation,
          child: Scaffold(
            body: SafeArea(
              child: _buildMapStack(routeContext, expanded: true),
            ),
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
          ),
        ),
      ),
    );
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
            width: min(440, MediaQuery.sizeOf(context).width - 48),
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
                        value: 'medium',
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
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;
    final compactHeight = (size.height * (isWide ? 0.6 : 0.42)).clamp(
      300.0,
      540.0,
    );

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
        child: SingleChildScrollView(
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
                  tooltip: 'Refresh',
                ),
              ),
              if (_weather != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: WeatherBreedingCard(
                    label: _weather!.label,
                    summary: _weather!.summary,
                    dailyRainMm: _weather!.dailyRainMm,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.97 + (0.03 * value),
                      child: child,
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: compactHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppGlow.soft(
                        Theme.of(context).colorScheme.shadow,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildMapStack(context, expanded: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapStack(BuildContext context, {required bool expanded}) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _marilao,
            initialZoom: 13,
            onTap: (_, __) => setState(() {
              _selected = null;
              _selectedReport = null;
            }),
          ),
          children: [
            // CARTO's basemap instead of raw OSM tiles: the stock OSM style
            // is a bright, busy GIS-tool look (mustard roads, saturated
            // land-use fills) that clashes with the app's warm, restrained
            // editorial theme. CARTO's light_all tiles are muted and
            // theme-matched, so the map reads as part of the app instead of
            // an embedded third-party widget. Same free, no-key OSM-derived
            // data — just a calmer render of it, attributed below.
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
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
                      ((row['case_count'] as num?)?.toDouble() ?? 0).clamp(
                        0,
                        24,
                      ),
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
                    tooltip:
                        '${row['barangay'] ?? 'Hotspot'} · ${humanize('${row['risk_level']}')} risk',
                    onPressed: () => setState(() {
                      _selectedReport = null;
                      _selected = row;
                    }),
                  ),
                );
              }).toList(),
            ),
            // Individual report pins, exactly where each one was filed.
            // RLS already limits what fetchReports returned above (own
            // reports for a resident, all reports for staff), so this
            // never surfaces another resident's report to a resident.
            MarkerLayer(
              markers: _reports.map((row) {
                final color = statusColor(
                  '${row['status']}',
                  Theme.of(context).colorScheme,
                );
                return Marker(
                  point: LatLng(
                    (row['latitude'] as num).toDouble(),
                    (row['longitude'] as num).toDouble(),
                  ),
                  width: 34,
                  height: 34,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selected = null;
                      _selectedReport = row;
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        row['report_type'] == 'breeding_site'
                            ? Icons.pest_control_outlined
                            : Icons.coronavirus_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation!,
                    width: 60,
                    height: 60,
                    child: const _PulsingLocationDot(),
                  ),
                ],
              ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
                TextSourceAttribution(
                  'CARTO',
                  onTap: () =>
                      launchUrl(Uri.parse('https://carto.com/attributions')),
                ),
              ],
            ),
          ],
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 12,
          left: 12,
          child: LiquidGlass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: AppColors.riskLow, label: 'Low'),
                SizedBox(width: 10),
                _LegendDot(color: AppColors.riskMedium, label: 'Moderate'),
                SizedBox(width: 10),
                _LegendDot(color: AppColors.riskHigh, label: 'High'),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              LiquidGlassIconButton(
                icon: Icons.my_location,
                loading: _locating,
                tooltip: 'Center on my location',
                onPressed: _locating ? null : () => _locateMe(),
              ),
              const SizedBox(height: 8),
              LiquidGlassIconButton(
                icon: expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                tooltip: expanded ? 'Exit full screen' : 'Full screen',
                onPressed: expanded
                    ? () => Navigator.of(context).maybePop()
                    : _openFullscreen,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _selected != null
                    ? _hotspotCard(context, key: ValueKey('hotspot-${_selected!['id']}'))
                    : _selectedReport != null
                        ? _reportCard(
                            context,
                            key: ValueKey('report-${_selectedReport!['id']}'),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hotspotCard(BuildContext context, {required Key key}) {
    return LiquidGlass(
      key: key,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
        title: Text('${_selected!['barangay'] ?? 'Mapped area'}'),
        subtitle: Text(
          '${_selected!['case_count'] ?? 0} verified case(s) · Updated ${formatDateTime(_selected!['updated_at'])}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip('${_selected!['risk_level'] ?? 'low'}'),
            if (_canManage)
              IconButton(
                onPressed: _saveHotspot,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit hotspot',
              ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, {required Key key}) {
    return LiquidGlass(
      key: key,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            _selectedReport!['report_type'] == 'breeding_site'
                ? Icons.pest_control_outlined
                : Icons.coronavirus_outlined,
          ),
        ),
        title: Text(humanize('${_selectedReport!['report_type']}')),
        subtitle: Text(
          '${_selectedReport!['location_text'] ?? 'Location not supplied'} · '
          '${formatDateTime(_selectedReport!['created_at'])}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusChip('${_selectedReport!['status'] ?? 'pending'}'),
      ),
    );
  }
}

/// A living "you are here" marker: a soft ring that repeatedly expands and
/// fades behind a solid dot, the same idiom mobile map apps use so the
/// marker reads as live GPS tracking rather than a static pin.
class _PulsingLocationDot extends StatefulWidget {
  const _PulsingLocationDot();

  @override
  State<_PulsingLocationDot> createState() => _PulsingLocationDotState();
}

class _PulsingLocationDotState extends State<_PulsingLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Container(
                width: 22 + (t * 34),
                height: 22 + (t * 34),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 6),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
