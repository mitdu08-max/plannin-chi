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

// Current User Provider (for the logged-in user)
final currentUserProvider = StateProvider<TeamMember?>((ref) => null);

// Selected Month Provider (for calendar/stats navigation)
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Notification Settings Provider
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);