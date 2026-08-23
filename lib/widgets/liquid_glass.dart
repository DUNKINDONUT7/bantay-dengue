import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted "liquid glass" surface reserved for floating chrome — content
/// that hovers over other content rather than sitting docked in the page
/// flow: map controls, a floating nav bar, an anchored notifications
/// dropdown, a filter chip row. Everything else in the app (page cards,
/// sidebars, docked panels) stays flat per the editorial design language.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xl)),
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates the blur into its own compositor layer.
    // BackdropFilter is the single most expensive thing this app draws
    // (Flutter web has no Impeller acceleration, so every blurred pixel is
    // a real per-frame cost) — without this boundary, anything that makes a
    // sibling widget repaint (a text cursor blinking, a hovered nav item, a
    // page transition) forces Flutter to redo the blur too, even though the
    // blur itself never changed. Wrapping it here means it paints once and
    // is reused as a texture until this widget's own contents change.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.62),
                  AppColors.background.withValues(alpha: 0.42),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A round, tappable liquid-glass control — used for icon-only floating
/// buttons like map "locate me" / "fullscreen".
class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ink,
                ),
              )
            : Icon(icon, color: AppColors.ink),
      ),
    );
  }
}
