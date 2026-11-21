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
    final yearlyShifts = shifts.where((s) => s.date.year == year).toList();
    final weekdayCounts = countNightsPerWeekdayYear(shifts, year);
    final weekendAnalysis = analyzeWeekendsYear(shifts, year);
    final topTeammates =
        getTopTeammates(yearlyShifts, currentUserId, allTeamMembers);
    final totalHours =
        calculateYearlyHours(shifts, year, shiftDurationHours: shiftDurationHours);
    final totalNights =
        yearlyShifts.where((s) => s.isWorking).length;

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

  /// Formate un total d'heures de manière lisible (ex: `1452h` ou `1452.5h`).
  static String formatHours(double hours) {
    if ((hours - hours.roundToDouble()).abs() < 0.05) {
      return '${hours.round()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Calcule le bilan comparatif de chaque membre de l'équipe sur un mois
  /// ([month] non nul) ou sur une année complète ([month] == null).
  static TeamPeriodSummary getTeamStatistics({
    required List<NightShift> allShifts,
    required List<TeamMember> allTeamMembers,
    required int year,
    int? month,
    double shiftDurationHours = 10.0,
    TeamSortField sortBy = TeamSortField.nights,
    bool ascending = false,
  }) {
    // Indexation des membres connus par ID exact et par trigramme majuscule.
    final membersById = <String, TeamMember>{};
    final membersByTrigramme = <String, TeamMember>{};
    for (final m in allTeamMembers) {
      membersById[m.id] = m;
      if (m.trigramme.isNotEmpty) {
        membersByTrigramme.putIfAbsent(m.trigramme.toUpperCase(), () => m);
      }
    }

    // Regroupement de toutes les gardes (toutes périodes) par agent canonique
    // afin que les week-ends à cheval (sam. 31 / dim. 1er) soient exacts.
    final shiftsByAgentKey = <String, List<NightShift>>{};
    final resolvedMembers = <String, TeamMember>{
      for (final m in allTeamMembers) m.id: m,
    };

    for (final shift in allShifts) {
      final upperTrig = shift.agentTrigramme.trim().toUpperCase();
      final upperId = shift.agentId.trim().toUpperCase();

      TeamMember? member = membersById[shift.agentId];
      member ??= upperTrig.isNotEmpty ? membersByTrigramme[upperTrig] : null;
      member ??= upperId.isNotEmpty ? membersByTrigramme[upperId] : null;

      if (member == null) {
        final fallbackKey = shift.agentId.isNotEmpty
            ? shift.agentId
            : (upperTrig.isNotEmpty ? upperTrig : 'INCONNU');
        final label = upperTrig.isNotEmpty ? upperTrig : fallbackKey;
        member = resolvedMembers.putIfAbsent(
          fallbackKey,
          () => TeamMember(
            id: fallbackKey,
            firstName: label,
            lastName: '',
            trigramme: label,
          ),
        );
      } else {
        resolvedMembers.putIfAbsent(member.id, () => member!);
      }

      shiftsByAgentKey.putIfAbsent(member.id, () => []).add(shift);
    }

    final teamCoveredMonths = <int>{};
    final agentStats = <AgentPeriodStats>[];

    for (final entry in resolvedMembers.entries) {
      final member = entry.value;
      final agentAllShifts = shiftsByAgentKey[entry.key] ?? const <NightShift>[];

      final periodShifts = agentAllShifts.where((s) {
        if (s.date.year != year) return false;
        if (month != null && s.date.month != month) return false;
        return true;
      }).toList();

      final workingShifts = periodShifts.where((s) => s.isWorking).toList();
      final vacationDays =
          periodShifts.where((s) => !s.isWorking && s.isVacation).length;

      final totalNights = workingShifts.length;
      final totalHours = workingShifts.fold<double>(
        0.0,
        (total, shift) => total + _shiftHours(shift, shiftDurationHours),
      );

      final weekendAnalysis = month != null
          ? analyzeWeekendsMonth(agentAllShifts, year, month)
          : analyzeWeekendsYear(agentAllShifts, year);

      final weekdayCounts = month != null
          ? countNightsPerWeekdayMonth(agentAllShifts, year, month)
          : countNightsPerWeekdayYear(agentAllShifts, year);

      final coveredMonths = <int>{};
      for (final s in periodShifts) {
        if (s.isWorking || s.isVacation) {
          coveredMonths.add(s.date.month);
          teamCoveredMonths.add(s.date.month);
        }
      }

      agentStats.add(
        AgentPeriodStats(
          teamMember: member,
          totalNights: totalNights,
          totalHours: totalHours,
          weekendAnalysis: weekendAnalysis,
          vacationDays: vacationDays,
          weekdayCounts: weekdayCounts,
          coveredMonths: coveredMonths,
        ),
      );
    }

    agentStats.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case TeamSortField.nights:
          cmp = a.totalNights.compareTo(b.totalNights);
          if (cmp == 0) cmp = a.totalHours.compareTo(b.totalHours);
          if (cmp == 0) {
            return a.displayName
                .toUpperCase()
                .compareTo(b.displayName.toUpperCase());
          }
          return ascending ? cmp : -cmp;
        case TeamSortField.hours:
          cmp = a.totalHours.compareTo(b.totalHours);
          if (cmp == 0) cmp = a.totalNights.compareTo(b.totalNights);
          if (cmp == 0) {
            return a.displayName
                .toUpperCase()
                .compareTo(b.displayName.toUpperCase());
          }
          return ascending ? cmp : -cmp;
        case TeamSortField.weekends:
          cmp = a.weekendsWorked.compareTo(b.weekendsWorked);
          if (cmp == 0) {
            cmp = a.fullWeekendsWorked.compareTo(b.fullWeekendsWorked);
          }
          if (cmp == 0) cmp = a.totalNights.compareTo(b.totalNights);
          if (cmp == 0) {
            return a.displayName
                .toUpperCase()
                .compareTo(b.displayName.toUpperCase());
          }
          return ascending ? cmp : -cmp;
        case TeamSortField.name:
          cmp = a.displayName
              .toUpperCase()
              .compareTo(b.displayName.toUpperCase());
          return ascending ? cmp : -cmp;
      }
    });

    return TeamPeriodSummary(
      year: year,
      month: month,
      agentStats: agentStats,
      coveredMonths: teamCoveredMonths,
    );
  }

  /// Construit un résumé texte prêt à être copié/partagé (WhatsApp, mail...).
  static String buildTeamSummaryText(TeamPeriodSummary summary) {
    const months = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    final periodLabel = summary.month != null
        ? '${months[summary.month!]} ${summary.year}'
        : 'Année ${summary.year} (${summary.coveredMonths.length}/12 mois)';

    final buffer = StringBuffer()
      ..writeln('Bilan Équipe — $periodLabel')
      ..writeln();

    for (final stat in summary.agentStats) {
      final weDetail = stat.halfWeekendsWorked > 0
          ? '${stat.weekendsWorked} WE (${stat.fullWeekendsWorked} comp., ${stat.halfWeekendsWorked} demi)'
          : '${stat.weekendsWorked} WE';
      final caPart = stat.vacationDays > 0 ? ' · ${stat.vacationDays} CA' : '';
      buffer.writeln(
        '• ${stat.displayName} : ${stat.totalNights} nuits · $weDetail · ${formatHours(stat.totalHours)}$caPart',
      );
    }

    buffer
      ..writeln()
      ..write(
        'Total équipe : ${summary.totalTeamNights} nuits · ${formatHours(summary.totalTeamHours)}',
      );

    return buffer.toString();
  }
}

/// Critères de tri pour le bilan d'équipe.
enum TeamSortField { nights, weekends, hours, name }

/// Statistiques d'un agent sur un mois ou une année.
class AgentPeriodStats {
  final TeamMember teamMember;
  final int totalNights;
  final double totalHours;
  final WeekendAnalysis weekendAnalysis;
  final int vacationDays;
  final Map<int, int> weekdayCounts;
  final Set<int> coveredMonths;

  AgentPeriodStats({
    required this.teamMember,
    required this.totalNights,
    required this.totalHours,
    required this.weekendAnalysis,
    this.vacationDays = 0,
    required this.weekdayCounts,
    this.coveredMonths = const {},
  });

  String get displayName {
    final name = teamMember.displayName.trim();
    if (name.isNotEmpty) return name;
    final trig = teamMember.trigramme.trim();
    return trig.isNotEmpty ? trig : teamMember.id;
  }

  String get trigramme => teamMember.trigramme;

  /// Nombre total de week-ends travaillés (complets + demi week-ends).
  int get weekendsWorked =>
      weekendAnalysis.fullWeekendsWorked + weekendAnalysis.halfWeekendsWorked;

  int get fullWeekendsWorked => weekendAnalysis.fullWeekendsWorked;
  int get halfWeekendsWorked => weekendAnalysis.halfWeekendsWorked;
}

/// Bilan global de l'équipe sur un mois ou une année.
class TeamPeriodSummary {
  final int year;
  final int? month;
  final List<AgentPeriodStats> agentStats;
  final Set<int> coveredMonths;

  TeamPeriodSummary({
    required this.year,
    this.month,
    required this.agentStats,
    required this.coveredMonths,
  });

  int get totalTeamNights =>
      agentStats.fold<int>(0, (sum, s) => sum + s.totalNights);

  double get totalTeamHours =>
      agentStats.fold<double>(0.0, (sum, s) => sum + s.totalHours);

  int get activeAgentsCount =>
      agentStats.where((s) => s.totalNights > 0 || s.vacationDays > 0).length;

  int get maxAgentNights => agentStats.fold<int>(
        0,
        (maxVal, s) => s.totalNights > maxVal ? s.totalNights : maxVal,
      );
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