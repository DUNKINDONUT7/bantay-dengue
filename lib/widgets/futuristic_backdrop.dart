import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight monochrome shell backdrop.
///
/// The previous grid/glow painter added layers to every role screen. A flat,
/// high-contrast surface is faster to composite on lower-end phones and keeps
/// the Shadcn-inspired interface intentionally quiet.
class FuturisticBackdrop extends StatelessWidget {
  final Widget child;

  const FuturisticBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? AppColors.background : AppColors.backgroundLight,
      child: child,
    );
  }
}
