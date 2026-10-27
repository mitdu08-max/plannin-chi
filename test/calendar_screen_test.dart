import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:night_shift_planning/models/models.dart';
import 'package:night_shift_planning/providers/providers.dart';
import 'package:night_shift_planning/screens/calendar_screen.dart';
import 'package:night_shift_planning/services/database_service.dart';
import 'package:night_shift_planning/theme/app_theme.dart';

class _FakeDatabase implements DatabaseService {
  _FakeDatabase() {
    config = UserConfig(
      userId: 'current-id',
      userName: 'Alice',
      userTrigramme: 'ALICE',
      notificationsEnabled: false,
    );
    members = [
      TeamMember(
        id: 'current-id',
        firstName: 'Alice',
        lastName: '',
        trigramme: 'ALICE',
      ),
      TeamMember(
        id: 'other-id',
        firstName: 'Bert',
        lastName: '',
        trigramme: 'BERT',
      ),
    ];
    shifts = [
      _shift(
        'legacy-shift',
        'legacy-id',
        'ALICE',
        DateTime(2026, 1, 5),
        coworkers: ['other-id'],
      ),
      _shift('other-shift', 'other-id', 'BERT', DateTime(2026, 1, 6)),
      _shift('february-shift', 'current-id', 'ALICE', DateTime(2026, 2, 3)),
      _shift(
        'vacation',
        'current-id',
        'ALICE',
        DateTime(2026, 1, 7),
        vacation: 'CA',
      ),
      _shift(
        'rest',
        'current-id',
        'ALICE',
        DateTime(2026, 1, 8),
        vacation: 'REPOS',
      ),
    ];
  }

  late UserConfig config;
  late List<TeamMember> members;
  late List<NightShift> shifts;

  static NightShift _shift(
    String id,
    String agentId,
    String trigramme,
    DateTime date, {
    List<String> coworkers = const [],
    String? vacation,
  }) => NightShift(
    id: id,
    date: date,
    agentId: agentId,
    agentTrigramme: trigramme,
    startTime: const TimeOfDay(hour: 19, minute: 0),
    endTime: const TimeOfDay(hour: 7, minute: 0),
    isWorking: vacation == null,
    isVacation: vacation != null,
    vacationType: vacation ?? '',
    coWorkerIds: coworkers,
  );

  @override
  UserConfig? getUserConfig() => config;

  @override
  List<TeamMember> getAllTeamMembers() => List.of(members);

  @override
  List<NightShift> getAllNightShifts() => List.of(shifts);

  @override
  Future<void> saveNightShift(NightShift shift) async {
    shifts.removeWhere((existing) => existing.id == shift.id);
    shifts.add(shift);
  }

  @override
  Future<void> deleteNightShift(String id) async {
    shifts.removeWhere((shift) => shift.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  _FakeDatabase db, {
  Size size = const Size(400, 850),
  Brightness brightness = Brightness.dark,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(db),
        allNightShiftsProvider.overrideWith(
          (ref) async => db.getAllNightShifts(),
        ),
        teamMembersProvider.overrideWith((ref) async => db.getAllTeamMembers()),
        userConfigProvider.overrideWith((ref) async => db.getUserConfig()),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        home: CalendarScreen(initialDay: DateTime(2026, 1, 1)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _day(int month, int day) =>
    find.byKey(ValueKey('calendar-day-2026-$month-$day'));

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR', null));

  testWidgets(
    'le calendrier occupe la page et une date ouvre une fiche vitrée',
    (tester) async {
      final db = _FakeDatabase();
      await _pumpCalendar(tester, db);

      final grid = find.byKey(const ValueKey('calendar-grid'));
      expect(tester.getSize(grid).height, greaterThan(500));
      expect(find.byKey(const ValueKey('calendar-day-sheet')), findsNothing);

      await _tapVisible(tester, _day(1, 5));
      final sheet = find.byKey(const ValueKey('calendar-day-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      expect(find.text('Nuit de garde'), findsOneWidget);
      expect(find.text('19:00 — 07:00'), findsOneWidget);
      expect(find.text('Bert'), findsOneWidget);

      await _tapVisible(tester, find.byTooltip('Fermer le détail'));
      expect(sheet, findsNothing);
      // Une seconde pression sur le même jour doit rouvrir la fiche.
      await _tapVisible(tester, _day(1, 5));
      expect(sheet, findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('calendar-sheet-handle')),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    },
  );

  testWidgets('les congés, repos et jours sans entrée gardent leur sens', (
    tester,
  ) async {
    await _pumpCalendar(tester, _FakeDatabase());

    await _tapVisible(tester, _day(1, 7));
    expect(find.text('Congés · CA'), findsOneWidget);
    expect(find.text('Congés annuels (CA)'), findsOneWidget);
    await _tapVisible(tester, find.byTooltip('Fermer le détail'));

    await _tapVisible(tester, _day(1, 8));
    expect(find.text('Repos'), findsWidgets);
    expect(find.text('Congés · REPOS'), findsNothing);
    await _tapVisible(tester, find.byTooltip('Fermer le détail'));

    await _tapVisible(tester, _day(1, 6));
    expect(
      find.text('Aucune garde ou absence n’est enregistrée pour cette date.'),
      findsOneWidget,
    );
    expect(find.text('Équipe en poste'), findsOneWidget);
    expect(find.text('Bert'), findsOneWidget);
    expect(find.text('Ajouter une garde'), findsOneWidget);
  });

  testWidgets(
    'la fiche se met à jour si les données changent pendant son ouverture',
    (tester) async {
      final db = _FakeDatabase();
      await _pumpCalendar(tester, db);
      await _tapVisible(tester, _day(1, 5));
      expect(find.text('Nuit de garde'), findsOneWidget);

      db.shifts.removeWhere((shift) => shift.id == 'legacy-shift');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarScreen)),
      );
      container.invalidate(allNightShiftsProvider);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('calendar-day-sheet')), findsOneWidget);
      expect(find.text('Nuit de garde'), findsNothing);
      expect(find.text('Ajouter une garde'), findsOneWidget);
    },
  );

  testWidgets('modifier et supprimer préservent les autres dates', (
    tester,
  ) async {
    final db = _FakeDatabase();
    await _pumpCalendar(tester, db);
    await _tapVisible(tester, _day(1, 5));
    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Modifier'));
    await _tapVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Enregistrer'),
    );

    final saved = db.shifts.where((shift) => shift.id == 'legacy-shift').single;
    expect(saved.isManualOverride, isTrue);
    expect(saved.agentId, 'legacy-id');
    expect(
      db.shifts.where((shift) => shift.date == DateTime(2026, 1, 5)).length,
      1,
    );
    expect(db.shifts.any((shift) => shift.id == 'february-shift'), isTrue);
    expect(find.text('Modifié manuellement'), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Supprimer'));
    expect(find.text('Supprimer la garde'), findsOneWidget);
    // Annuler ne touche à aucune donnée.
    await _tapVisible(tester, find.text('Annuler'));
    expect(db.shifts.any((shift) => shift.id == 'legacy-shift'), isTrue);

    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Supprimer'));
    await _tapVisible(tester, find.widgetWithText(ElevatedButton, 'Supprimer'));
    expect(db.shifts.any((shift) => shift.id == 'legacy-shift'), isFalse);
    expect(db.shifts.any((shift) => shift.id == 'february-shift'), isTrue);
    expect(find.text('Ajouter une garde'), findsOneWidget);
  });

  testWidgets(
    'ajouter une garde actualise la fiche sans toucher aux autres dates',
    (tester) async {
      final db = _FakeDatabase();
      await _pumpCalendar(tester, db);
      await _tapVisible(tester, _day(1, 10));
      await _tapVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Ajouter une garde'),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Enregistrer'),
      );

      expect(
        db.shifts.any((shift) => shift.id == 'current-id_2026_1_10'),
        isTrue,
      );
      expect(db.shifts.any((shift) => shift.id == 'february-shift'), isTrue);
      expect(find.text('Nuit de garde'), findsOneWidget);
    },
  );

  testWidgets(
    'les formats mois, deux semaines et semaine restent accessibles',
    (tester) async {
      await _pumpCalendar(tester, _FakeDatabase());
      await _tapVisible(tester, find.text('Mois'));
      expect(find.text('2 sem.'), findsOneWidget);
      await _tapVisible(tester, find.text('2 sem.'));
      expect(find.text('Semaine'), findsOneWidget);
      await _tapVisible(tester, find.text('Semaine'));
      expect(find.text('Mois'), findsOneWidget);
    },
  );

  testWidgets('changement de mois et petits écrans restent utilisables', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      _FakeDatabase(),
      size: const Size(320, 480),
      brightness: Brightness.light,
    );
    await _tapVisible(tester, find.byIcon(Icons.chevron_right_rounded));
    expect(_day(2, 3), findsOneWidget);
    await _tapVisible(tester, _day(2, 3));
    expect(find.text('Nuit de garde'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le calendrier et la fiche restent défilables en paysage', (
    tester,
  ) async {
    await _pumpCalendar(tester, _FakeDatabase(), size: const Size(640, 360));
    // Faire défiler comme un utilisateur : ensureVisible chercherait aussi à
    // déplacer horizontalement le PageView contenant les mois.
    await tester.drag(
      find.byKey(const ValueKey('calendar-page-scroll')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(_day(1, 31), findsOneWidget);
    await tester.tap(_day(1, 31));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-day-sheet')), findsOneWidget);
    await tester.ensureVisible(find.text('Ajouter une garde'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
