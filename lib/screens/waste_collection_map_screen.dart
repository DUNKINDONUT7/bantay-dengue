import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/section_header.dart';

/// A driving route between the personnel's current position and a selected
/// pickup, drawn on the map itself — not just a link out. OSRM's free public
/// routing server is keyless, matching how weather_service.dart already
/// calls Open-Meteo directly with no backend hop.
class _RouteInfo {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const _RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Map view of pending/scheduled collection requests. Selecting a pin draws
/// an actual driving route from the personnel's current position on the map
/// (via OSRM) and shows distance/ETA — a real route preview, not just a
/// promise of one. The map still can't do live turn-by-turn voice guidance
/// itself, so "Navigate" hands off to whatever navigation app the device has
/// installed (see [openNavigationTo]) for the actual drive.
class WasteCollectionMapScreen extends StatefulWidget {
  const WasteCollectionMapScreen({super.key});

  @override
  State<WasteCollectionMapScreen> createState() =>
      _WasteCollectionMapScreenState();
}

class _WasteCollectionMapScreenState extends State<WasteCollectionMapScreen> {
  static const _marilao = LatLng(14.7575, 120.9480);
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _requests = [];
  LatLng? _userLocation;
  Object? _error;
  bool _loading = true;
  bool _locating = false;
  bool _showCollected = false;
  Map<String, dynamic>? _selected;
  final Set<String> _busyIds = {};
  _RouteInfo? _route;
  bool _routeLoading = false;
  // Bumped on every new route fetch so a slow/late response for a pin the
  // user has since tapped away from can't overwrite the current selection's
  // route after the fact.
  int _routeRequestToken = 0;

  bool _hasLocation(Map<String, dynamic> row) =>
      row['latitude'] != null && row['longitude'] != null;

  List<Map<String, dynamic>> get _visible => _requests
      .where(
        (row) =>
            _hasLocation(row) &&
            (_showCollected ||
                ['pending', 'scheduled'].contains(row['status'])),
      )
      .toList();

  // Requests staff still need to reach that don't have a pin at all — these
  // can never appear as a map marker, but they're still real outstanding
  // work, so the screen must not just silently drop them.
  List<Map<String, dynamic>> get _unpinnedActive => _requests
      .where(
        (row) =>
            !_hasLocation(row) &&
            ['pending', 'scheduled'].contains(row['status']),
      )
      .toList();

  int get _activeTotal => _requests
      .where((row) => ['pending', 'scheduled'].contains(row['status']))
      .length;

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
      _requests = await DatabaseService.instance.fetchWasteRequests();
      if (mounted) _fitToMarkers();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Frames the map around whatever's actually on it instead of leaving the
  /// personnel user staring at an empty stretch of the fallback barangay
  /// center — the failure mode that made this screen look broken/plain when
  /// the only visible pins happened to sit outside the default zoom.
  void _fitToMarkers() {
    final points = _visible
        .map(
          (row) => LatLng(
            (row['latitude'] as num).toDouble(),
            (row['longitude'] as num).toDouble(),
          ),
        )
        .toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  Future<void> _locateMe({bool recenter = false}) async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted && !recenter) {
          showMessage(context, 'Location permission was denied.', error: true);
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted && !recenter) {
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
      // On the initial auto-locate, don't yank the camera away from
      // _fitToMarkers' framing if there's already something on the map to
      // show — only recenter here when the map would otherwise have
      // nothing to fit to, or the user tapped the locate button directly.
      if (!recenter || _visible.isEmpty) {
        _mapController.move(point, 14);
      }
      // A pin can already be selected before the very first location fix
      // resolves (geolocation can take a few seconds) — if so, this is the
      // first moment a route can actually be computed for it.
      final selected = _selected;
      if (selected != null && _route == null && !_routeLoading) {
        final lat = selected['latitude'] as num?;
        final lng = selected['longitude'] as num?;
        if (lat != null && lng != null) {
          unawaited(_loadRoute(LatLng(lat.toDouble(), lng.toDouble())));
        }
      }
    } catch (_) {
      if (mounted && !recenter) {
        showMessage(context, "Couldn't get your location.", error: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _selectRequest(Map<String, dynamic> row) {
    setState(() {
      _selected = row;
      _route = null;
    });
    final lat = row['latitude'] as num?;
    final lng = row['longitude'] as num?;
    if (lat != null && lng != null) {
      unawaited(_loadRoute(LatLng(lat.toDouble(), lng.toDouble())));
    }
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _route = null;
    });
  }

  /// Best-effort route preview only — a failed/slow fetch just leaves the
  /// map without a drawn line. It never blocks the "Navigate" handoff button,
  /// which is the one path that has to actually work every time.
  Future<void> _loadRoute(LatLng destination) async {
    final origin = _userLocation;
    if (origin == null) return;
    final token = ++_routeRequestToken;
    setState(() => _routeLoading = true);
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'BantayDengue/1.0 waste-collection-map'})
          .timeout(const Duration(seconds: 10));
      // A newer selection (or reselection) started after this fetch was
      // issued — its own call owns `_route` now, so don't overwrite it.
      if (token != _routeRequestToken || !mounted) return;
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null) return;
      final points = coordinates
          .map(
            (c) => LatLng(
              ((c as List)[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ),
          )
          .toList();
      setState(() {
        _route = _RouteInfo(
          points: points,
          distanceMeters: (route['distance'] as num).toDouble(),
          durationSeconds: (route['duration'] as num).toDouble(),
        );
      });
    } catch (_) {
      // Silent — the distance/ETA line just won't show, "Navigate" still works.
    } finally {
      if (token == _routeRequestToken && mounted) {
        setState(() => _routeLoading = false);
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> request, String status) async {
    final id = '${request['id']}';
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await DatabaseService.instance.updateWasteStatus(id, status);
      if (mounted) {
        showMessage(context, 'Request marked ${humanize(status).toLowerCase()}.');
      }
      await _load();
      if (mounted) _clearSelection();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  /// Lets staff still act on requests the map itself can't plot — closing
  /// this sheet before calling `_updateStatus` (rather than trying to keep
  /// the sheet's own list reactive) keeps this simple: the underlying data
  /// still refreshes via `_load()`, the sheet just isn't open to watch it.
  Future<void> _showUnpinnedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Without a location pin',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "These pickups can't be mapped or navigated to yet. "
                    'Coordinate with the resident directly, or ask them to '
                    'add a pin from their report.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _unpinnedActive.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _unpinnedActive[index];
                        return _UnpinnedRequestTile(
                          item: item,
                          busy: _busyIds.contains('${item['id']}'),
                          onSchedule: () {
                            Navigator.pop(sheetContext);
                            _updateStatus(item, 'scheduled');
                          },
                          onCollect: () {
                            Navigator.pop(sheetContext);
                            _updateStatus(item, 'collected');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Collection map',
              subtitle:
                  'Tap a pin, then Navigate for turn-by-turn directions to that pickup.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_shipping_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            // Same total the dashboard shows — counts every
                            // active request, not just the ones with a pin
                            // to plot, so this can never read "0" while
                            // work is actually outstanding.
                            Text(
                              '$_activeTotal to reach',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                        if (_unpinnedActive.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.location_off_outlined,
                              size: 16,
                            ),
                            label: Text(
                              '${_unpinnedActive.length} without a pin',
                            ),
                            onPressed: _showUnpinnedSheet,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Show collected'),
                    selected: _showCollected,
                    onSelected: (value) =>
                        setState(() => _showCollected = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: _buildMapStack(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapStack(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? _marilao,
            initialZoom: 13,
            onTap: (_, __) => _clearSelection(),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.bantaydengue.app',
              maxZoom: 19,
            ),
            if (_route != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 5,
                    color: AppColors.info,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(
              markers: _visible.map((row) {
                final color = statusColor('${row['status']}', scheme);
                final selected = _selected != null &&
                    _selected!['id'] == row['id'];
                return Marker(
                  point: LatLng(
                    (row['latitude'] as num).toDouble(),
                    (row['longitude'] as num).toDouble(),
                  ),
                  width: selected ? 54 : 44,
                  height: selected ? 54 : 44,
                  child: GestureDetector(
                    onTap: () => _selectRequest(row),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: selected ? 3 : 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                        size: selected ? 24 : 19,
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
        if (!_loading && _activeTotal == 0)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _EmptyMapOverlay(
                  title: 'No active pickups right now',
                  message: 'New collection requests will show up here as pins.',
                ),
              ),
            ),
          )
        else if (!_loading &&
            _visible.where((r) => r['status'] != 'collected').isEmpty)
          // There IS outstanding work (_activeTotal > 0) — it's just none
          // of it has a location pin, so nothing can be plotted. Saying "no
          // active pickups" here would be actively wrong, not just unhelpful.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _EmptyMapOverlay(
                  title: "$_activeTotal pickup${_activeTotal == 1 ? '' : 's'} waiting, no pins yet",
                  message: "None of them have a location set — tap \"without a pin\" above to see and act on them.",
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: LiquidGlass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: AppColors.warning, label: 'Pending'),
                const SizedBox(width: 10),
                _LegendDot(color: AppColors.info, label: 'Scheduled'),
                if (_showCollected) ...[
                  const SizedBox(width: 10),
                  _LegendDot(color: AppColors.success, label: 'Collected'),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: LiquidGlassIconButton(
            icon: Icons.my_location,
            loading: _locating,
            tooltip: 'Center on my location',
            onPressed: _locating ? null : () => _locateMe(),
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
                    ? _requestCard(context, key: ValueKey(_selected!['id']))
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Distance/ETA line for the currently selected pin's route preview —
  /// separate from the "Navigate" button so the preview (best-effort, can
  /// silently fail) never implies anything about whether live turn-by-turn
  /// will work, which is entirely up to the external navigation app.
  Widget _routeStatusRow(BuildContext context) {
    if (_routeLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Finding route…', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }
    if (_route != null) {
      final km = (_route!.distanceMeters / 1000).toStringAsFixed(1);
      final minutes = (_route!.durationSeconds / 60).round();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_outlined, size: 15, color: AppColors.info),
          const SizedBox(width: 6),
          Text(
            '$km km · ~$minutes min drive',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    if (_userLocation == null) {
      return Text(
        'Turn on location to preview the route',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _requestCard(BuildContext context, {required Key key}) {
    final request = _selected!;
    final resident = request['profiles'] as Map<String, dynamic>?;
    final status = '${request['status']}';
    final latitude = request['latitude'] as num;
    final longitude = request['longitude'] as num;
    final handledBy = request['handled_by'] as String?;
    final assignedToMe = handledBy != null &&
        handledBy == authService.currentUser?.id;
    final busy = _busyIds.contains('${request['id']}');

    return LiquidGlass(
      key: key,
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request['location_text'] ?? 'Pickup location'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested by ${resident?['full_name'] ?? 'Resident'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          _routeStatusRow(context),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => openNavigationTo(latitude, longitude),
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Navigate'),
              ),
              if (status == 'pending')
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _updateStatus(request, 'scheduled'),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available, size: 18),
                  label: const Text('Schedule & assign'),
                ),
              if (status == 'scheduled' && (handledBy == null || assignedToMe))
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _updateStatus(request, 'collected'),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.task_alt, size: 18),
                  label: Text(
                    handledBy == null ? 'Take & mark collected' : 'Mark collected',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row for a request with no coordinates — same status/assignment info and
/// workflow actions as a mapped pin's card, minus anything that needs a
/// location (no Navigate button, no distance/ETA).
class _UnpinnedRequestTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onSchedule;
  final VoidCallback onCollect;

  const _UnpinnedRequestTile({
    required this.item,
    required this.busy,
    required this.onSchedule,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final resident = item['profiles'] as Map<String, dynamic>?;
    final status = '${item['status']}';
    final handledBy = item['handled_by'] as String?;
    final assignedToMe =
        handledBy != null && handledBy == authService.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['location_text'] ?? 'Pickup location'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested by ${resident?['full_name'] ?? 'Resident'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending')
                OutlinedButton.icon(
                  onPressed: busy ? null : onSchedule,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available, size: 16),
                  label: const Text('Schedule & assign'),
                ),
              if (status == 'scheduled' && (handledBy == null || assignedToMe))
                OutlinedButton.icon(
                  onPressed: busy ? null : onCollect,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.task_alt, size: 16),
                  label: Text(
                    handledBy == null ? 'Take & mark collected' : 'Mark collected',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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

/// Shown centered over the map when there's nothing to reach — without this
/// the screen was just a bare, half-detailed basemap with no marker on it,
/// which reads as broken rather than "caught up."
class _EmptyMapOverlay extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyMapOverlay({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 28,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
