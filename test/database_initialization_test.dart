import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:night_shift_planning/models/models.dart';
import 'package:night_shift_planning/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'le démarrage conserve les données sans précharger d’anciens plannings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'planning-db-test-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory')
          return directory.path;
        return null;
      });
      final db = DatabaseService();
      addTearDown(() async {
        if (db.isInitialized) {
          await db.close();
        } else {
          await Hive.close();
        }
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });

      // Simule une base existante contenant la modification d'un seul agent.
      Hive.init(directory.path);
      Hive.registerAdapter(TeamMemberAdapter());
      Hive.registerAdapter(NightShiftAdapter());
      Hive.registerAdapter(UserConfigAdapter());
      Hive.registerAdapter(TimeOfDayAdapter());
      final box = await Hive.openBox<NightShift>('night_shifts');
      final existing = NightShift(
        id: 'ALICE_2026_10_5',
        date: DateTime(2026, 10, 5),
        agentId: 'ALICE',
        agentTrigramme: 'ALICE',
        startTime: const TimeOfDay(hour: 20, minute: 30),
        endTime: const TimeOfDay(hour: 7, minute: 0),
        isWorking: true,
        isManualOverride: true,
      );
      await box.put(existing.id, existing);
      await Hive.close();

      for (var launch = 0; launch < 2; launch++) {
        await db.initialize();
        final stored = db.getAllNightShifts();
        expect(stored, hasLength(1));
        expect(stored.single.id, existing.id);
        expect(stored.single.startTime, existing.startTime);
        expect(stored.single.isManualOverride, isTrue);
        expect(db.getAllTeamMembers(), isEmpty);
        await db.close();
      }
    },
  );
}
