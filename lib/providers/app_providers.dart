import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/database_service.dart';

// Database Service Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Database Initialization Provider
final databaseInitializedProvider = FutureProvider<bool>((ref) async {
  final db = ref.read(databaseServiceProvider);
  await db.initialize();
  return db.isInitialized;
});

// Team Members Providers
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getAllTeamMembers();
});

final teamMemberProvider = FutureProvider.family<TeamMember?, String>((ref, id) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getTeamMemberById(id);
});

// Night Shifts Providers
final allNightShiftsProvider = FutureProvider<List<NightShift>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getAllNightShifts();
});

final nightShiftsForAgentProvider = FutureProvider.family<List<NightShift>, String>((ref, agentId) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getNightShiftsForAgent(agentId);
});

final nightShiftsForMonthProvider = FutureProvider.family<List<NightShift>, ({int year, int month})>((ref, params) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getNightShiftsForMonth(params.year, params.month);
});

final nightShiftForDateProvider = FutureProvider.family<NightShift?, ({String agentId, DateTime date})>((ref, params) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getNightShift(params.agentId, params.date);
});

// User Config Provider
final userConfigProvider = FutureProvider<UserConfig?>((ref) async {
  final db = ref.read(databaseServiceProvider);
  await ref.read(databaseInitializedProvider.future);
  return db.getUserConfig();
});

// Mode d'affichage choisi par l'utilisateur dans les paramètres.
// `null` = suit le réglage enregistré (UserConfig.darkModeEnabled).
final themeModeProvider = StateProvider<ThemeMode?>((ref) => null);

// Onglet actif de la barre de navigation (0 = Accueil, 1 = Calendrier, ...)
// Permet aux écrans de renvoyer l'utilisateur vers l'import sans callback.
final selectedTabProvider = StateProvider<int>((ref) => 0);