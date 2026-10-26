import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/statistics_service.dart';
import 'import_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Écran d'accueil : la prochaine garde, la semaine à venir et les chiffres
/// du mois. C'est le « tableau de bord » demandé avant tout le reste.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(userConfigProvider);
    final shiftsAsync = ref.watch(allNightShiftsProvider);
    final membersAsync = ref.watch(teamMembersProvider);

    final config = configAsync.valueOrNull;
    if (config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allShifts = shiftsAsync.valueOrNull ?? const <NightShift>[];
    final members = membersAsync.valueOrNull ?? const <TeamMember>[];

    final mine = allShifts
        .where((s) => s.agentId == config.userId && (s.isWorking || s.isVacation))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final upcoming = mine
        .where((s) => s.isWorking && !s.date.isBefore(todayOnly))
        .toList();
    final nextShift = upcoming.isEmpty ? null : upcoming.first;

    final monthStats = StatisticsService.getMonthlyStatistics(
      mine,
      today.year,
      today.month,
      config.userId,
      members,
      shiftDurationHours: config.shiftDurationHours.toDouble(),
    );

    final nightToday = mine.where((s) =>
        s.isWorking &&
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: _Header(config: config, nightToday: nightToday.isNotEmpty),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  child: _NextShiftCard(
                    nextShift: nextShift,
                    members: members,
                    config: config,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  child: _WeekStrip(shifts: mine),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          value: '${monthStats.totalNights}',
                          label: 'nuits ce mois',
                          icon: Icons.nightlight_round,
                          accent: AppColors.shiftEnd,
                          hint: DateFormat('MMMM', 'fr_FR').format(today),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MetricCard(
                          value: '${monthStats.totalHours.toStringAsFixed(0)}h',
                          label: 'heures cumulées',
                          icon: Icons.timelapse_rounded,
                          accent: AppColors.nightTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MetricCard(
                          value: '${monthStats.weekendAnalysis.fullWeekendsWorked}',
                          label: 'week-ends',
                          icon: Icons.weekend_outlined,
                          accent: AppColors.vacationStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Importer',
                          icon: Icons.upload_file_rounded,
                          onPressed: () => _openImport(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timeline_rounded, size: 19),
                          label: const Text('Mes stats'),
                          onPressed: () =>
                              ref.read(selectedTabProvider.notifier).state = 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _UpcomingList(
                    shifts: upcoming.take(4).toList(),
                    members: members,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserConfig config;
  final bool tonight;

  const _Header({required this.config, required this.tonight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE d MMMM', 'fr_FR').format(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toTitleCase(dateLabel),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                tonight ? 'Bonne garde ce soir 🌙' : 'Bonjour ${config.userName.isEmpty ? config.userTrigramme : config.userName}',
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        InitialsAvatar(
          name: config.userName.isEmpty ? config.userTrigramme : config.userName,
          size: 44,
        ),
      ],
    );
  }
}

class _NextShiftCard extends StatelessWidget {
  final NightShift? nextShift;
  final List<TeamMember> members;
  final UserConfig config;

  const _NextShiftCard({
    required this.nextShift,
    required this.members,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = nextShift;

    if (shift == null) {
      return SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.vacationStart, size: 20),
                const SizedBox(width: 8),
                Text('Aucune garde à venir', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Importez le planning du mois pour retrouver vos nuits et vos collègues.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final coWorkers =
        members.where((m) => shift.coWorkerIds.contains(m.id)).toList();
    final now = DateTime.now();
    final start = shift.startDateTime;
    final daysUntil = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    final countdown = switch (daysUntil) {
      0 => 'Ce soir',
      1 => 'Demain',
      _ => 'Dans $daysUntil jours',
    };

    final dateLabel = toTitleCase(
      DateFormat('EEEE d MMMM', 'fr_FR').format(shift.date),
    );

    return SurfaceCard(
      gradient: AppColors.shiftGradient,
      glow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  countdown.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.nightlight_round,
                  color: Colors.white.withValues(alpha: 0.9), size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Prochaine garde',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _infoChip(
                Icons.schedule_rounded,
                '${_hhmm(shift.startTime)} – ${_hhmm(shift.endTime)}',
              ),
              const SizedBox(width: 8),
              _infoChip(
                Icons.timelapse_rounded,
                '${shift.durationHours.toStringAsFixed(0)}h',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (coWorkers.isEmpty)
                Text(
                  'Seul de garde',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...[
                SizedBox(
                  width: (coWorkers.length.clamp(1, 4) * 22).toDouble() + 12,
                  height: 32,
                  child: Stack(
                    children: [
                      for (var i = 0; i < coWorkers.length.clamp(0, 4); i++)
                        Positioned(
                          left: i * 20.0,
                          child: InitialsAvatar(
                            name: coWorkers[i].firstName.isEmpty
                                ? coWorkers[i].trigramme
                                : coWorkers[i].firstName,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coWorkers.length == 1
                        ? 'Avec ${_firstName(coWorkers.first)}'
                        : 'Avec ${_firstName(coWorkers.first)} +${coWorkers.length - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<NightShift> shifts;

  const _WeekStrip({required this.shifts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('Les 7 prochains jours', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _DayCell(
                    day: day,
                    shift: shifts.firstWhere(
                      (s) =>
                          s.date.year == day.year &&
                          s.date.month == day.month &&
                          s.date.day == day.day,
                      orElse: () => _emptyShift(day),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static NightShift _emptyShift(DateTime day) => NightShift(
        id: 'empty',
        date: day,
        agentId: '',
        agentTrigramme: '',
        startTime: const TimeOfDay(hour: 0, minute: 0),
        endTime: const TimeOfDay(hour: 0, minute: 0),
        isWorking: false,
      );
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final NightShift shift;

  const _DayCell({required this.day, required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isSameDay(day, DateTime.now());
    final hasShift = shift.id != 'empty';

    final color = shift.isWorking
        ? AppColors.shiftEnd
        : (shift.isVacation ? AppColors.vacationStart : null);

    return Column(
      children: [
        Text(
          DateFormat('E', 'fr_FR').format(day).substring(0, 1).toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasShift && color != null
                ? color.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isToday
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (hasShift)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color ?? Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final List<NightShift> shifts;
  final List<TeamMember> members;

  const _UpcomingList({required this.shifts, required this.members});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (shifts.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded,
                color: theme.colorScheme.secondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucune garde planifiée pour les prochains jours.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'À venir'),
        for (final shift in shifts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.shiftGradient,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${shift.date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toTitleCase(
                            DateFormat('EEEE d MMMM', 'fr_FR').format(shift.date),
                          ),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${_hhmm(shift.startTime)} – ${_hhmm(shift.endTime)}  •  '
                          '${shift.durationHours.toStringAsFixed(0)}h',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    label: '${shift.coWorkerIds.length} collègue${shift.coWorkerIds.length > 1 ? 's' : ''}',
                    color: AppColors.vacationStart,
                    icon: Icons.groups_rounded,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ helpers

void _openImport(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
  );
}

String _hhmm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _firstName(TeamMember member) =>
    member.firstName.isEmpty ? member.trigramme : member.firstName;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String toTitleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
