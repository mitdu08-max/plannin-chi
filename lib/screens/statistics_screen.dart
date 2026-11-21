import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/pdf_export_service.dart';
import '../services/statistics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  StatisticsPeriod _period = StatisticsPeriod.month;
  StatisticsScope _scope = StatisticsScope.personal;
  TeamSortField _teamSort = TeamSortField.nights;
  bool _teamSortAscending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nightShiftsAsync = ref.watch(allNightShiftsProvider);
    final userConfigAsync = ref.watch(userConfigProvider);
    final teamMembersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          PopupMenuButton<StatisticsPeriod>(
            initialValue: _period,
            onSelected: (period) => setState(() => _period = period),
            itemBuilder: (context) => [
              const PopupMenuItem(value: StatisticsPeriod.month, child: Text('Par Mois')),
              const PopupMenuItem(value: StatisticsPeriod.year, child: Text('Par Année')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _period == StatisticsPeriod.month ? 'Mois' : 'Année',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: NeonBackground(
        child: nightShiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error),
        data: (allShifts) => userConfigAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorState(error),
          data: (userConfig) => teamMembersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error),
            data: (teamMembers) {
              if (userConfig == null) {
                return _buildNotConfiguredState();
              }

              final userShifts = allShifts
                  .where((s) =>
                      (s.agentId == userConfig.userId ||
                       s.agentTrigramme.toUpperCase() ==
                           userConfig.userTrigramme.toUpperCase()) &&
                      s.isWorking)
                  .toList();

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(allNightShiftsProvider);
                  ref.invalidate(userConfigProvider);
                  ref.invalidate(teamMembersProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bascule Mon bilan / Bilan Équipe
                      _buildScopeSelector(theme),

                      const SizedBox(height: 16),

                      // Period Selector
                      _buildPeriodSelector(theme),

                      const SizedBox(height: 24),

                      if (_scope == StatisticsScope.personal) ...[
                        // Summary Cards
                        _buildSummaryCards(theme, userShifts, userConfig),

                        const SizedBox(height: 14),

                        // Barre d'export PDF personnel
                        _buildPersonalPdfCard(
                          theme,
                          allShifts,
                          teamMembers,
                          userConfig,
                        ),

                        const SizedBox(height: 24),

                        // Weekday Bar Chart
                        _buildWeekdayChart(theme, userShifts),

                        const SizedBox(height: 24),

                        // Weekend Analysis
                        _buildWeekendAnalysis(theme, userShifts),

                        const SizedBox(height: 24),

                        // Top Teammates
                        _buildTopTeammates(
                            theme, userShifts, teamMembers, userConfig),
                      ] else ...[
                        // Bilan Équipe
                        _buildTeamOverviewSection(
                          theme,
                          allShifts,
                          teamMembers,
                          userConfig,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildScopeSelector(ThemeData theme) {
    return SegmentedButton<StatisticsScope>(
      segments: const [
        ButtonSegment(
          value: StatisticsScope.personal,
          label: Text('Mon bilan'),
          icon: Icon(Icons.person_outline),
        ),
        ButtonSegment(
          value: StatisticsScope.team,
          label: Text('Bilan Équipe'),
          icon: Icon(Icons.groups_outlined),
        ),
      ],
      selected: {_scope},
      onSelectionChanged: (selection) =>
          setState(() => _scope = selection.first),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final isMonth = _period == StatisticsPeriod.month;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousPeriod,
                  tooltip: 'Période précédente',
                ),

                // Period title
                Text(
                  isMonth
                      ? '${_getMonthName(_selectedMonth)} $_selectedYear'
                      : 'Année $_selectedYear',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Next button
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextPeriod,
                  tooltip: 'Période suivante',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Month/Year toggle
            SegmentedButton<StatisticsPeriod>(
              segments: const [
                ButtonSegment(value: StatisticsPeriod.month, label: Text('Mois'), icon: Icon(Icons.calendar_month)),
                ButtonSegment(value: StatisticsPeriod.year, label: Text('Année'), icon: Icon(Icons.calendar_today)),
              ],
              selected: {_period},
              onSelectionChanged: (selection) => setState(() => _period = selection.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, List<NightShift> userShifts, UserConfig userConfig) {
    MonthlyStatistics? monthlyStats;
    YearlyStatistics? yearlyStats;

    if (_period == StatisticsPeriod.month) {
      monthlyStats = StatisticsService.getMonthlyStatistics(
        userShifts,
        _selectedYear,
        _selectedMonth,
        userConfig.userId,
        [], // team members not needed for basic stats
        shiftDurationHours: userConfig.shiftDurationHours.toDouble(),
      );
    } else {
      yearlyStats = StatisticsService.getYearlyStatistics(
        userShifts,
        _selectedYear,
        userConfig.userId,
        [],
        shiftDurationHours: userConfig.shiftDurationHours.toDouble(),
      );
    }

    final totalNights = _period == StatisticsPeriod.month ? monthlyStats!.totalNights : yearlyStats!.totalNights;
    final totalHours = _period == StatisticsPeriod.month ? monthlyStats!.totalHours : yearlyStats!.totalHours;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            theme,
            title: 'Heures totales',
            value: StatisticsService.formatHours(totalHours),
            icon: Icons.access_time,
            color: AppColors.shiftEnd,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryCard(
            theme,
            title: 'Nuits travaillées',
            value: '$totalNights',
            icon: Icons.nightlight_round,
            color: AppColors.nightTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return MetricCard(
      value: value,
      label: title,
      icon: icon,
      accent: color,
    );
  }

  Widget _buildWeekdayChart(ThemeData theme, List<NightShift> userShifts) {
    Map<int, int> weekdayCounts;

    if (_period == StatisticsPeriod.month) {
      weekdayCounts = StatisticsService.countNightsPerWeekdayMonth(userShifts, _selectedYear, _selectedMonth);
    } else {
      weekdayCounts = StatisticsService.countNightsPerWeekdayYear(userShifts, _selectedYear);
    }

    final weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final maxCount = weekdayCounts.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TechLabel(
              'Répartition par jour de la semaine',
              size: 9.5,
              color: theme.colorScheme.onSurface,
              letterSpacing: 1.8,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? (maxCount * 1.3).toDouble() : 5,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => theme.colorScheme.surfaceContainerHighest,
                      tooltipRoundedRadius: 10,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${weekdays[group.x.toInt()]}: ${rod.toY.toInt()} nuit(s)',
                          TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < weekdays.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                weekdays[value.toInt()].toUpperCase(),
                                style: AppFonts.tag(
                                  size: 8,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value == value.toInt()) {
                            return Text(
                              value.toInt().toString(),
                              style: AppFonts.tag(
                                size: 8.5,
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 0,
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (index) {
                    final count = weekdayCounts[index + 1] ?? 0;
                    final isWeekend = index >= 5; // Sat/Sun
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isWeekend
                                ? [AppColors.shiftEnd, AppColors.shiftStart]
                                : [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                          ),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxCount.toDouble(),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekendAnalysis(ThemeData theme, List<NightShift> userShifts) {
    WeekendAnalysis weekendAnalysis;

    if (_period == StatisticsPeriod.month) {
      weekendAnalysis = StatisticsService.analyzeWeekendsMonth(userShifts, _selectedYear, _selectedMonth);
    } else {
      weekendAnalysis = StatisticsService.analyzeWeekendsYear(userShifts, _selectedYear);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TechLabel(
              'Analyse des week-ends',
              size: 9.5,
              color: theme.colorScheme.onSurface,
              letterSpacing: 1.8,
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildWeekendStatCard(
                    theme,
                    'Complets travaillés',
                    '${weekendAnalysis.fullWeekendsWorked}',
                    Icons.weekend,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeekendStatCard(
                    theme,
                    'Demi week-ends',
                    '${weekendAnalysis.halfWeekendsWorked}',
                    Icons.nights_stay,
                    AppColors.nightTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeekendStatCard(
                    theme,
                    'Repos complets',
                    '${weekendAnalysis.fullWeekendsRest}',
                    Icons.beach_access,
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux de week-ends travaillés',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${weekendAnalysis.workedPercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: weekendAnalysis.workedPercentage / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekendStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppFonts.monoText(
                size: 22,
                weight: FontWeight.w800,
                color: color,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            maxLines: 2,
            style: AppFonts.tag(
              size: 7.5,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTeammates(
    ThemeData theme,
    List<NightShift> userShifts,
    List<TeamMember> teamMembers,
    UserConfig userConfig,
  ) {
    List<TeammateStats> topTeammates;

    if (_period == StatisticsPeriod.month) {
      topTeammates = StatisticsService.getTopTeammatesMonth(
        userShifts,
        userConfig.userId,
        teamMembers,
        _selectedYear,
        _selectedMonth,
        limit: 5,
      );
    } else {
      final yearShifts =
          userShifts.where((s) => s.date.year == _selectedYear).toList();
      topTeammates = StatisticsService.getTopTeammates(
        yearShifts,
        userConfig.userId,
        teamMembers,
        limit: 5,
      );
    }

    if (topTeammates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Aucun collègue détecté',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Importez un planning pour voir vos coéquipiers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TechLabel(
                  'Top collègues de garde',
                  size: 9.5,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 1.8,
                ),
                Text(
                  _period == StatisticsPeriod.month
                      ? 'Ce mois-ci'
                      : 'Cette année',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topTeammates.asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              final medal = _getMedal(index);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Rank/Medal
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _getMedalColor(index).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: _getMedalColor(index).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        medal,
                        style: AppFonts.monoText(
                          size: 13,
                          weight: FontWeight.w800,
                          color: _getMedalColor(index),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Teammate info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Trigramme: ${stat.trigramme}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nights together count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nightlight_round, size: 11, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${stat.nightsTogether}',
                            style: AppFonts.tag(
                              size: 9,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getMedal(int index) => '${index + 1}'.padLeft(2, '0');

  Color _getMedalColor(int index) {
    const palette = [
      AppColors.neonLime,
      AppColors.neonCyan,
      AppColors.neonAmber,
      AppColors.neonMid,
      AppColors.neonDim,
    ];
    return palette[index % palette.length];
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppColors.danger),
          const SizedBox(height: 16),
          Text('Erreur: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(allNightShiftsProvider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfiguredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('Profil non configuré'),
          const SizedBox(height: 8),
          const Text('Configurez votre profil dans l\'onglet Import'),
        ],
      ),
    );
  }

  Widget _buildTeamOverviewSection(
    ThemeData theme,
    List<NightShift> allShifts,
    List<TeamMember> teamMembers,
    UserConfig userConfig,
  ) {
    final summary = StatisticsService.getTeamStatistics(
      allShifts: allShifts,
      allTeamMembers: teamMembers,
      year: _selectedYear,
      month: _period == StatisticsPeriod.month ? _selectedMonth : null,
      shiftDurationHours: userConfig.shiftDurationHours.toDouble(),
      sortBy: _teamSort,
      ascending: _teamSortAscending,
    );

    if (summary.agentStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun membre d\'équipe enregistré',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Importez un planning complet (photo, capture ou PDF) pour calculer le bilan de toute l\'équipe.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final maxNights = summary.maxAgentNights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cartes globales équipe
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                theme,
                title: 'Nuits équipe',
                value: '${summary.totalTeamNights}',
                icon: Icons.nightlight_round,
                color: AppColors.shiftEnd,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                theme,
                title: 'Heures équipe',
                value: StatisticsService.formatHours(summary.totalTeamHours),
                icon: Icons.access_time,
                color: AppColors.neonLime,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Carte de couverture mensuelle (en mode Année) + bouton Copier
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TechLabel(
                            _period == StatisticsPeriod.year
                                ? 'Bilan annuel • ${summary.coveredMonths.length}/12 mois'
                                : 'Bilan mensuel • ${summary.activeAgentsCount}/${summary.agentStats.length} actifs',
                            size: 9.5,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: 1.4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Touchez un membre pour voir son détail',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => _copyTeamSummary(summary),
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copier'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showTeamPdfActionsSheet(theme, summary),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (_period == StatisticsPeriod.year) ...[
                  const SizedBox(height: 14),
                  _buildMonthCoverageStrip(theme, summary.coveredMonths),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Barre de tri
        _buildTeamSortBar(theme),

        const SizedBox(height: 12),

        // Liste des membres de l'équipe
        ...summary.agentStats.asMap().entries.map((entry) {
          final rank = entry.key;
          final stat = entry.value;
          final isCurrentUser =
              stat.teamMember.id == userConfig.userId ||
                  (userConfig.userTrigramme.isNotEmpty &&
                      stat.trigramme.toUpperCase() ==
                          userConfig.userTrigramme.toUpperCase());

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAgentBilanCard(
              theme: theme,
              rank: rank,
              stat: stat,
              maxNights: maxNights,
              isCurrentUser: isCurrentUser,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthCoverageStrip(ThemeData theme, Set<int> coveredMonths) {
    const labels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];
    return Row(
      children: List.generate(12, (index) {
        final monthNum = index + 1;
        final covered = coveredMonths.contains(monthNum);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 11 ? 4 : 0),
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: covered
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: covered
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              labels[index],
              style: AppFonts.tag(
                size: 8.5,
                color: covered
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTeamSortBar(ThemeData theme) {
    Widget buildChip(TeamSortField field, String label) {
      final selected = _teamSort == field;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(
                _teamSortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
              ),
            ],
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (_teamSort == field) {
              _teamSortAscending = !_teamSortAscending;
            } else {
              _teamSort = field;
              _teamSortAscending = field == TeamSortField.name;
            }
          });
        },
        visualDensity: VisualDensity.compact,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TechLabel(
            'Trier :',
            size: 8.5,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
          const SizedBox(width: 8),
          buildChip(TeamSortField.nights, 'Nuits'),
          const SizedBox(width: 6),
          buildChip(TeamSortField.weekends, 'Week-ends'),
          const SizedBox(width: 6),
          buildChip(TeamSortField.hours, 'Heures'),
          const SizedBox(width: 6),
          buildChip(TeamSortField.name, 'Nom'),
        ],
      ),
    );
  }

  Widget _buildAgentBilanCard({
    required ThemeData theme,
    required int rank,
    required AgentPeriodStats stat,
    required int maxNights,
    required bool isCurrentUser,
  }) {
    final accent = isCurrentUser
        ? theme.colorScheme.primary
        : _getMedalColor(rank);
    final ratio = maxNights > 0 ? (stat.totalNights / maxNights).clamp(0.0, 1.0) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isCurrentUser
              ? theme.colorScheme.primary.withValues(alpha: 0.7)
              : theme.colorScheme.outline.withValues(alpha: 0.25),
          width: isCurrentUser ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showAgentDetailSheet(theme, stat, isCurrentUser),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      _getMedal(rank),
                      style: AppFonts.monoText(
                        size: 11,
                        weight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            stat.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              'MOI',
                              style: AppFonts.tag(
                                size: 8,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (stat.vacationDays > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.vacationEnd.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.vacationEnd.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${stat.vacationDays} CA',
                        style: AppFonts.tag(
                          size: 8,
                          color: AppColors.vacationEnd,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildAgentMetricColumn(
                      theme: theme,
                      value: '${stat.totalNights}',
                      label: stat.totalNights > 1 ? 'NUITS' : 'NUIT',
                      color: AppColors.shiftEnd,
                    ),
                  ),
                  Expanded(
                    child: _buildAgentMetricColumn(
                      theme: theme,
                      value: '${stat.weekendsWorked}',
                      label: stat.halfWeekendsWorked > 0
                          ? 'WE (${stat.fullWeekendsWorked}c·${stat.halfWeekendsWorked}½)'
                          : 'WEEK-ENDS',
                      color: AppColors.nightTertiary,
                    ),
                  ),
                  Expanded(
                    child: _buildAgentMetricColumn(
                      theme: theme,
                      value: StatisticsService.formatHours(stat.totalHours),
                      label: 'HEURES',
                      color: AppColors.neonLime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentMetricColumn({
    required ThemeData theme,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppFonts.monoText(
              size: 18,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.tag(
            size: 7.5,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Future<void> _copyTeamSummary(TeamPeriodSummary summary) async {
    final text = StatisticsService.buildTeamSummaryText(summary);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: const Text(
          'Bilan équipe copié dans le presse-papiers !',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showAgentDetailSheet(
    ThemeData theme,
    AgentPeriodStats stat,
    bool isCurrentUser,
  ) {
    final periodTitle = _period == StatisticsPeriod.month
        ? '${_getMonthName(_selectedMonth)} $_selectedYear'
        : 'Année $_selectedYear';
    const weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              periodTitle +
                                  (isCurrentUser ? ' • Votre profil' : ''),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Nuits',
                          '${stat.totalNights}',
                          Icons.nightlight_round,
                          AppColors.shiftEnd,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Heures',
                          StatisticsService.formatHours(stat.totalHours),
                          Icons.access_time,
                          AppColors.neonLime,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Congés',
                          '${stat.vacationDays}',
                          Icons.beach_access,
                          AppColors.vacationEnd,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TechLabel(
                    'Week-ends ($periodTitle)',
                    size: 9,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 1.5,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Complets',
                          '${stat.weekendAnalysis.fullWeekendsWorked}',
                          Icons.weekend,
                          AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Demi WE',
                          '${stat.weekendAnalysis.halfWeekendsWorked}',
                          Icons.nights_stay,
                          AppColors.nightTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildWeekendStatCard(
                          theme,
                          'Repos WE',
                          '${stat.weekendAnalysis.fullWeekendsRest}',
                          Icons.spa_outlined,
                          theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TechLabel(
                    'Répartition par jour',
                    size: 9,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 1.5,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(7, (i) {
                      final count = stat.weekdayCounts[i + 1] ?? 0;
                      final isWe = i >= 5;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: (isWe
                                    ? AppColors.nightTertiary
                                    : theme.colorScheme.primary)
                                .withValues(alpha: count > 0 ? 0.14 : 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (isWe
                                      ? AppColors.nightTertiary
                                      : theme.colorScheme.primary)
                                  .withValues(alpha: count > 0 ? 0.45 : 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$count',
                                style: AppFonts.monoText(
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: count > 0
                                      ? (isWe
                                          ? AppColors.nightTertiary
                                          : theme.colorScheme.primary)
                                      : theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                weekdays[i].toUpperCase(),
                                style: AppFonts.tag(
                                  size: 7.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_period == StatisticsPeriod.year) ...[
                    const SizedBox(height: 18),
                    TechLabel(
                      'Mois renseignés (${stat.coveredMonths.length}/12)',
                      size: 9,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 1.5,
                    ),
                    const SizedBox(height: 8),
                    _buildMonthCoverageStrip(theme, stat.coveredMonths),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _exportAgentPdf(stat, share: false);
                          },
                          icon: const Icon(Icons.download_rounded, size: 17),
                          label: const Text('Enregistrer PDF'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _exportAgentPdf(stat, share: true);
                          },
                          icon: const Icon(Icons.share_outlined, size: 17),
                          label: const Text('Envoyer PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonalPdfCard(
    ThemeData theme,
    List<NightShift> allShifts,
    List<TeamMember> teamMembers,
    UserConfig userConfig,
  ) {
    final summary = StatisticsService.getTeamStatistics(
      allShifts: allShifts,
      allTeamMembers: teamMembers,
      year: _selectedYear,
      month: _period == StatisticsPeriod.month ? _selectedMonth : null,
      shiftDurationHours: userConfig.shiftDurationHours.toDouble(),
    );

    final myStat = summary.agentStats.firstWhere(
      (s) =>
          s.teamMember.id == userConfig.userId ||
          (userConfig.userTrigramme.isNotEmpty &&
              s.trigramme.toUpperCase() ==
                  userConfig.userTrigramme.toUpperCase()),
      orElse: () => AgentPeriodStats(
        teamMember: TeamMember(
          id: userConfig.userId,
          firstName: userConfig.userName,
          lastName: '',
          trigramme: userConfig.userTrigramme,
        ),
        totalNights: 0,
        totalHours: 0,
        weekendAnalysis: WeekendAnalysis(
          fullWeekendsWorked: 0,
          halfWeekendsWorked: 0,
          fullWeekendsRest: 0,
        ),
        weekdayCounts: const {},
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _period == StatisticsPeriod.year
                    ? 'Ma fiche annuelle $_selectedYear (PDF)'
                    : 'Ma fiche ${_getMonthName(_selectedMonth)} (PDF)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportAgentPdf(myStat, share: false),
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Sauver'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton.icon(
              onPressed: () => _exportAgentPdf(myStat, share: true),
              icon: const Icon(Icons.share_outlined, size: 15),
              label: const Text('Envoyer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeamPdfActionsSheet(ThemeData theme, TeamPeriodSummary summary) {
    final periodTitle = _period == StatisticsPeriod.month
        ? '${_getMonthName(_selectedMonth)} $_selectedYear'
        : 'Année $_selectedYear';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Exporter le Bilan PDF — $periodTitle',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Génère le document officiel récapitulatif de toute l\'équipe (nuits, heures, week-ends, congés et détail mensuel).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _exportTeamPdf(summary, share: true);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text(
                    'Envoyer / Partager le PDF Équipe (WhatsApp, Mail...)',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _exportTeamPdf(summary, share: false);
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Enregistrer le PDF Équipe dans Téléchargements',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportTeamPdf(
    TeamPeriodSummary summary, {
    required bool share,
  }) async {
    try {
      final bytes = PdfExportService.generateTeamReportPdf(summary);
      final fileName = PdfExportService.buildTeamFileName(summary);
      final title = summary.month != null
          ? 'Bilan Équipe ${_getMonthName(summary.month!)} ${summary.year}'
          : 'Bilan Équipe Année ${summary.year}';

      if (share) {
        await PdfExportService.sharePdf(
          bytes: bytes,
          fileName: fileName,
          title: title,
        );
      } else {
        final savedPath = await PdfExportService.savePdfToDevice(
          bytes: bytes,
          fileName: fileName,
        );
        if (!mounted || savedPath == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'PDF enregistré : $savedPath',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Erreur lors de l\'export PDF : $e'),
        ),
      );
    }
  }

  Future<void> _exportAgentPdf(
    AgentPeriodStats stat, {
    required bool share,
  }) async {
    try {
      final month = _period == StatisticsPeriod.month ? _selectedMonth : null;
      final bytes = PdfExportService.generateAgentReportPdf(
        stat: stat,
        year: _selectedYear,
        month: month,
      );
      final fileName = PdfExportService.buildAgentFileName(
        stat,
        _selectedYear,
        month: month,
      );
      final title = month != null
          ? 'Fiche ${stat.displayName} - ${_getMonthName(month)} $_selectedYear'
          : 'Fiche Annuelle ${stat.displayName} - $_selectedYear';

      if (share) {
        await PdfExportService.sharePdf(
          bytes: bytes,
          fileName: fileName,
          title: title,
        );
      } else {
        final savedPath = await PdfExportService.savePdfToDevice(
          bytes: bytes,
          fileName: fileName,
        );
        if (!mounted || savedPath == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Fiche PDF enregistrée : $savedPath',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Erreur lors de l\'export PDF : $e'),
        ),
      );
    }
  }

  void _goToPreviousPeriod() {
    setState(() {
      if (_period == StatisticsPeriod.month) {
        if (_selectedMonth == 1) {
          _selectedMonth = 12;
          _selectedYear--;
        } else {
          _selectedMonth--;
        }
      } else {
        _selectedYear--;
      }
    });
  }

  void _goToNextPeriod() {
    setState(() {
      if (_period == StatisticsPeriod.month) {
        if (_selectedMonth == 12) {
          _selectedMonth = 1;
          _selectedYear++;
        } else {
          _selectedMonth++;
        }
      } else {
        _selectedYear++;
      }
    });
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month];
  }
}

enum StatisticsPeriod { month, year }

enum StatisticsScope { personal, team }