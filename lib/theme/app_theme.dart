import 'package:flutter/material.dart';

/// Monochrome, Shadcn-inspired design tokens adapted for Flutter.
///
/// Shadcn itself is a React/Tailwind component library, so it cannot be used
/// directly in Flutter. These tokens reproduce its restrained surfaces,
/// borders, typography, control heights, focus states, and semantic colors.
class AppColors {
  // Dark surfaces (default).
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF0C0C0F);
  static const Color surfaceElevated = Color(0xFF18181B);
  static const Color surfaceCard = Color(0xFF101013);
  static const Color border = Color(0xFF29292E);

  // Light surfaces.
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLightBase = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF4F4F5);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE4E4E7);

  // Monochrome brand/control scale.
  static const Color primary = Color(0xFFFAFAFA);
  static const Color onPrimary = Color(0xFF09090B);
  static const Color primaryDark = Color(0xFFD4D4D8);
  static const Color primaryLight = Color(0xFFFFFFFF);
  static const Color primaryGlow = Color(0x1FFFFFFF);
  static const Color secondary = Color(0xFFA1A1AA);
  static const Color secondaryDark = Color(0xFF71717A);
  static const Color secondaryLight = Color(0xFFD4D4D8);
  static const Color secondaryGlow = Color(0x14FFFFFF);

  // Semantic colors are intentionally reserved for status/safety feedback.
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color info = Color(0xFF60A5FA);

  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);
  static const Color textPrimaryLight = Color(0xFF09090B);
  static const Color textSecondaryLight = Color(0xFF52525B);
  static const Color textMutedLight = Color(0xFF71717A);

  // Existing stat/risk API retained; cards remain monochrome while semantic
  // state still has a small, accessible signal color.
  static const Color statRed = danger;
  static const Color statOrange = warning;
  static const Color statBlue = info;
  static const Color statGreen = success;
  static const Color riskHigh = danger;
  static const Color riskMedium = warning;
  static const Color riskLow = success;

  static const Color glassFill = Color(0x0FFFFFFF);
  static const Color glassBorder = border;
}

class AppGradients {
  static const LinearGradient heroAlert = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF18181B), Color(0xFF101013)],
  );

  static const LinearGradient brandSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFB4B4BB)],
  );

  static LinearGradient cardSheen(Color base) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base.withValues(alpha: 0.10), base.withValues(alpha: 0.025)],
  );

  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x12FFFFFF), Color(0x05FFFFFF)],
  );
}

class AppGlow {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> strong(Color color) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
  static const double maxContentWidth = 1120;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double pill = 999;
}

class AppTypography {
  static TextStyle display(BuildContext context, {Color? color}) => TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.12,
    color: color ?? _onSurface(context),
  );

  static TextStyle heading(BuildContext context, {Color? color}) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
    height: 1.2,
    color: color ?? _onSurface(context),
  );

  static TextStyle subheading(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: color ?? _onSurface(context),
      );

  static TextStyle statNumber(
    BuildContext context, {
    Color? color,
    double size = 26,
  }) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? _onSurface(context),
    height: 1,
  );

  static TextStyle eyebrow(BuildContext context, {Color? color}) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: color ?? AppColors.textMuted,
  );

  static Color _onSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.textPrimary
      : AppColors.textPrimaryLight;
}

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceCard : AppColors.surfaceLightBase;
    final raised = isDark
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final foreground = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final muted = isDark
        ? AppColors.textSecondary
        : AppColors.textSecondaryLight;
    final controlBackground = isDark
        ? AppColors.primary
        : const Color(0xFF18181B);
    final onControl = isDark ? AppColors.background : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: controlBackground,
      onPrimary: onControl,
      secondary: isDark ? AppColors.secondary : const Color(0xFF52525B),
      onSecondary: isDark ? AppColors.background : Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: foreground,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: foreground,
      onInverseSurface: bg,
      inversePrimary: isDark ? const Color(0xFF18181B) : Colors.white,
      surfaceTint: Colors.transparent,
    );

    final baseText = Typography.material2021().white.apply(
      bodyColor: foreground,
      displayColor: foreground,
      fontFamily: 'Inter',
    );
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(color: foreground, height: 1.5),
      bodyMedium: baseText.bodyMedium?.copyWith(color: muted, height: 1.45),
      bodySmall: baseText.bodySmall?.copyWith(color: muted, height: 1.4),
      labelLarge: baseText.labelLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseText.labelMedium?.copyWith(color: muted),
      labelSmall: baseText.labelSmall?.copyWith(color: muted),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: 48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: foreground, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: controlBackground,
          foregroundColor: onControl,
          disabledBackgroundColor: raised,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: controlBackground,
          foregroundColor: onControl,
          disabledBackgroundColor: raised,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          side: BorderSide(color: border),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: muted,
          minimumSize: const Size(44, 44),
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: controlBackground,
        foregroundColor: onControl,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: isDark
            ? const Color(0xFF27272A)
            : const Color(0xFFE4E4E7),
        disabledColor: raised,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: foreground, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: foreground, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: foreground,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: foreground),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
        indicatorColor: raised,
        indicatorShape: controlShape,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: foreground,
        minTileHeight: 48,
        shape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFFFAFAFA)
            : const Color(0xFF18181B),
        contentTextStyle: TextStyle(color: onControl),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: foreground,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: foreground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: TextStyle(color: bg, fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onControl : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? controlBackground
              : raised,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? controlBackground
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onControl),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      iconTheme: IconThemeData(color: muted),
    );
  }
}
