import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/providers.dart';
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
      body: AuroraBackground(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Period Selector
                      _buildPeriodSelector(theme),

                      const SizedBox(height: 24),

                      // Summary Cards
                      _buildSummaryCards(theme, userShifts, userConfig),

                      const SizedBox(height: 24),

                      // Weekday Bar Chart
                      _buildWeekdayChart(theme, userShifts),

                      const SizedBox(height: 24),

                      // Weekend Analysis
                      _buildWeekendAnalysis(theme, userShifts),

                      const SizedBox(height: 24),

                      // Top Teammates
                      _buildTopTeammates(theme, userShifts, teamMembers, userConfig),
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
            value: '${totalHours.toStringAsFixed(1)}h',
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
            Text(
              'Répartition par jour de la semaine',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                                weekdays[value.toInt()],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
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
            Text(
              'Analyse des week-ends',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
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
      topTeammates = StatisticsService.getTopTeammates(
        userShifts,
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
                Text(
                  'Top collègues de garde',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getMedalColor(index).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          medal,
                          style: TextStyle(
                            color: _getMedalColor(index),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nightlight_round, size: 16, color: theme.colorScheme.onPrimaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            '${stat.nightsTogether} garde(s)',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
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

  String _getMedal(int index) {
    switch (index) {
      case 0: return '🥇';
      case 1: return '🥈';
      case 2: return '🥉';
      default: return '#${index + 1}';
    }
  }

  Color _getMedalColor(int index) {
    switch (index) {
      case 0: return Colors.amber;
      case 1: return Colors.grey.shade400;
      case 2: return Colors.brown.shade300;
      default: return Colors.blue;
    }
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
          const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Profil non configuré'),
          const SizedBox(height: 8),
          const Text('Configurez votre profil dans l\'onglet Import'),
        ],
      ),
    );
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