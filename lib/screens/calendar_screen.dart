import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'import_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nightShiftsAsync = ref.watch(allNightShiftsProvider);
    final userConfigAsync = ref.watch(userConfigProvider);
    final teamMembersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => _goToToday(),
            tooltip: "Aujourd'hui",
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

              // Filter shifts for current user (working shifts AND vacations)
              final userShifts = allShifts
                  .where((s) =>
                      (s.agentId == userConfig.userId ||
                       s.agentTrigramme.toUpperCase() == userConfig.userTrigramme.toUpperCase() ||
                       s.agentTrigramme.toUpperCase() == userConfig.userName.toUpperCase()) &&
                      (s.isWorking || s.isVacation))
                  .toList();

              // Create a map of date -> shift for quick lookup
              final shiftsMap = <DateTime, NightShift>{};
              // Add vacation shifts first
              for (final shift in userShifts.where((s) => s.isVacation)) {
                final dateKey = DateTime(shift.date.year, shift.date.month, shift.date.day);
                shiftsMap[dateKey] = shift;
              }
              // Add working shifts (working shifts take priority if on same date)
              for (final shift in userShifts.where((s) => s.isWorking)) {
                final dateKey = DateTime(shift.date.year, shift.date.month, shift.date.day);
                shiftsMap[dateKey] = shift;
              }

              // Initialize focusedDay to first worked day if not already initialized
              if (!_initialized && userShifts.isNotEmpty) {
                final firstShiftDate = userShifts
                    .map((s) => s.date)
                    .reduce((a, b) => a.isBefore(b) ? a : b);
                _focusedDay = DateTime(firstShiftDate.year, firstShiftDate.month, 1);
                _initialized = true;
              }

              return Column(
                children: [
                  _buildCalendar(theme, shiftsMap, teamMembers),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const StatusLegend(),
                  ),
                  const SizedBox(height: 12),
                  _buildDayDetails(theme, shiftsMap, userConfig, teamMembers),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Map<DateTime, NightShift> shiftsMap, List<TeamMember> teamMembers) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: TableCalendar<NightShift>(
          locale: 'fr_FR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.monday,
          daysOfWeekHeight: 32.0,
          rowHeight: 46.0,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            final dateKey = DateTime(day.year, day.month, day.day);
            final shift = shiftsMap[dateKey];
            return shift != null ? [shift] : [];
          },
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: theme.colorScheme.error),
            holidayTextStyle: TextStyle(color: theme.colorScheme.error),
            markersMaxCount: 0,
            markerDecoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonDecoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            formatButtonTextStyle: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
            ),
            titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                const TextStyle(fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.onSurface,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekendStyle: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
            weekdayStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) => const SizedBox.shrink(),
            defaultBuilder: (context, day, focusedDay) {
              final dateKey = DateTime(day.year, day.month, day.day);
              final shift = shiftsMap[dateKey];
              if (shift != null) {
                if (shift.isVacation) {
                  return _buildVacationDayCell(theme, day);
                }
                return _buildWorkedDayCell(theme, day);
              }
              return null;
            },
            todayBuilder: (context, day, focusedDay) {
              final dateKey = DateTime(day.year, day.month, day.day);
              final shift = shiftsMap[dateKey];
              final isWorking = shift != null && shift.isWorking;
              final isVacation = shift != null && shift.isVacation;
              return _buildTodayCell(theme, day, isWorking, isVacation);
            },
            selectedBuilder: (context, day, focusedDay) {
              final dateKey = DateTime(day.year, day.month, day.day);
              final shift = shiftsMap[dateKey];
              final isWorking = shift != null && shift.isWorking;
              final isVacation = shift != null && shift.isVacation;
              return _buildSelectedCell(theme, day, isWorking, isVacation);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWorkedDayCell(ThemeData theme, DateTime day) {
    return _dayCell(
      day: day,
      gradient: AppColors.shiftGradient,
      textColor: Colors.white,
    );
  }

  Widget _buildVacationDayCell(ThemeData theme, DateTime day) {
    return _dayCell(
      day: day,
      gradient: AppColors.vacationGradient,
      textColor: Colors.white,
    );
  }

  Widget _buildTodayCell(
    ThemeData theme,
    DateTime day,
    bool isWorking,
    bool isVacation,
  ) {
    final hasStatus = isWorking || isVacation;
    return _dayCell(
      day: day,
      gradient: isWorking
          ? AppColors.shiftGradient
          : (isVacation ? AppColors.vacationGradient : null),
      background: hasStatus
          ? null
          : theme.colorScheme.primary.withValues(alpha: 0.12),
      textColor: hasStatus ? Colors.white : theme.colorScheme.primary,
      border: Border.all(color: theme.colorScheme.primary, width: 1.6),
    );
  }

  Widget _buildSelectedCell(
    ThemeData theme,
    DateTime day,
    bool isWorking,
    bool isVacation,
  ) {
    return _dayCell(
      day: day,
      gradient: isWorking
          ? AppColors.shiftGradient
          : (isVacation ? AppColors.vacationGradient : AppColors.aurora),
      textColor: Colors.white,
      glow: true,
    );
  }

  /// Cellule de calendrier commune (nuit / congé / aujourd'hui / sélection).
  Widget _dayCell({
    required DateTime day,
    Gradient? gradient,
    Color? background,
    required Color textColor,
    BoxBorder? border,
    bool glow = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(3.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: border,
        boxShadow: glow && gradient != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildDayDetails(ThemeData theme, Map<DateTime, NightShift> shiftsMap, UserConfig userConfig, List<TeamMember> teamMembers) {
    if (_selectedDay == null) {
      return const SizedBox.shrink();
    }

    final dateKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final shift = shiftsMap[dateKey];
    final isDark = theme.brightness == Brightness.dark;

    String formattedDate;
    try {
      final raw = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDay!);
      formattedDate = raw.isNotEmpty ? raw[0].toUpperCase() + raw.substring(1) : raw;
    } catch (_) {
      formattedDate = '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}';
    }
    final timeFormat = DateFormat('HH:mm');

    final bool isWorking = shift != null && shift.isWorking;
    final bool isVacation = shift != null && shift.isVacation;
    final String vacationType = isVacation ? shift.vacationType : '';

    final Color accentColor = isWorking
        ? AppColors.shiftEnd
        : (isVacation ? AppColors.vacationStart : theme.colorScheme.onSurfaceVariant);

    final String badgeText = isWorking
        ? 'Nuit de garde'
        : (isVacation ? 'Congés ($vacationType)' : 'Repos');

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.82),
                    isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.45),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.45)
                      : accentColor.withValues(alpha: 0.35),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Date & Status Glass Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: isDark ? Colors.white : accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (isVacation) ...[
                      // Vacation Glass Block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.vacationStart.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.vacationStart.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.vacationStart.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.beach_access, color: AppColors.vacationStart, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getVacationLabel(vacationType),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.vacationStart,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Journée de congés posée. Aucune garde de nuit programmée.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isWorking) ...[
                      // Shift Hours Glass Block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.shiftEnd.withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.shiftEnd.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.shiftEnd.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.nightlight_round, color: AppColors.shiftEnd, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${timeFormat.format(DateTime(0, 1, 1, shift.startTime.hour, shift.startTime.minute))} — '
                              '${timeFormat.format(DateTime(0, 1, 1, shift.endTime.hour, shift.endTime.minute))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${shift.durationHours.toStringAsFixed(0)}h',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Coworkers Section
                      _buildSectionHeader(theme, 'Équipe en poste ce soir', Icons.groups_outlined),
                      const SizedBox(height: 10),

                      if (shift.coWorkerIds.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: shift.coWorkerIds.map((id) {
                            final colleague = teamMembers.firstWhere(
                              (m) => m.id == id,
                              orElse: () => TeamMember(
                                id: id,
                                firstName: id,
                                lastName: '',
                                trigramme: id,
                              ),
                            );
                            return _buildColleagueBadge(theme, colleague);
                          }).toList(),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: isDark ? 0.14 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.person_outline, color: AppColors.warning, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Seul de garde cette nuit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (shift.isManualOverride) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          theme,
                          Icons.edit,
                          'Modification manuelle',
                          'Cette garde a été modifiée manuellement',
                          valueColor: theme.colorScheme.tertiary,
                        ),
                      ],
                    ] else ...[
                      // Repos Glass Block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.vacationStart.withValues(alpha: isDark ? 0.12 : 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.vacationStart.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.vacationStart.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.beach_access, size: 24, color: AppColors.vacationStart),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jour de repos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Aucune garde prévue pour cette date.',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Glass Action Buttons
                    if (shift != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Modifier'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _showEditShiftDialog(shift),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Supprimer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _confirmDeleteShift(shift),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter une garde'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _showAddShiftDialog(dateKey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getVacationLabel(String vacationType) {
    switch (vacationType) {
      case 'CA':
        return 'Congés Annuels (CA)';
      case 'CET':
        return 'Compte Épargne Temps (CET)';
      case 'CFR':
        return 'Congés Fractionnés (CFR)';
      case 'REPOS':
        return 'Jour de repos';
      default:
        return 'Vacances ($vacationType)';
    }
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildColleagueBadge(ThemeData theme, TeamMember colleague) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.shiftEnd,
            child: Text(
              colleague.trigramme.isNotEmpty
                  ? colleague.trigramme.substring(0, 1).toUpperCase()
                  : colleague.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            colleague.firstName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
          const SizedBox(height: 16),
          GradientButton(
            label: 'Importer un planning',
            icon: Icons.upload_file_rounded,
            expand: false,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  void _showAddShiftDialog(DateTime date) => _showShiftEditor(date: date);

  void _showEditShiftDialog(NightShift shift) =>
      _showShiftEditor(date: shift.date, shift: shift);

  /// Création / modification manuelle d'une garde.
  ///
  /// La garde est marquée `isManualOverride: true` et n'est jamais écrasée
  /// silencieusement : un ré-import du même mois reste possible mais l'aperçu
  /// affiche le même identifiant, donc la saisie manuelle est bien la dernière
  /// opération enregistrée.
  Future<void> _showShiftEditor({
    required DateTime date,
    NightShift? shift,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final config = db.getUserConfig();

    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurez d\'abord votre profil')),
      );
      return;
    }

    final teamMembers = db.getAllTeamMembers();
    final day = DateTime(date.year, date.month, date.day);

    var startTime = shift?.startTime ?? config.shiftStartTime;
    var endTime = shift?.endTime ?? config.shiftEndTime;
    var isWorking = shift?.isWorking ?? true;
    var vacationType = 'CA';
    if (shift != null && shift.isVacation && shift.vacationType.isNotEmpty) {
      vacationType = shift.vacationType;
    }
    final coWorkers = <String>{...?shift?.coWorkerIds};

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: context,
              initialTime: isStart ? startTime : endTime,
            );
            if (picked != null) {
              setLocalState(() {
                if (isStart) {
                  startTime = picked;
                } else {
                  endTime = picked;
                }
              });
            }
          }

          String format(TimeOfDay t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text(
              '${shift == null ? 'Ajouter' : 'Modifier'} - '
              '${DateFormat('EEEE d MMMM', 'fr_FR').format(day)}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Je travaille cette nuit'),
                      value: isWorking,
                      onChanged: (value) =>
                          setLocalState(() => isWorking = value),
                    ),
                    if (isWorking) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.login, size: 18),
                              label: Text(format(startTime)),
                              onPressed: () => pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout, size: 18),
                              label: Text(format(endTime)),
                              onPressed: () => pickTime(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Collègues en poste',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: teamMembers
                            .where((m) => m.trigramme != config.userTrigramme)
                            .map(
                              (member) => FilterChip(
                                label: Text(member.trigramme),
                                selected: coWorkers.contains(member.id),
                                onSelected: (selected) {
                                  setLocalState(() {
                                    if (selected) {
                                      coWorkers.add(member.id);
                                    } else {
                                      coWorkers.remove(member.id);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: vacationType,
                        decoration:
                            const InputDecoration(labelText: 'Type d\'absence'),
                        items: const [
                          DropdownMenuItem(value: 'CA', child: Text('Congés annuels')),
                          DropdownMenuItem(value: 'CET', child: Text('Compte épargne temps')),
                          DropdownMenuItem(value: 'CFR', child: Text('Congés fractionnés')),
                          DropdownMenuItem(value: 'REPOS', child: Text('Repos')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => vacationType = value);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSave != true) return;

    final updated = NightShift(
      id: '${config.userId}_${day.year}_${day.month}_${day.day}',
      date: day,
      agentId: config.userId,
      agentTrigramme: config.userTrigramme,
      startTime: startTime,
      endTime: endTime,
      isWorking: isWorking,
      coWorkerIds: isWorking ? coWorkers.toList() : const [],
      isManualOverride: true,
      isVacation: !isWorking,
      vacationType: isWorking ? '' : vacationType,
    );

    await db.saveNightShift(updated);
    ref.invalidate(allNightShiftsProvider);

    if (config.notificationsEnabled) {
      await NotificationService().rescheduleAllNotifications(
        userId: config.userId,
        shiftStartTime: config.shiftStartTime,
        notificationDelayMinutes: config.notificationDelayMinutes,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isWorking ? 'Garde enregistrée' : 'Absence enregistrée'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _confirmDeleteShift(NightShift shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la garde'),
        content: Text('Voulez-vous vraiment supprimer la garde du ${shift.date.day}/${shift.date.month} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteShift(shift);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShift(NightShift shift) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteNightShift(shift.id);
    await NotificationService().cancelShiftNotification(shift.id);
    ref.invalidate(allNightShiftsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Garde supprimée')),
      );
    }
  }
}