import 'package:flutter/material.dart';

/// Palette et styles de l'application — identité « Aurora ».
///
/// Deux thèmes complets (nuit / jour) construits sur les mêmes rôles de
/// couleur, pour que tous les écrans restent cohérents sans couleur codée en
/// dur.
class AppColors {
  const AppColors._();

  // --- Mode nuit (par défaut) ---
  static const Color nightBackground = Color(0xFF070B14);
  static const Color nightSurface = Color(0xFF101827);
  static const Color nightSurfaceHigh = Color(0xFF16213A);
  static const Color nightOutline = Color(0xFF25314B);
  static const Color nightText = Color(0xFFE9EFFB);
  static const Color nightTextMuted = Color(0xFF93A4C3);

  static const Color nightPrimary = Color(0xFF7C8CFF);
  static const Color nightSecondary = Color(0xFF37D9C0);
  static const Color nightTertiary = Color(0xFFFFB454);

  // --- Mode jour ---
  static const Color dayBackground = Color(0xFFF4F6FC);
  static const Color daySurface = Color(0xFFFFFFFF);
  static const Color daySurfaceHigh = Color(0xFFFFFFFF);
  static const Color dayOutline = Color(0xFFE1E7F3);
  static const Color dayText = Color(0xFF111A2C);
  static const Color dayTextMuted = Color(0xFF5E6E8A);

  static const Color dayPrimary = Color(0xFF3D5BE0);
  static const Color daySecondary = Color(0xFF0F9E8A);
  static const Color dayTertiary = Color(0xFFE08A00);

  // --- Couleurs sémantiques (communes) ---
  /// Garde de nuit : indigo → violet.
  static const Color shiftStart = Color(0xFF6C5CFF);
  static const Color shiftEnd = Color(0xFF3E8BFF);

  /// Congés / vacances.
  static const Color vacationStart = Color(0xFF12B886);
  static const Color vacationEnd = Color(0xFF37D9C0);

  /// Repos.
  static const Color restStart = Color(0xFF64748B);
  static const Color restEnd = Color(0xFF475569);

  static const Color danger = Color(0xFFF2555A);
  static const Color warning = Color(0xFFF5A524);
  static const Color success = Color(0xFF2FBF71);

  /// Dégradé signature de l'application.
  static const LinearGradient aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CFF), Color(0xFF3E8BFF), Color(0xFF37D9C0)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient shiftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [shiftStart, shiftEnd],
  );

  static const LinearGradient vacationGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [vacationStart, vacationEnd],
  );

  /// Couleur d'un jour selon son statut.
  static Color forStatus({bool working = false, bool vacation = false}) {
    if (working) return shiftEnd;
    if (vacation) return vacationStart;
    return restStart;
  }
}

/// Rayons, espacements et durées partagés.
class AppRadius {
  const AppRadius._();
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

class AppSpacing {
  const AppSpacing._();
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? AppColors.nightBackground : AppColors.dayBackground;
    final surface = isDark ? AppColors.nightSurface : AppColors.daySurface;
    final surfaceHigh = isDark ? AppColors.nightSurfaceHigh : AppColors.daySurfaceHigh;
    final outline = isDark ? AppColors.nightOutline : AppColors.dayOutline;
    final text = isDark ? AppColors.nightText : AppColors.dayText;
    final muted = isDark ? AppColors.nightTextMuted : AppColors.dayTextMuted;
    final primary = isDark ? AppColors.nightPrimary : AppColors.dayPrimary;
    final secondary = isDark ? AppColors.nightSecondary : AppColors.daySecondary;
    final tertiary = isDark ? AppColors.nightTertiary : AppColors.dayTertiary;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF0A1020) : Colors.white,
      primaryContainer: isDark ? primary.withValues(alpha: 0.18) : primary.withValues(alpha: 0.10),
      onPrimaryContainer: isDark ? primary : primary,
      secondary: secondary,
      onSecondary: isDark ? const Color(0xFF04140F) : Colors.white,
      secondaryContainer: secondary.withValues(alpha: isDark ? 0.18 : 0.12),
      onSecondaryContainer: secondary,
      tertiary: tertiary,
      onTertiary: isDark ? const Color(0xFF231603) : Colors.white,
      tertiaryContainer: tertiary.withValues(alpha: isDark ? 0.18 : 0.12),
      onTertiaryContainer: tertiary,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.danger.withValues(alpha: 0.16),
      onErrorContainer: AppColors.danger,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.6),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: secondary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      // ---------------------------------------------------------------- texte
      textTheme: _textTheme(text, muted),
      primaryTextTheme: _textTheme(text, muted),

      // ---------------------------------------------------------------- barres
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),

      // ---------------------------------------------------------------- cartes
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),

      // ---------------------------------------------------------------- boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: outline, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ------------------------------------------------------------ navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: isDark ? 0.20 : 0.12),
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? primary : muted,
          );
        }),
      ),

      // ------------------------------------------------------------ formulaire
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),

      // ---------------------------------------------------------------- divers
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: primary.withValues(alpha: isDark ? 0.24 : 0.14),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
        secondaryLabelStyle:
            TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: text.withValues(alpha: 0.9), fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.nightSurfaceHigh : const Color(0xFF1B2537),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: outline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colorScheme.onPrimary : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : outline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.nightSurfaceHigh : const Color(0xFF1B2537),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static TextTheme _textTheme(Color text, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(color: text, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.1),
      displayMedium: TextStyle(color: text, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
      displaySmall: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      headlineLarge: TextStyle(color: text, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      bodyLarge: TextStyle(color: text, fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: text, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(color: muted, fontSize: 12.5, height: 1.4),
      labelLarge: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    );
  }
}
