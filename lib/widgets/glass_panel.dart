import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight bordered surface retained under the old API name for screen
/// compatibility. It intentionally avoids BackdropFilter blur and large glow
/// layers, which are expensive on mobile GPUs and Flutter Web.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color glowColor;
  final bool glow;
  final VoidCallback? onTap;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.lg,
    this.glowColor = AppColors.primary,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceCard : AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark ? AppColors.border : AppColors.borderLight,
        ),
        boxShadow: glow ? AppGlow.soft(glowColor) : null,
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: panel,
      ),
    );
  }
}
