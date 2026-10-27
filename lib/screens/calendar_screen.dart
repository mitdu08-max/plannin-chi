import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'calendar_day_sheet.dart';
import 'import_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDay});

  /// Permet aussi d'ouvrir le calendrier sur une date précise dans les tests.
  final DateTime? initialDay;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDay ?? DateTime.now();
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
            onPressed: _goToToday,
            tooltip: "Aujourd'hui",
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
              data: (_) {
                if (userConfig == null) return _buildNotConfiguredState();
                final shiftsMap = _userShiftsByDay(allShifts, userConfig);
                return _buildCalendarPage(theme, shiftsMap);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPage(
    ThemeData theme,
    Map<DateTime, NightShift> shiftsMap,
  ) {
    // La grille occupe toute la hauteur disponible. En paysage ou sur un très
    // petit écran, un défilement conserve des cases faciles à toucher.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumHeight = _calendarFormat == CalendarFormat.month
              ? 430.0
              : 280.0;
          final height = constraints.hasBoundedHeight
              ? math.max(constraints.maxHeight, minimumHeight)
              : minimumHeight;
          return SingleChildScrollView(
            primary: false,
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: _buildCalendar(theme, shiftsMap),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const StatusLegend(),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Touchez un jour pour voir le détail',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Map<DateTime, NightShift> shiftsMap) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.88 : 0.94,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.10 : 0.12,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: TableCalendar<NightShift>(
        key: const ValueKey('calendar-grid'),
        locale: 'fr_FR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mois',
          CalendarFormat.twoWeeks: '2 sem.',
          CalendarFormat.week: 'Semaine',
        },
        shouldFillViewport: true,
        startingDayOfWeek: StartingDayOfWeek.monday,
        daysOfWeekHeight: 34,
        rangeSelectionMode: RangeSelectionMode.disabled,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showDayDetails(selectedDay);
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
        eventLoader: (day) {
          final shift = shiftsMap[_dateOnly(day)];
          return shift == null ? [] : [shift];
        },
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          markersMaxCount: 0,
          cellMargin: EdgeInsets.zero,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          titleCentered: true,
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
          leftChevronMargin: EdgeInsets.zero,
          rightChevronMargin: EdgeInsets.zero,
          leftChevronPadding: const EdgeInsets.all(8),
          rightChevronPadding: const EdgeInsets.all(8),
          formatButtonPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          formatButtonDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          formatButtonTextStyle: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
          titleTextStyle: theme.textTheme.titleMedium!.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: theme.colorScheme.onSurface,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppFonts.tag(
            size: 9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            weight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          weekendStyle: AppFonts.tag(
            size: 9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            weight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        calendarBuilders: CalendarBuilders<NightShift>(
          markerBuilder: (_, _, _) => const SizedBox.shrink(),
          defaultBuilder: (_, day, _) =>
              _buildDayCell(theme, day, shiftsMap[_dateOnly(day)]),
          todayBuilder: (_, day, _) => _buildDayCell(
            theme,
            day,
            shiftsMap[_dateOnly(day)],
            isToday: true,
          ),
          selectedBuilder: (_, day, _) => _buildDayCell(
            theme,
            day,
            shiftsMap[_dateOnly(day)],
            isToday: isSameDay(day, DateTime.now()),
            isSelected: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    ThemeData theme,
    DateTime day,
    NightShift? shift, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isWorking = shift?.isWorking ?? false;
    final isRest = shift?.isVacation == true && shift?.vacationType == 'REPOS';
    final isVacation = shift?.isVacation == true && !isRest;
    final accent = isWorking
        ? theme.colorScheme.primary
        : isVacation
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final label = isWorking
        ? 'NUIT'
        : isVacation
        ? shift!.vacationType
        : isRest
        ? 'REPOS'
        : '';
    final description = isWorking
        ? 'nuit de garde'
        : isVacation
        ? 'congé ${shift!.vacationType}'
        : isRest
        ? 'repos'
        : 'aucune garde enregistrée';
    final background = isWorking || isVacation || isRest
        ? accent.withValues(alpha: isDark ? 0.15 : 0.11)
        : isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : isToday
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : Colors.transparent;

    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        label:
            '${day.day}/${day.month}/${day.year}, $description${isToday ? ', aujourd’hui' : ''}',
        selected: isSelected,
        child: Container(
          key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isToday || isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (label.isNotEmpty && constraints.maxHeight >= 46) ...[
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: AppFonts.tag(
                        size: 8,
                        color: accent,
                        weight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDayDetails(DateTime day) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.32,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Consumer(
            builder: (context, ref, _) => ref
                .watch(allNightShiftsProvider)
                .when(
                  loading: () => _sheetMessage(scrollController, 'Chargement…'),
                  error: (_, _) => _sheetMessage(
                    scrollController,
                    'Impossible de charger les gardes.',
                  ),
                  data: (allShifts) => ref
                      .watch(userConfigProvider)
                      .when(
                        loading: () =>
                            _sheetMessage(scrollController, 'Chargement…'),
                        error: (_, _) => _sheetMessage(
                          scrollController,
                          'Impossible de charger le profil.',
                        ),
                        data: (config) => ref
                            .watch(teamMembersProvider)
                            .when(
                              loading: () => _sheetMessage(
                                scrollController,
                                'Chargement…',
                              ),
                              error: (_, _) => _sheetMessage(
                                scrollController,
                                'Impossible de charger l’équipe.',
                              ),
                              data: (members) {
                                if (config == null) {
                                  return _sheetMessage(
                                    scrollController,
                                    'Profil non configuré.',
                                  );
                                }
                                final shift = _userShiftsByDay(
                                  allShifts,
                                  config,
                                )[_dateOnly(day)];
                                return CalendarDaySheet(
                                  key: const ValueKey('calendar-day-sheet'),
                                  day: day,
                                  shift: shift,
                                  colleagues: _colleaguesForDay(
                                    day,
                                    shift,
                                    allShifts,
                                    config,
                                    members,
                                  ),
                                  scrollController: scrollController,
                                  onClose: () =>
                                      Navigator.of(sheetContext).pop(),
                                  onAdd: () => _showAddShiftDialog(day),
                                  onEdit: () {
                                    if (shift != null)
                                      _showEditShiftDialog(shift);
                                  },
                                  onDelete: () {
                                    if (shift != null)
                                      _confirmDeleteShift(shift);
                                  },
                                );
                              },
                            ),
                      ),
                ),
          ),
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  Widget _sheetMessage(ScrollController controller, String message) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: ListView(
        controller: controller,
        children: [
          const SizedBox(height: 36),
          Center(child: Text(message)),
        ],
      ),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _belongsToUser(NightShift shift, UserConfig config) {
    if (shift.agentId == config.userId) return true;
    final agent = shift.agentTrigramme.trim().toUpperCase();
    if (agent.isEmpty) return false;
    final trigramme = config.userTrigramme.trim().toUpperCase();
    final name = config.userName.trim().toUpperCase();
    return (trigramme.isNotEmpty && agent == trigramme) ||
        (name.isNotEmpty && agent == name);
  }

  static Map<DateTime, NightShift> _userShiftsByDay(
    List<NightShift> shifts,
    UserConfig config,
  ) {
    final result = <DateTime, NightShift>{};
    for (final shift in shifts) {
      if (!_belongsToUser(shift, config) ||
          (!shift.isWorking && !shift.isVacation)) {
        continue;
      }
      final date = _dateOnly(shift.date);
      if (!result.containsKey(date) || shift.isWorking) result[date] = shift;
    }
    return result;
  }

  static List<TeamMember> _colleaguesForDay(
    DateTime day,
    NightShift? shift,
    List<NightShift> allShifts,
    UserConfig config,
    List<TeamMember> members,
  ) {
    final ids = <String>{};
    if (shift?.isWorking == true) {
      ids.addAll(shift!.coWorkerIds);
    } else {
      ids.addAll(
        allShifts
            .where(
              (item) =>
                  item.isWorking &&
                  isSameDay(item.date, day) &&
                  !_belongsToUser(item, config),
            )
            .map((item) => item.agentId),
      );
    }
    ids.removeWhere((id) {
      final normalized = id.trim().toUpperCase();
      final userTrigramme = config.userTrigramme.trim().toUpperCase();
      return normalized.isEmpty ||
          id == config.userId ||
          (userTrigramme.isNotEmpty && normalized == userTrigramme);
    });
    return ids
        .map(
          (id) => members.firstWhere(
            (member) => member.id == id || member.trigramme == id,
            orElse: () =>
                TeamMember(id: id, firstName: id, lastName: '', trigramme: id),
          ),
        )
        .toList();
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
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          TechLabel(
            'Profil non configuré',
            size: 11,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 2,
          ),
          const SizedBox(height: 8),
          Text(
            'Configurez votre profil dans l\'onglet Import',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
  /// La garde est marquée `isManualOverride: true`. Un ré-import du même mois
  /// peut la remplacer après la confirmation explicite de l'utilisateur.
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
                        decoration: const InputDecoration(
                          labelText: 'Type d\'absence',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CA',
                            child: Text('Congés annuels'),
                          ),
                          DropdownMenuItem(
                            value: 'CET',
                            child: Text('Compte épargne temps'),
                          ),
                          DropdownMenuItem(
                            value: 'CFR',
                            child: Text('Congés fractionnés'),
                          ),
                          DropdownMenuItem(
                            value: 'REPOS',
                            child: Text('Repos'),
                          ),
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
      // Conserver l'identifiant d'une entrée existante, même si elle provient
      // d'un ancien import dont l'id diffère de celui du profil actif.
      id: shift?.id ?? '${config.userId}_${day.year}_${day.month}_${day.day}',
      date: day,
      agentId: shift?.agentId ?? config.userId,
      agentTrigramme: shift?.agentTrigramme ?? config.userTrigramme,
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
          content: Text(
            isWorking ? 'Garde enregistrée' : 'Absence enregistrée',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _confirmDeleteShift(NightShift shift) {
    final entry = shift.isWorking
        ? 'la garde'
        : shift.vacationType == 'REPOS'
        ? 'le repos'
        : 'le congé';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer $entry'),
        content: Text(
          'Voulez-vous vraiment supprimer $entry du ${shift.date.day}/${shift.date.month} ?',
        ),
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
    try {
      await NotificationService().cancelShiftNotification(shift.id);
    } catch (error) {
      debugPrint('Annulation du rappel impossible : $error');
    }
    ref.invalidate(allNightShiftsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrée supprimée')));
    }
  }
}
