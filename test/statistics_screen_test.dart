import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/models/models.dart';
import 'package:night_shift_planning/providers/providers.dart';
import 'package:night_shift_planning/screens/statistics_screen.dart';
import 'package:night_shift_planning/theme/app_theme.dart';

void main() {
  testWidgets(
      'Bilan Équipe affiche chaque membre avec nuits, week-ends, heures et détail',
      (tester) async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Trouver le premier samedi du mois courant pour tester les week-ends
    var firstSat = 1;
    while (DateTime(year, month, firstSat).weekday != DateTime.saturday) {
      firstSat++;
    }

    final config = UserConfig(
      userId: 'ARRAGAIN',
      userName: 'ARRAGAIN',
      userTrigramme: 'ARRAGAIN',
      shiftDurationHours: 12,
    );

    final members = [
      TeamMember(
        id: 'ARRAGAIN',
        firstName: 'ARRAGAIN',
        lastName: '',
        trigramme: 'ARRAGAIN',
      ),
      TeamMember(
        id: 'LEROY',
        firstName: 'LEROY',
        lastName: '',
        trigramme: 'LEROY',
      ),
    ];

    NightShift makeShift(String agent, int day) => NightShift(
          id: '${agent}_${year}_${month}_$day',
          date: DateTime(year, month, day),
          agentId: agent,
          agentTrigramme: agent,
          startTime: const TimeOfDay(hour: 19, minute: 0),
          endTime: const TimeOfDay(hour: 7, minute: 0),
          isWorking: true,
        );

    final shifts = [
      // ARRAGAIN: 2 nuits (24h), 1 WE complet
      makeShift('ARRAGAIN', firstSat),
      makeShift('ARRAGAIN', firstSat + 1),
      // LEROY: 3 nuits (36h), 0 WE
      makeShift('LEROY', firstSat + 2),
      makeShift('LEROY', firstSat + 3),
      makeShift('LEROY', firstSat + 4),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allNightShiftsProvider.overrideWith((ref) async => shifts),
          userConfigProvider.overrideWith((ref) async => config),
          teamMembersProvider.overrideWith((ref) async => members),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Basculer sur Bilan Équipe
    expect(find.text('Bilan Équipe'), findsOneWidget);
    await tester.tap(find.text('Bilan Équipe'));
    await tester.pumpAndSettle();

    // Vérifier la présence des deux membres et de leurs totaux
    expect(find.text('LEROY'), findsOneWidget);
    expect(find.text('ARRAGAIN'), findsOneWidget);
    expect(find.text('MOI'), findsOneWidget);
    expect(find.text('36h'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);
    expect(find.text('60h'), findsOneWidget); // Total heures équipe

    // Toucher ARRAGAIN pour ouvrir la fiche détail
    await tester.ensureVisible(find.text('ARRAGAIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ARRAGAIN'));
    await tester.pumpAndSettle();

    expect(find.text('RÉPARTITION PAR JOUR'), findsOneWidget);
    expect(find.text('COMPLETS'), findsOneWidget);
    expect(find.text('DEMI WE'), findsOneWidget);
    expect(find.text('REPOS WE'), findsOneWidget);
  });
}
