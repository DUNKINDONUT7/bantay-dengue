import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat, minimally-bordered surface — the default card treatment for the
/// editorial design language. No blur, no gradient, no glow by default; a
/// soft shadow is only added when [glow] is explicitly requested (used
/// sparingly for a single emphasized panel, not as a general pattern).
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
    this.glowColor = AppColors.ink,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
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
