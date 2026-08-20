import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat cream backdrop shared by every role shell.
class FuturisticBackdrop extends StatelessWidget {
  final Widget child;

  const FuturisticBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}
