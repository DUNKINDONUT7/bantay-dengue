import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../services/location_helper.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import 'liquid_glass.dart';
import 'location_picker_screen.dart';

export 'location_picker_screen.dart' show LocationPickResult;

/// Drop-in replacement for "type your latitude/longitude" — a compact map
/// preview that opens [LocationPickerScreen] to set the point, plus a
/// one-tap GPS shortcut for the common case. The caller stays the source of
/// truth for latitude/longitude (so it can still feed a submit call and
/// existing validators); this widget only ever reports picks upward.
class LocationPickerField extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final bool enabled;
  final ValueChanged<LocationPickResult> onChanged;
  final VoidCallback onCleared;

  const LocationPickerField({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    required this.onCleared,
    this.enabled = true,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  bool _locating = false;
  String? _address;

  bool get _hasPoint => widget.latitude != null && widget.longitude != null;

  @override
  void didUpdateWidget(covariant LocationPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent clears its lat/lng controllers on submit-reset or an
    // explicit "Clear" tap — mirror that here so a stale address caption
    // doesn't linger over an empty picker.
    if (!_hasPoint && (oldWidget.latitude != null || oldWidget.longitude != null)) {
      _address = null;
    }
  }

  Future<void> _quickUseCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationHelper.getCurrentLocation();
      if (!isWithinPhilippines(loc.latitude, loc.longitude)) {
        if (mounted) {
          showMessage(
            context,
            "That location is outside the Philippines — this device's GPS "
            'may be spoofed or inaccurate right now. Try "Pick on map" '
            'instead.',
            error: true,
          );
        }
        return;
      }
      final address = await GeocodingService.instance.reverseGeocode(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      if (!mounted) return;
      setState(() => _address = address);
      widget.onChanged(
        LocationPickResult(
          latitude: loc.latitude,
          longitude: loc.longitude,
          address: address,
        ),
      );
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      final message = switch (failure.reason) {
        LocationFailureReason.permissionDenied =>
          'Location permission was denied. Try "Pick on map" instead.',
        LocationFailureReason.serviceDisabled =>
          'Turn on location services, or use "Pick on map" instead.',
        LocationFailureReason.other =>
          "Couldn't get your location. Try \"Pick on map\" instead.",
      };
      showMessage(context, message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openPicker() async {
    final initial = _hasPoint
        ? LatLng(widget.latitude!, widget.longitude!)
        : null;
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: initial)),
    );
    if (result != null && mounted) {
      setState(() => _address = result.address);
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!_hasPoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.enabled ? _openPicker : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: scheme.outline),
                color: scheme.inverseSurface.withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set the exact location',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Search an address or drop a pin — no coordinates needed.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.enabled && !_locating
                ? _quickUseCurrentLocation
                : null,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              _locating ? 'Getting your location…' : 'Use my current location',
            ),
          ),
        ],
      );
    }

    final point = LatLng(widget.latitude!, widget.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        children: [
          // A styled placeholder, not a live FlutterMap instance — this
          // preview never pans or zooms, so spinning up the full map engine
          // plus a network tile fetch just to show a static thumbnail would
          // burn real frame time for nothing. Tapping it opens the actual
          // interactive picker, which is where a live map earns its cost.
          const SizedBox(height: 140, child: _StaticMapPreview()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          // Positioned.fill gives this bounded height (matching the 140px
          // preview above) — without it, a bare Stack child that contains a
          // flex widget like Spacer gets unbounded height from the Stack
          // and crashes layout the instant a point is picked. It doesn't
          // need Spacer anyway: bounded height + MainAxisAlignment.end
          // already pins the text to the bottom on its own.
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.enabled ? _openPicker : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _address ?? 'Pinned location',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: LiquidGlass(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                onTap: widget.enabled ? _openPicker : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_location_alt_outlined, size: 15),
                    const SizedBox(width: 5),
                    Text('Change', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ),
          if (widget.enabled)
            Positioned(
              top: 8,
              left: 8,
              child: LiquidGlass(
                padding: const EdgeInsets.all(4),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: widget.onCleared,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A decorative, non-map "you picked a spot" backdrop — a faint dot grid
/// plus a large pin, painted once and never repainted (no animation, no
/// dependency on the map's own state). Exists purely so the compact card
/// doesn't need a live FlutterMap engine to communicate "this is a place on
/// a map" at a glance.
class _StaticMapPreview extends StatelessWidget {
  const _StaticMapPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.info.withValues(alpha: 0.16),
                AppColors.surfaceElevated,
              ],
            ),
          ),
          child: const RepaintBoundary(
            child: CustomPaint(painter: _DotGridPainter(), size: Size.infinite),
          ),
        ),
        const Center(
          child: Icon(
            Icons.location_on,
            size: 40,
            color: AppColors.danger,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  static const _spacing = 22.0;
  static const _radius = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink.withValues(alpha: 0.10);
    for (double y = _spacing / 2; y < size.height; y += _spacing) {
      for (double x = _spacing / 2; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  // Static pattern — the size this paints into never changes after layout,
  // so there is nothing to react to on rebuild.
  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
