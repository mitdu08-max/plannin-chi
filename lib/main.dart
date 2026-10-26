import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale française pour DateFormat
  await initializeDateFormatting('fr_FR', null);

  // Base de fuseaux horaires (rappels)
  tz.initializeTimeZones();

  // Hive est initialisé (et les adapters enregistrés) par DatabaseService,
  // via databaseInitializedProvider : plus de double initialisation ici.

  runApp(const ProviderScope(child: NightShiftApp()));
}

class NightShiftApp extends ConsumerWidget {
  const NightShiftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbInitialized = ref.watch(databaseInitializedProvider);
    final themeOverride = ref.watch(themeModeProvider);
    final config = ref.watch(userConfigProvider).valueOrNull;

    // Nuit par défaut (métier de nuit), sauf choix explicite de l'utilisateur.
    final themeMode = themeOverride ??
        (config == null
            ? ThemeMode.dark
            : (config.darkModeEnabled ? ThemeMode.dark : ThemeMode.light));

    return MaterialApp(
      title: 'Planning CHI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: dbInitialized.when(
        loading: () => const _SplashScreen(),
        error: (error, stack) => _ErrorScreen(error: error),
        data: (_) => const HomeScreen(),
      ),
    );
  }
}

/// Écran de démarrage : allumage du moniteur — noir, grille, logo néon.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.neonCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.neonCyan),
                  boxShadow: AppColors.glow(AppColors.neonCyan, blur: 30, alpha: 0.35),
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  size: 38,
                  color: AppColors.neonLime,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'PLANNING CHI',
                style: AppFonts.tag(
                  size: 13,
                  color: AppColors.nightText,
                  weight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'INITIALISATION…',
                style: AppFonts.tag(
                  size: 9,
                  color: AppColors.neonDim,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 26),
              const SizedBox(
                width: 132,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.neonLime,
                  backgroundColor: AppColors.neonLine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: AppSpacing.md),
              Text('Démarrage impossible', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
