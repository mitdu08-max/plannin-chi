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
      body: NeonBackground(
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
                  child: _Header(config: config, tonight: nightToday.isNotEmpty),
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
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final dateLabel = toTitleCase(DateFormat('EEEE d MMMM', 'fr_FR').format(now));
    final name = config.userName.isEmpty ? config.userTrigramme : config.userName;
    final lime = isDark ? AppColors.neonLime : AppColors.daySecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TechLabel(dateLabel, size: 9.5, letterSpacing: 1.8),
              const SizedBox(height: 7),
              Text(
                tonight ? 'Garde ce soir' : 'Bonjour $name',
                style: theme.textTheme.displaySmall,
              ),
              if (tonight) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const PulseDot(color: AppColors.neonLime),
                    const SizedBox(width: 7),
                    TechLabel(
                      'En service cette nuit',
                      size: 8.5,
                      color: lime,
                      letterSpacing: 1.2,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        InitialsAvatar(name: name, size: 42),
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
    final isDark = theme.brightness == Brightness.dark;
    final shift = nextShift;
    final primary = theme.colorScheme.primary;
    final lime = isDark ? AppColors.neonLime : AppColors.daySecondary;

    if (shift == null) {
      return SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: lime, size: 18),
                const SizedBox(width: 8),
                TechLabel(
                  'Aucune garde à venir',
                  size: 10,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 1.2,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      _ => 'Dans $daysUntil j',
    };

    final dateLabel = toTitleCase(
      DateFormat('EEEE d MMMM', 'fr_FR').format(shift.date),
    );

    return SurfaceCard(
      brackets: true,
      glow: true,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: isDark ? 0.13 : 0.07),
          primary.withValues(alpha: isDark ? 0.02 : 0.01),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TechLabel(
                  'Prochaine garde',
                  size: 9,
                  color: primary,
                  letterSpacing: 2.2,
                ),
                const SizedBox(height: 12),
                Text(
                  dateLabel.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.monoText(
                    size: 15,
                    weight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 0.4,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _hhmm(shift.startTime),
                      style: AppFonts.monoText(
                        size: 34,
                        weight: FontWeight.w800,
                        color: lime,
                        letterSpacing: -1.2,
                        height: 1,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: lime.withValues(alpha: 0.45),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      child: Text(
                        '→ ${_hhmm(shift.endTime)}',
                        style: AppFonts.monoText(
                          size: 13,
                          weight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${shift.durationHours.toStringAsFixed(0)}H',
                      style: AppFonts.tag(
                        size: 10,
                        color: primary,
                        weight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: theme.colorScheme.outline),
                const SizedBox(height: 11),
                if (coWorkers.isEmpty)
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      TechLabel(
                        'Seul de garde',
                        size: 9,
                        letterSpacing: 1.4,
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final member in coWorkers.take(3))
                        _crewTag(context, _firstName(member)),
                      if (coWorkers.length > 3)
                        _crewTag(context, '+${coWorkers.length - 3}'),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lime,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                countdown.toUpperCase(),
                style: AppFonts.tag(
                  size: 8.5,
                  color: AppColors.neonInk,
                  weight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crewTag(BuildContext context, String label) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: primary.withValues(alpha: 0.38)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppFonts.tag(
          size: 9,
          color: primary,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Container(width: 5, height: 5, color: theme.colorScheme.secondary),
                const SizedBox(width: 7),
                TechLabel(
                  '7 prochains jours',
                  size: 9,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 1.8,
                ),
              ],
            ),
          ),
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
    final isDark = theme.brightness == Brightness.dark;
    final isToday = _isSameDay(day, DateTime.now());
    final hasShift = shift.id != 'empty';

    final color = shift.isWorking
        ? AppColors.shiftEnd
        : (shift.isVacation ? AppColors.vacationStart : null);
    final lime = isDark ? AppColors.neonLime : AppColors.daySecondary;

    return Column(
      children: [
        TechLabel(
          DateFormat('E', 'fr_FR').format(day).substring(0, 1),
          size: 8,
          letterSpacing: 0.8,
          color: isToday ? theme.colorScheme.primary : null,
        ),
        const SizedBox(height: 5),
        Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasShift && color != null
                ? color.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isToday
                  ? theme.colorScheme.primary
                  : (hasShift && color != null
                      ? color.withValues(alpha: 0.35)
                      : Colors.transparent),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: AppFonts.monoText(
                  size: 13,
                  weight: FontWeight.w800,
                  color: isToday ? lime : theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (hasShift) ...[
                const SizedBox(height: 3),
                Container(
                  width: 9,
                  height: 2,
                  color: color ?? Colors.transparent,
                ),
              ],
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
    final isDark = theme.brightness == Brightness.dark;
    final lime = isDark ? AppColors.neonLime : AppColors.daySecondary;

    if (shifts.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded,
                color: theme.colorScheme.primary, size: 18),
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
        SectionHeader(
          title: 'À venir',
          trailing: TechLabel(
            '${shifts.length}',
            size: 9,
            color: lime,
            letterSpacing: 1,
          ),
        ),
        for (final shift in shifts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 56,
                    color: AppColors.shiftEnd,
                  ),
                  const SizedBox(width: 11),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${shift.date.day}'.padLeft(2, '0'),
                      textAlign: TextAlign.center,
                      style: AppFonts.monoText(
                        size: 18,
                        weight: FontWeight.w800,
                        color: lime,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toTitleCase(
                            DateFormat('EEE d MMM', 'fr_FR').format(shift.date),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        TechLabel(
                          '${_hhmm(shift.startTime)} → ${_hhmm(shift.endTime)} · '
                          '${shift.durationHours.toStringAsFixed(0)}h',
                          size: 8.5,
                          letterSpacing: 0.8,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10, left: 6),
                    child: Pill(
                      label: '${shift.coWorkerIds.length}',
                      color: AppColors.vacationStart,
                      icon: Icons.groups_rounded,
                    ),
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
