import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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

/// Écran de démarrage : logo, dégradé, indicateur discret.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.aurora),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nightlight_round, size: 64, color: Colors.white),
              SizedBox(height: 18),
              Text(
                'Planning CHI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
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
