import 'package:flutter/material.dart';

/// Palette et styles de l'application — identité « Nocturne néon ».
///
/// Noir absolu, grille technique, accents cyan / lime, angles vifs et chiffres
/// en monospace : l'application doit ressembler à un moniteur de nuit allumé
/// dans une salle de repos éteinte.
///
/// Tous les écrans lisent ces jetons (aucune couleur codée en dur) : il suffit
/// de changer les valeurs ci-dessous pour faire basculer l'identité entière.
class AppColors {
  const AppColors._();

  // ------------------------------------------------------------- mode nuit
  static const Color nightBackground = Color(0xFF04060B);
  static const Color nightSurface = Color(0xFF080C13);
  static const Color nightSurfaceHigh = Color(0xFF0C121B);
  static const Color nightOutline = Color(0xFF16232E);
  static const Color nightText = Color(0xFFE6FCFF);
  static const Color nightTextMuted = Color(0xFF5E7C8C);

  static const Color nightPrimary = Color(0xFF00E5FF);
  static const Color nightSecondary = Color(0xFFB6FF3B);
  static const Color nightTertiary = Color(0xFFFFC857);

  // -------------------------------------------------------------- mode jour
  /// Volontairement le même langage, mais sur papier glacé : encre froide,
  /// traits fins, accents assombris pour rester lisibles au soleil.
  static const Color dayBackground = Color(0xFFEDF2F5);
  static const Color daySurface = Color(0xFFFFFFFF);
  static const Color daySurfaceHigh = Color(0xFFF4F8FA);
  static const Color dayOutline = Color(0xFFCBD9E0);
  static const Color dayText = Color(0xFF06121A);
  static const Color dayTextMuted = Color(0xFF5A7280);

  static const Color dayPrimary = Color(0xFF007A8C);
  static const Color daySecondary = Color(0xFF4F7A00);
  static const Color dayTertiary = Color(0xFFB26A00);

  // ------------------------------------------------------ accents bruts néon
  /// Cyan du moniteur : couleur de la garde et des traits actifs.
  static const Color neonCyan = Color(0xFF00E5FF);

  /// Lime des lectures de nuit : heures, chiffres, navigation active.
  static const Color neonLime = Color(0xFFB6FF3B);

  static const Color neonAmber = Color(0xFFFFC857);
  static const Color neonInk = Color(0xFF04060B);
  static const Color neonDeep = Color(0xFF080C13);
  static const Color neonLine = Color(0xFF16232E);
  static const Color neonDim = Color(0xFF5E7C8C);
  static const Color neonMid = Color(0xFF9FE8F5);

  // ---------------------------------------------------- couleurs sémantiques
  /// Garde de nuit : cyan → teal profond (assez sombre pour du texte blanc).
  static const Color shiftStart = Color(0xFF0089A6);
  static const Color shiftEnd = Color(0xFF00E5FF);

  /// Congés : lime → olive profond.
  static const Color vacationStart = Color(0xFF9BD62B);
  static const Color vacationEnd = Color(0xFFB6FF3B);

  /// Repos.
  static const Color restStart = Color(0xFF3C4E5A);
  static const Color restEnd = Color(0xFF25323B);

  static const Color danger = Color(0xFFFF5470);
  static const Color warning = Color(0xFFFFC857);
  static const Color success = Color(0xFFB6FF3B);

  /// Dégradé signature : cyan → lime. À réserver aux accents et aux boutons
  /// (texte encre obligatoire dessus).
  static const LinearGradient neon = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [neonCyan, neonLime],
    stops: [0.0, 1.0],
  );

  /// Ancien nom conservé : c'est le même dégradé signature.
  static const LinearGradient aurora = neon;

  /// Dégradé sombre pour les aplats qui portent du texte blanc.
  static const LinearGradient neonDeepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00707F), Color(0xFF013A47)],
  );

  static const LinearGradient shiftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [shiftStart, Color(0xFF013A47)],
  );

  static const LinearGradient vacationGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C6B00), Color(0xFF223300)],
  );

  /// Halo de la couleur demandée, pour les traits lumineux.
  static List<BoxShadow> glow(
    Color color, {
    double blur = 18,
    double alpha = 0.45,
    Offset offset = Offset.zero,
  }) =>
      [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: blur,
          spreadRadius: 0,
          offset: offset,
        ),
      ];

  /// Couleur d'un jour selon son statut.
  static Color forStatus({bool working = false, bool vacation = false}) {
    if (working) return shiftEnd;
    if (vacation) return vacationStart;
    return restStart;
  }
}

/// Typographie : sans-serif neutre pour lire, monospace pour mesurer.
class AppFonts {
  const AppFonts._();

  static const String mono = 'monospace';
  static const List<String> monoFallback = <String>[
    'Roboto Mono',
    'JetBrains Mono',
    'SF Mono',
    'Menlo',
    'Courier New',
    'Courier',
  ];

  /// Chiffres / libellés techniques.
  static TextStyle monoText({
    double size = 12,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0.6,
    double? height,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontFamilyFallback: monoFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Étiquette technique majuscule, très espacée.
  static TextStyle tag({
    double size = 10,
    Color? color,
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 1.4,
  }) =>
      monoText(
        size: size,
        weight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

/// Rayons : angles vifs, presque machinés. Rien au-dessus de 12.
class AppRadius {
  const AppRadius._();
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double pill = 3;
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
      onPrimary: AppColors.neonInk,
      primaryContainer: primary.withValues(alpha: isDark ? 0.16 : 0.12),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: AppColors.neonInk,
      secondaryContainer: secondary.withValues(alpha: isDark ? 0.16 : 0.14),
      onSecondaryContainer: isDark ? secondary : const Color(0xFF35530A),
      tertiary: tertiary,
      onTertiary: AppColors.neonInk,
      tertiaryContainer: tertiary.withValues(alpha: isDark ? 0.16 : 0.12),
      onTertiaryContainer: tertiary,
      error: AppColors.danger,
      onError: AppColors.neonInk,
      errorContainer: AppColors.danger.withValues(alpha: 0.16),
      onErrorContainer: AppColors.danger,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.55),
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
      textTheme: _textTheme(text, muted, primary),
      primaryTextTheme: _textTheme(text, muted, primary),

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
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
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
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppFonts.monoText(size: 13, weight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppFonts.monoText(size: 12.5, weight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppFonts.monoText(size: 12.5, weight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: AppColors.neonInk,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ------------------------------------------------------------ navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppFonts.tag(
            size: 9.5,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
            color: selected ? secondary : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 21,
            color: selected ? secondary : muted,
          );
        }),
      ),

      // ------------------------------------------------------------ formulaire
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: AppFonts.monoText(size: 11.5, color: muted, letterSpacing: 0.8),
        floatingLabelStyle: AppFonts.monoText(size: 11.5, color: primary, letterSpacing: 0.8),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.75), fontSize: 14),
        prefixIconColor: muted,
        suffixIconColor: muted,
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
          borderSide: BorderSide(color: primary, width: 1.4),
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

      // ---------------------------------------------------------------- divers
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: primary.withValues(alpha: isDark ? 0.18 : 0.14),
        side: BorderSide(color: outline),
        labelStyle: AppFonts.monoText(size: 11, color: text, letterSpacing: 0.8),
        secondaryLabelStyle:
            AppFonts.monoText(size: 11, color: primary, letterSpacing: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: primary.withValues(alpha: 0.35)),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        contentTextStyle: TextStyle(color: text.withValues(alpha: 0.88), fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF101A22) : const Color(0xFF11202A),
        contentTextStyle: const TextStyle(color: Color(0xFFE6FCFF), fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: primary.withValues(alpha: 0.4)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: secondary,
        linearTrackColor: outline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.neonInk : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? secondary : outline,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? secondary : outline,
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
          color: const Color(0xFF101A22),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: outline),
        ),
        textStyle: AppFonts.monoText(size: 11, color: const Color(0xFFE6FCFF), letterSpacing: 0.6),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: secondary,
        inactiveTrackColor: outline,
        thumbColor: secondary,
        overlayColor: secondary.withValues(alpha: 0.14),
      ),
    );
  }

  static TextTheme _textTheme(Color text, Color muted, Color accent) {
    return TextTheme(
      // Titres : sans-serif serré, capitales pleines d'assurance.
      displayLarge: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.08),
      displayMedium: TextStyle(color: text, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.12),
      displaySmall: TextStyle(color: text, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineLarge: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineMedium: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      headlineSmall: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.1),
      titleLarge: TextStyle(color: text, fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      titleMedium: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      // Petites capitales techniques.
      titleSmall: AppFonts.tag(size: 10, color: muted, letterSpacing: 1.5),
      bodyLarge: TextStyle(color: text, fontSize: 14.5, height: 1.45),
      bodyMedium: TextStyle(color: text, fontSize: 13.5, height: 1.45),
      bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
      labelLarge: AppFonts.monoText(size: 12, color: text, letterSpacing: 0.8),
      labelMedium: AppFonts.tag(size: 10, color: muted, letterSpacing: 1.2),
      labelSmall: AppFonts.tag(size: 9, color: muted, letterSpacing: 1.2),
    );
  }
}
