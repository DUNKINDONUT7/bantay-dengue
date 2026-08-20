import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium editorial design tokens: warm cream surfaces, deep-black ink for
/// contrast and CTAs, and a single theme (no dark mode) — matching the
/// product's chosen visual direction.
class AppColors {
  // Warm cream surfaces.
  static const Color background = Color(0xFFF6F1E6);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceElevated = Color(0xFFEFE8D8);
  static const Color surfaceCard = Color(0xFFFFFDF8);
  static const Color border = Color(0xFFE2D9C4);
  static const Color borderStrong = Color(0xFFCFC2A4);

  // Ink — the "deep black" pole of the palette, used for headlines, primary
  // CTAs, and active states. Warm-tinted rather than pure black so it sits
  // naturally against the cream.
  static const Color ink = Color(0xFF16140F);
  static const Color primary = ink;
  static const Color onPrimary = background;
  static const Color primaryDark = Color(0xFF322D22);
  static const Color primaryLight = Color(0xFF3A362A);
  static const Color primaryGlow = Color(0x1416140F);
  static const Color secondary = Color(0xFF6B6355);
  static const Color secondaryDark = Color(0xFF4A4438);
  static const Color secondaryLight = Color(0xFF99917E);
  static const Color secondaryGlow = Color(0x0D16140F);

  // Semantic colors, warm-tuned to sit inside the editorial palette instead
  // of stock Material red/amber/green.
  static const Color danger = Color(0xFFB3401E);
  static const Color warning = Color(0xFFA8791F);
  static const Color success = Color(0xFF4C6B3F);
  static const Color info = Color(0xFF3E5C6B);

  static const Color statRed = danger;
  static const Color statOrange = warning;
  static const Color statBlue = info;
  static const Color statGreen = success;
  static const Color riskHigh = danger;
  static const Color riskMedium = warning;
  static const Color riskLow = success;

  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF6B6355);
  static const Color textMuted = Color(0xFF99917E);

  static const Color glassFill = Color(0x59FFFFFF);
  static const Color glassBorder = Color(0x8CFFFFFF);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  // On very wide monitors the web shell's remaining width (after the 240px
  // sidebar) is often 1500-1700px, so a tighter cap left dead space on both
  // sides. 1440 uses far more of a normal desktop window before it kicks in.
  static const double maxContentWidth = 1440;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

class AppGlow {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> strong(Color color) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Ad-hoc text styles used directly by a handful of widgets that need a
/// style outside the standard Material [TextTheme] slots. Display/heading
/// route through Fraunces (the editorial serif); everything else stays on
/// Inter for legibility at small sizes.
class AppTypography {
  static TextStyle display(BuildContext context, {Color? color}) =>
      GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.08,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle heading(BuildContext context, {Color? color}) =>
      GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.15,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle subheading(BuildContext context, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle statNumber(
    BuildContext context, {
    Color? color,
    double size = 28,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? AppColors.textPrimary,
    height: 1,
  );

  static TextStyle eyebrow(BuildContext context, {Color? color}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color ?? AppColors.textMuted,
      );
}

class AppTheme {
  static ThemeData get theme => _build();
  // Retained so any lingering reference resolves to the same single theme.
  static ThemeData get lightTheme => _build();
  static ThemeData get darkTheme => _build();

  static ThemeData _build() {
    const bg = AppColors.background;
    const surface = AppColors.surfaceCard;
    const raised = AppColors.surfaceElevated;
    const border = AppColors.border;
    const foreground = AppColors.textPrimary;
    const muted = AppColors.textSecondary;
    const controlBackground = AppColors.ink;
    const onControl = AppColors.onPrimary;

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: controlBackground,
      onPrimary: onControl,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
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
      inversePrimary: AppColors.surfaceElevated,
      surfaceTint: Colors.transparent,
    );

    final baseText = GoogleFonts.interTextTheme().apply(
      bodyColor: foreground,
      displayColor: foreground,
    );
    final frauncesDisplay = GoogleFonts.fraunces(
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    final textTheme = baseText.copyWith(
      displayLarge: frauncesDisplay.copyWith(
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        height: 1.02,
      ),
      displayMedium: frauncesDisplay.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        height: 1.04,
      ),
      displaySmall: frauncesDisplay.copyWith(
        fontSize: 36,
        letterSpacing: -0.8,
        height: 1.06,
      ),
      headlineLarge: frauncesDisplay.copyWith(
        fontSize: 32,
        letterSpacing: -0.6,
        height: 1.1,
      ),
      headlineMedium: frauncesDisplay.copyWith(
        fontSize: 28,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      headlineSmall: frauncesDisplay.copyWith(
        fontSize: 26,
        letterSpacing: -0.4,
        height: 1.14,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
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
      brightness: Brightness.light,
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
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: 48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: foreground, width: 1.4),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: controlBackground,
          foregroundColor: onControl,
          disabledBackgroundColor: raised,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          side: const BorderSide(color: border),
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
        selectedColor: AppColors.surfaceElevated,
        disabledColor: raised,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: foreground, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: foreground, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: foreground,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: const IconThemeData(color: foreground),
        unselectedIconTheme: const IconThemeData(color: muted),
        selectedLabelTextStyle: const TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: muted),
        indicatorColor: raised,
        indicatorShape: controlShape,
      ),
      drawerTheme: const DrawerThemeData(
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
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: controlBackground,
        contentTextStyle: const TextStyle(color: onControl),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: foreground,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: foreground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: bg, fontSize: 12),
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
        checkColor: const WidgetStatePropertyAll(onControl),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      iconTheme: const IconThemeData(color: muted),
    );
  }
}
