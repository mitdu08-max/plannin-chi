import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'import_screen.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static final List<Widget> _screens = [
    const ImportScreen(),
    const CalendarScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.upload_file_outlined),
      selectedIcon: Icon(Icons.upload_file),
      label: 'Import',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Calendrier',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Statistiques',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Paramètres',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final userConfigAsync = ref.watch(userConfigProvider);
    final selectedIndex = ref.watch(selectedTabProvider);

    return userConfigAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userConfigProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
      data: (userConfig) {
        final isFirstLaunch = userConfig == null;

        if (isFirstLaunch) {
          return const ImportScreen(isFirstLaunch: true);
        }

        return Scaffold(
          body: _screens[selectedIndex.clamp(0, _screens.length - 1)],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex.clamp(0, _screens.length - 1),
            onDestinationSelected: (index) {
              ref.read(selectedTabProvider.notifier).state = index;
            },
            destinations: _destinations,
          ),
        );
      },
    );
  }
}