// lib/services/theme_controller.dart
import 'package:flutter/material.dart';

/// App-wide light/dark mode switch. A simple ValueNotifier is enough here —
/// MaterialApp.router rebuilds via ValueListenableBuilder in main.dart.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void setMode(ThemeMode mode) {
    value = mode;
  }
}

final ThemeController themeController = ThemeController();
