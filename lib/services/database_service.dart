import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _teamMembersBoxName = 'team_members';
  static const String _nightShiftsBoxName = 'night_shifts';
  static const String _userConfigBoxName = 'user_config';

  late Box<TeamMember> _teamMembersBox;
  late Box<NightShift> _nightShiftsBox;
  late Box<UserConfig> _userConfigBox;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TeamMemberAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(NightShiftAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserConfigAdapter());
    }
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(TimeOfDayAdapter());
    }

    // Open boxes
    _teamMembersBox = await Hive.openBox<TeamMember>(_teamMembersBoxName);
    _nightShiftsBox = await Hive.openBox<NightShift>(_nightShiftsBoxName);
    _userConfigBox = await Hive.openBox<UserConfig>(_userConfigBoxName);

    // Ne pas précharger silencieusement de planning : les données existantes
    // restent intactes et les nouveaux mois proviennent d'un import confirmé.
    _isInitialized = true;
  }

  // Team Members
  Box<TeamMember> get teamMembersBox => _teamMembersBox;

  List<TeamMember> getAllTeamMembers() {
    return _teamMembersBox.values.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  TeamMember? getTeamMemberById(String id) {
    try {
      return _teamMembersBox.values.firstWhere((member) => member.id == id);
    } catch (_) {
      return null;
    }
  }

  TeamMember? getTeamMemberByTrigramme(String trigramme) {
    try {
      return _teamMembersBox.values.firstWhere((member) => member.trigramme == trigramme);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTeamMember(TeamMember member) async {
    await _teamMembersBox.put(member.id, member);
  }

  /// Enregistre l'équipe détectée **sans vider** la boîte.
  ///
  /// L'ancienne version faisait un `clear()` : un simple ré-import effaçait
  /// les noms/prénoms saisis ou corrigés par l'utilisateur. On fait désormais
  /// un upsert, l'ordre étant conservé par `orderIndex`.
  Future<void> saveAllTeamMembers(List<TeamMember> members) async {
    for (var i = 0; i < members.length; i++) {
      final existing = getTeamMemberById(members[i].id);
      final member = members[i].copyWith(
        orderIndex: members[i].orderIndex == 0 ? i : members[i].orderIndex,
        // on ne perd pas un nom/prénom déjà renseigné
        firstName: members[i].firstName.isEmpty
            ? (existing?.firstName ?? '')
            : members[i].firstName,
      );
      await _teamMembersBox.put(member.id, member);
    }
  }

  Future<void> deleteTeamMember(String id) async {
    await _teamMembersBox.delete(id);
  }

  Future<void> clearTeamMembers() async {
    await _teamMembersBox.clear();
  }

  // Night Shifts
  Box<NightShift> get nightShiftsBox => _nightShiftsBox;

  List<NightShift> getAllNightShifts() {
    return _nightShiftsBox.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<NightShift> getNightShiftsForAgent(String agentId) {
    return _nightShiftsBox.values
        .where((shift) => shift.agentId == agentId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<NightShift> getNightShiftsForDateRange(DateTime start, DateTime end) {
    return _nightShiftsBox.values
        .where((shift) =>
            shift.date.isAfter(start.subtract(const Duration(days: 1))) &&
            shift.date.isBefore(end.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<NightShift> getNightShiftsForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return getNightShiftsForDateRange(start, end);
  }

  NightShift? getNightShift(String agentId, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return _nightShiftsBox.values.firstWhere(
        (shift) =>
            shift.agentId == agentId &&
            shift.date.year == dateOnly.year &&
            shift.date.month == dateOnly.month &&
            shift.date.day == dateOnly.day,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNightShift(NightShift shift) async {
    await _nightShiftsBox.put(shift.id, shift);
  }

  Future<void> saveAllNightShifts(List<NightShift> shifts) async {
    for (final shift in shifts) {
      await _nightShiftsBox.put(shift.id, shift);
    }
  }

  Future<void> deleteNightShift(String id) async {
    await _nightShiftsBox.delete(id);
  }

  Future<void> clearNightShifts() async {
    await _nightShiftsBox.clear();
  }

  /// Supprime toutes les gardes d'un agent pour un mois donné.
  ///
  /// Utilisé avant chaque import : sans cela, une garde retirée du nouveau
  /// planning restait en base et faussait les statistiques.
  Future<int> deleteNightShiftsForMonth(
    String agentId,
    int year,
    int month,
  ) async {
    final keys = _nightShiftsBox.values
        .where((shift) =>
            shift.agentId == agentId &&
            shift.date.year == year &&
            shift.date.month == month)
        .map((shift) => shift.key as String)
        .toList();

    for (final key in keys) {
      await _nightShiftsBox.delete(key);
    }
    return keys.length;
  }

  /// Nombre de gardes enregistrées pour un agent sur un mois.
  int countNightShiftsForMonth(String agentId, int year, int month) {
    return _nightShiftsBox.values
        .where((shift) =>
            shift.agentId == agentId &&
            shift.date.year == year &&
            shift.date.month == month)
        .length;
  }

  // User Config
  Box<UserConfig> get userConfigBox => _userConfigBox;

  UserConfig? getUserConfig() {
    if (_userConfigBox.isEmpty) return null;
    return _userConfigBox.values.first;
  }

  Future<void> saveUserConfig(UserConfig config) async {
    await _userConfigBox.put(config.userId, config);
  }

  Future<void> deleteUserConfig(String userId) async {
    await _userConfigBox.delete(userId);
  }

  Future<void> clearAll() async {
    await _teamMembersBox.clear();
    await _nightShiftsBox.clear();
    await _userConfigBox.clear();
  }

  Future<void> close() async {
    await _teamMembersBox.close();
    await _nightShiftsBox.close();
    await _userConfigBox.close();
    await Hive.close();
    _isInitialized = false;
  }
}