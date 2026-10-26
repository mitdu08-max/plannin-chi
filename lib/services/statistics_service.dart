import '../models/models.dart';

/// Service for calculating statistics from night shifts
class StatisticsService {
  /// Heures d'une garde : durée réelle (fin - début, minuit géré) avec repli
  /// sur la durée forfaitaire configurée si la saisie est incomplète.
  static double _shiftHours(NightShift shift, double fallbackHours) {
    final real = shift.durationHours;
    return real > 0 ? real : fallbackHours;
  }

  /// Normalise une date (supprime l'heure) pour les comparaisons de jours.
  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Calculate total hours worked in a specific month
  static double calculateMonthlyHours(
    List<NightShift> shifts,
    int year,
    int month, {
    double shiftDurationHours = 10.0,
  }) {
    final monthlyShifts = shifts.where((s) =>
      s.date.year == year &&
      s.date.month == month &&
      s.isWorking
    ).toList();

    return monthlyShifts.fold<double>(
      0.0,
      (total, shift) => total + _shiftHours(shift, shiftDurationHours),
    );
  }

  /// Calculate total hours worked in a specific year
  static double calculateYearlyHours(
    List<NightShift> shifts,
    int year, {
    double shiftDurationHours = 10.0,
  }) {
    final yearlyShifts = shifts.where((s) =>
      s.date.year == year &&
      s.isWorking
    ).toList();

    return yearlyShifts.fold<double>(
      0.0,
      (total, shift) => total + _shiftHours(shift, shiftDurationHours),
    );
  }

  /// Count nights worked per day of week for a month
  static Map<int, int> countNightsPerWeekdayMonth(
    List<NightShift> shifts,
    int year,
    int month,
  ) {
    final counts = <int, int>{
      1: 0, // Monday
      2: 0, // Tuesday
      3: 0, // Wednesday
      4: 0, // Thursday
      5: 0, // Friday
      6: 0, // Saturday
      7: 0, // Sunday
    };

    for (final shift in shifts) {
      if (shift.date.year == year && shift.date.month == month && shift.isWorking) {
        final weekday = shift.date.weekday;
        counts[weekday] = (counts[weekday] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Count nights worked per day of week for a year
  static Map<int, int> countNightsPerWeekdayYear(
    List<NightShift> shifts,
    int year,
  ) {
    final counts = <int, int>{
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0,
    };

    for (final shift in shifts) {
      if (shift.date.year == year && shift.isWorking) {
        final weekday = shift.date.weekday;
        counts[weekday] = (counts[weekday] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Analyse des week-ends dont le **samedi** tombe dans le mois.
  ///
  /// Correction : le dimanche est cherché par date réelle et non par
  /// `day + 1`. Un samedi 31 octobre est désormais correctement associé au
  /// dimanche 1er novembre (et n'est plus classé « demi week-end »).
  static WeekendAnalysis analyzeWeekendsMonth(
    List<NightShift> shifts,
    int year,
    int month,
  ) {
    final workedDays = shifts
        .where((s) => s.isWorking)
        .map((s) => _dayOnly(s.date))
        .toSet();

    var fullWeekendsWorked = 0;
    var halfWeekendsWorked = 0;
    var fullWeekendsRest = 0;

    final lastDayOfMonth = DateTime(year, month + 1, 0).day;

    for (var day = 1; day <= lastDayOfMonth; day++) {
      final saturday = DateTime(year, month, day);
      if (saturday.weekday != DateTime.saturday) continue;

      final sunday = saturday.add(const Duration(days: 1));
      final saturdayWorked = workedDays.contains(saturday);
      final sundayWorked = workedDays.contains(_dayOnly(sunday));

      if (saturdayWorked && sundayWorked) {
        fullWeekendsWorked++;
      } else if (saturdayWorked || sundayWorked) {
        halfWeekendsWorked++;
      } else {
        fullWeekendsRest++;
      }
    }

    return WeekendAnalysis(
      fullWeekendsWorked: fullWeekendsWorked,
      halfWeekendsWorked: halfWeekendsWorked,
      fullWeekendsRest: fullWeekendsRest,
    );
  }

  /// Analyze weekends for a year
  static WeekendAnalysis analyzeWeekendsYear(
    List<NightShift> shifts,
    int year,
  ) {
    int fullWeekendsWorked = 0;
    int halfWeekendsWorked = 0;
    int fullWeekendsRest = 0;

    for (int month = 1; month <= 12; month++) {
      final analysis = analyzeWeekendsMonth(shifts, year, month);
      fullWeekendsWorked += analysis.fullWeekendsWorked;
      halfWeekendsWorked += analysis.halfWeekendsWorked;
      fullWeekendsRest += analysis.fullWeekendsRest;
    }

    return WeekendAnalysis(
      fullWeekendsWorked: fullWeekendsWorked,
      halfWeekendsWorked: halfWeekendsWorked,
      fullWeekendsRest: fullWeekendsRest,
    );
  }

  /// Get top teammates (colleagues worked with most often)
  static List<TeammateStats> getTopTeammates(
    List<NightShift> shifts,
    String currentUserId,
    List<TeamMember> allTeamMembers,
    {int limit = 10}
  ) {
    final Map<String, int> coworkerCounts = {};

    // On ne compte que les gardes de l'utilisateur courant : les shifts d'un
    // autre agent ne doivent pas gonfler les statistiques de binômes.
    final hasUserShifts = shifts.any((s) => s.agentId == currentUserId);

    for (final shift in shifts) {
      if (!shift.isWorking) continue;
      if (hasUserShifts && shift.agentId != currentUserId) continue;

      for (final coworkerId in shift.coWorkerIds) {
        coworkerCounts[coworkerId] = (coworkerCounts[coworkerId] ?? 0) + 1;
      }
    }

    // Convert to TeammateStats and sort
    final stats = coworkerCounts.entries.map((entry) {
      final member = allTeamMembers.firstWhere(
        (m) => m.id == entry.key,
        orElse: () => TeamMember(
          id: entry.key,
          firstName: '',
          lastName: '',
          trigramme: entry.key,
        ),
      );
      return TeammateStats(
        teamMember: member,
        nightsTogether: entry.value,
      );
    }).toList();

    stats.sort((a, b) => b.nightsTogether.compareTo(a.nightsTogether));

    return stats.take(limit).toList();
  }

  /// Get top teammates for a specific month
  static List<TeammateStats> getTopTeammatesMonth(
    List<NightShift> shifts,
    String currentUserId,
    List<TeamMember> allTeamMembers,
    int year,
    int month,
    {int limit = 10}
  ) {
    final monthlyShifts = shifts.where((s) =>
      s.date.year == year &&
      s.date.month == month &&
      s.isWorking
    ).toList();

    return getTopTeammates(monthlyShifts, currentUserId, allTeamMembers, limit: limit);
  }

  /// Get complete statistics for a month
  static MonthlyStatistics getMonthlyStatistics(
    List<NightShift> shifts,
    int year,
    int month,
    String currentUserId,
    List<TeamMember> allTeamMembers, {
    double shiftDurationHours = 10.0,
  }) {
    final weekdayCounts = countNightsPerWeekdayMonth(shifts, year, month);
    final weekendAnalysis = analyzeWeekendsMonth(shifts, year, month);
    final topTeammates = getTopTeammatesMonth(shifts, currentUserId, allTeamMembers, year, month);
    final totalHours = calculateMonthlyHours(shifts, year, month, shiftDurationHours: shiftDurationHours);
    final totalNights = shifts.where((s) => s.date.year == year && s.date.month == month && s.isWorking).length;

    return MonthlyStatistics(
      year: year,
      month: month,
      totalNights: totalNights,
      totalHours: totalHours,
      weekdayCounts: weekdayCounts,
      weekendAnalysis: weekendAnalysis,
      topTeammates: topTeammates,
    );
  }

  /// Get complete statistics for a year
  static YearlyStatistics getYearlyStatistics(
    List<NightShift> shifts,
    int year,
    String currentUserId,
    List<TeamMember> allTeamMembers, {
    double shiftDurationHours = 10.0,
  }) {
    final weekdayCounts = countNightsPerWeekdayYear(shifts, year);
    final weekendAnalysis = analyzeWeekendsYear(shifts, year);
    final topTeammates = getTopTeammates(shifts, currentUserId, allTeamMembers);
    final totalHours = calculateYearlyHours(shifts, year, shiftDurationHours: shiftDurationHours);
    final totalNights = shifts.where((s) => s.date.year == year && s.isWorking).length;

    // Monthly breakdown
    final monthlyBreakdown = <int, MonthlyStatistics>{};
    for (int month = 1; month <= 12; month++) {
      monthlyBreakdown[month] = getMonthlyStatistics(
        shifts, year, month, currentUserId, allTeamMembers,
        shiftDurationHours: shiftDurationHours,
      );
    }

    return YearlyStatistics(
      year: year,
      totalNights: totalNights,
      totalHours: totalHours,
      weekdayCounts: weekdayCounts,
      weekendAnalysis: weekendAnalysis,
      topTeammates: topTeammates,
      monthlyBreakdown: monthlyBreakdown,
    );
  }
}

/// Weekend analysis result
class WeekendAnalysis {
  final int fullWeekendsWorked;
  final int halfWeekendsWorked;
  final int fullWeekendsRest;

  WeekendAnalysis({
    required this.fullWeekendsWorked,
    required this.halfWeekendsWorked,
    required this.fullWeekendsRest,
  });

  int get totalWeekends => fullWeekendsWorked + halfWeekendsWorked + fullWeekendsRest;

  double get workedPercentage => totalWeekends > 0
      ? ((fullWeekendsWorked + halfWeekendsWorked * 0.5) / totalWeekends * 100)
      : 0.0;
}

/// Teammate statistics
class TeammateStats {
  final TeamMember teamMember;
  final int nightsTogether;

  TeammateStats({
    required this.teamMember,
    required this.nightsTogether,
  });

  String get displayName => teamMember.displayName;
  String get trigramme => teamMember.trigramme;
}

/// Monthly statistics container
class MonthlyStatistics {
  final int year;
  final int month;
  final int totalNights;
  final double totalHours;
  final Map<int, int> weekdayCounts;
  final WeekendAnalysis weekendAnalysis;
  final List<TeammateStats> topTeammates;

  MonthlyStatistics({
    required this.year,
    required this.month,
    required this.totalNights,
    required this.totalHours,
    required this.weekdayCounts,
    required this.weekendAnalysis,
    required this.topTeammates,
  });

  String get monthName {
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month];
  }

  int get weekdayTotal => weekdayCounts.values.fold(0, (a, b) => a + b);
}

/// Yearly statistics container
class YearlyStatistics {
  final int year;
  final int totalNights;
  final double totalHours;
  final Map<int, int> weekdayCounts;
  final WeekendAnalysis weekendAnalysis;
  final List<TeammateStats> topTeammates;
  final Map<int, MonthlyStatistics> monthlyBreakdown;

  YearlyStatistics({
    required this.year,
    required this.totalNights,
    required this.totalHours,
    required this.weekdayCounts,
    required this.weekendAnalysis,
    required this.topTeammates,
    required this.monthlyBreakdown,
  });

  int get weekdayTotal => weekdayCounts.values.fold(0, (a, b) => a + b);
}