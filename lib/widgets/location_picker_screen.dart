import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/geocoding_service.dart';
import '../services/location_helper.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import 'liquid_glass.dart';

/// Generous Philippines bounding box (Y'Ami Island in the north to Saluag
/// Island in the south, Balabac in the west to Mindanao's east coast), with
/// margin for GPS drift near the edges. Every report in this system is
/// local to Marilao, Bulacan — a pin dropped in another country or an ocean
/// is never a real report, only a map dragged/searched somewhere absurd, so
/// this is a sanity floor, not a precise territorial check.
bool isWithinPhilippines(double latitude, double longitude) =>
    latitude >= 4.0 &&
    latitude <= 21.5 &&
    longitude >= 116.0 &&
    longitude <= 127.0;

/// What the picker hands back once the resident confirms a spot.
class LocationPickResult {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Full-screen "drag the map, pin stays centered" location picker — the same
/// pattern ride-hailing and delivery apps use, chosen over a draggable marker
/// because it never fights the map's own pan gesture, and over asking for
/// raw latitude/longitude because almost nobody has their own coordinates
/// memorized. Three ways to land on a point, in the order most residents
/// will actually reach for them: search an address, tap "use my location",
/// or just drag the map under the pin.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Marilao, Bulacan — same fallback center as hotspot_map_screen.dart.
  static const _fallback = LatLng(14.7575, 120.9480);

  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _settleTimer;
  Timer? _searchDebounce;
  late LatLng _center;
  String? _address;
  bool _resolving = false;
  bool _dragging = false;
  bool _locating = false;
  bool _searching = false;
  List<GeocodeSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? _fallback;
    _resolveAddress(_center);
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() => _resolving = true);
    final address = await GeocodingService.instance.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _address = address;
    });
  }

  /// Fires continuously while the map moves. While a real drag is in
  /// progress the pin lifts and reverse-geocoding waits — running it on
  /// every frame of a pan would spam Nominatim and never keep up anyway.
  /// Once movement settles for [_settleDelay], the pin drops and the
  /// address for the final position resolves once.
  static const _settleDelay = Duration(milliseconds: 350);

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    if (!_dragging) setState(() => _dragging = true);
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () {
      if (!mounted) return;
      setState(() => _dragging = false);
      _resolveAddress(_center);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationHelper.getCurrentLocation();
      final point = LatLng(loc.latitude, loc.longitude);
      _mapController.move(point, 17);
      setState(() => _center = point);
      await _resolveAddress(point);
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      final results = await GeocodingService.instance.searchAddress(value);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = results;
      });
    });
  }

  void _selectSuggestion(GeocodeSuggestion suggestion) {
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    _mapController.move(point, 17);
    setState(() {
      _center = point;
      _address = suggestion.displayName;
      _suggestions = const [];
      _search.clear();
    });
    _searchFocus.unfocus();
  }

  void _confirm() {
    if (!isWithinPhilippines(_center.latitude, _center.longitude)) {
      showMessage(
        context,
        'This pin is outside the Philippines. Drag the map or search for '
        'the real location before confirming.',
        error: true,
      );
      return;
    }
    Navigator.of(context).pop(
      LocationPickResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bantaydengue.app',
                maxZoom: 19,
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
                    onTap: () => launchUrl(
                      Uri.parse('https://carto.com/attributions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // A fixed pin at the optical center of the viewport — the map
          // moves under it, so whatever it points to is always the exact
          // pick. Ignoring pointer events lets taps/drags reach the map.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: _DropPin(lifted: _dragging),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      LiquidGlassIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LiquidGlass(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: TextField(
                            controller: _search,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Search a street, sitio, or landmark',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(13),
                                      child: SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_search.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _search.clear();
                                              setState(
                                                () => _suggestions = const [],
                                              );
                                            },
                                          )
                                        : null),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: LiquidGlass(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: theme.dividerColor),
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.place_outlined,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                                onTap: () => _selectSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 148,
            child: LiquidGlassIconButton(
              icon: Icons.my_location,
              tooltip: 'Use my current location',
              loading: _locating,
              onPressed: _locating ? null : _useCurrentLocation,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: LiquidGlass(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.pin_drop, size: 18, color: AppColors.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _resolving
                              ? Text(
                                  'Finding this address…',
                                  style: theme.textTheme.bodySmall,
                                )
                              : Text(
                                  _address ??
                                      '${_center.latitude.toStringAsFixed(5)}, '
                                          '${_center.longitude.toStringAsFixed(5)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _dragging ? null : _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('Use this location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pin that visibly lifts off the map while the user is dragging, and
/// drops back down once the map settles — the same tactile cue Grab/Google
/// Maps use so "still deciding" reads differently from "picked".
class _DropPin extends StatelessWidget {
  final bool lifted;

  const _DropPin({required this.lifted});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          offset: lifted ? const Offset(0, -0.3) : Offset.zero,
          child: const Icon(
            Icons.location_on,
            size: 44,
            color: AppColors.danger,
            shadows: [
              Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(top: lifted ? 12 : 2),
          width: lifted ? 9 : 15,
          height: lifted ? 3 : 5,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}
