import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const List<Widget> _screens = [
    DashboardScreen(),
    CalendarScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Calendrier',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Stats',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Réglages',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final userConfigAsync = ref.watch(userConfigProvider);
    final index = ref.watch(selectedTabProvider);

    return userConfigAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 56, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text('Erreur : $error', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userConfigProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (userConfig) {
        // Premier lancement : configuration obligatoire avant tout.
        if (userConfig == null) {
          return const ImportScreen(isFirstLaunch: true);
        }

        final safeIndex = index.clamp(0, _screens.length - 1);

        return Scaffold(
          extendBody: true,
          body: IndexedStack(index: safeIndex, children: _screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            child: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (value) =>
                  ref.read(selectedTabProvider.notifier).state = value,
              destinations: _destinations,
            ),
          ),
        );
      },
    );
  }
}
