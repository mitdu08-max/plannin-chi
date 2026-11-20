import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Boîte de dialogue permettant de remplir et d'enregistrer rapidement
/// un mois complet de gardes et congés (Avril, Mai, Juin, etc.)
/// directement sans passer par un scan ou OCR.
class QuickMonthEditorDialog extends ConsumerStatefulWidget {
  const QuickMonthEditorDialog({
    super.key,
    required this.initialYear,
    required this.initialMonth,
  });

  final int initialYear;
  final int initialMonth;

  @override
  ConsumerState<QuickMonthEditorDialog> createState() =>
      _QuickMonthEditorDialogState();
}

class _QuickMonthEditorDialogState
    extends ConsumerState<QuickMonthEditorDialog> {
  late int _year;
  late int _month;
  String _selectedCode = 'N'; // 'N', 'R', 'CA', 'CET', 'CFR'
  final Map<int, String> _days = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _loadExistingShifts();
  }

  int get _totalDays => DateTime(_year, _month + 1, 0).day;

  void _loadExistingShifts() {
    final db = ref.read(databaseServiceProvider);
    final userConfig = db.getUserConfig();
    final agentId = userConfig?.userId ?? '';

    _days.clear();
    for (var day = 1; day <= _totalDays; day++) {
      _days[day] = 'R';
    }

    if (agentId.isNotEmpty) {
      final existingShifts = db.getNightShiftsForMonth(_year, _month);
      for (final shift in existingShifts) {
        if (shift.agentId == agentId) {
          final day = shift.date.day;
          if (shift.isWorking) {
            _days[day] = 'N';
          } else if (shift.isVacation) {
            _days[day] = shift.vacationType ?? 'CA';
          }
        }
      }
    }
  }

  void _onMonthChanged(int month) {
    setState(() {
      _month = month;
      _loadExistingShifts();
    });
  }

  void _onYearChanged(int year) {
    setState(() {
      _year = year;
      _loadExistingShifts();
    });
  }

  void _toggleDay(int day) {
    setState(() {
      final current = _days[day] ?? 'R';
      if (current == _selectedCode) {
        _days[day] = 'R';
      } else {
        _days[day] = _selectedCode;
      }
    });
  }

  void _setAllToRest() {
    setState(() {
      for (var day = 1; day <= _totalDays; day++) {
        _days[day] = 'R';
      }
    });
  }

  Future<void> _saveMonth() async {
    final db = ref.read(databaseServiceProvider);
    final userConfig = db.getUserConfig();

    if (userConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil non configuré. Veuillez d’abord configurer votre profil.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final agentId = userConfig.userId;
      final trigramme = userConfig.userTrigramme;
      final startTime = userConfig.shiftStartTime;
      final endTime = userConfig.shiftEndTime;

      // 1. Supprimer les anciennes gardes de l'utilisateur pour ce mois
      await db.deleteNightShiftsForMonth(agentId, _year, _month);

      // Récupérer les gardes des collègues déjà en base sur ce mois
      final teamMonthShifts = db.getNightShiftsForMonth(_year, _month);

      // 2. Enregistrer les nuits et congés
      int nightsCount = 0;
      int vacationsCount = 0;

      for (final entry in _days.entries) {
        final day = entry.key;
        final code = entry.value;

        if (code == 'N') {
          nightsCount++;
          final coWorkerIds = teamMonthShifts
              .where((s) => s.agentId != agentId && s.date.day == day && s.isWorking)
              .map((s) => s.agentId)
              .toSet()
              .toList();
          final shift = NightShift(
            id: '${agentId}_${_year}_${_month}_$day',
            date: DateTime(_year, _month, day),
            agentId: agentId,
            agentTrigramme: trigramme,
            startTime: startTime,
            endTime: endTime,
            isWorking: true,
            coWorkerIds: coWorkerIds,
            isManualOverride: true,
          );
          await db.saveNightShift(shift);
        } else if (const {'CA', 'CET', 'CFR'}.contains(code)) {
          vacationsCount++;
          final shift = NightShift(
            id: '${agentId}_${_year}_${_month}_$day',
            date: DateTime(_year, _month, day),
            agentId: agentId,
            agentTrigramme: trigramme,
            startTime: startTime,
            endTime: endTime,
            isWorking: false,
            isVacation: true,
            vacationType: code,
            isManualOverride: true,
          );
          await db.saveNightShift(shift);
        }
      }

      // 3. Replanifier les notifications
      if (userConfig.notificationsEnabled) {
        try {
          await NotificationService().rescheduleAllNotifications(
            userId: agentId,
            shiftStartTime: startTime,
            notificationDelayMinutes: userConfig.notificationDelayMinutes,
          );
        } catch (_) {}
      }

      // 4. Rafraîchir les providers Riverpod
      ref.invalidate(allNightShiftsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            '${AppConstants.monthsFr[_month - 1]} $_year enregistré : '
            '$nightsCount nuit(s), $vacationsCount congé(s)',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erreur lors de l’enregistrement : $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalDays = _totalDays;

    final workingCount = _days.values.where((v) => v == 'N').length;
    final vacationCount =
        _days.values.where((v) => const {'CA', 'CET', 'CFR'}.contains(v)).length;

    final years = [
      for (var y = 2024; y <= 2030; y++) y,
    ];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre et sélecteur de mois / année
              Row(
                children: [
                  Icon(Icons.edit_calendar, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saisie rapide du mois',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sélecteurs Mois + Année
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(
                        labelText: 'Mois',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(AppConstants.monthsFr[i - 1]),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) _onMonthChanged(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Année',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: [
                        for (final y in years)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (val) {
                        if (val != null) _onYearChanged(val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Palette des codes
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _codeChip('N', '🌙 Nuit', colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
                  _codeChip('R', '⚪ Repos', colorScheme.surfaceContainerHighest, colorScheme.onSurface),
                  _codeChip('CA', '🏖️ CA', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
                  _codeChip('CET', '⏳ CET', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
                  _codeChip('CFR', '📑 CFR', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
                ],
              ),
              const SizedBox(height: 6),

              // Indication et bouton tout effacer
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Touchez un jour pour appliquer le code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Tout en repos'),
                    onPressed: _setAllToRest,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Grille des jours
              Flexible(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = ((constraints.maxWidth + 4) / 52)
                          .floor()
                          .clamp(1, 7);
                      return GridView.builder(
                        shrinkWrap: true,
                        primary: false,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: totalDays,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final code = _days[day] ?? 'R';
                          final date = DateTime(_year, _month, day);
                          final dayLetter = AppConstants.daysFr[date.weekday - 1].substring(0, 2);

                          final Color bg;
                          final Color fg;
                          if (code == 'N') {
                            bg = colorScheme.primaryContainer;
                            fg = colorScheme.onPrimaryContainer;
                          } else if (code == 'CA' || code == 'CET' || code == 'CFR') {
                            bg = colorScheme.tertiaryContainer;
                            fg = colorScheme.onTertiaryContainer;
                          } else {
                            bg = colorScheme.surfaceContainerHighest;
                            fg = colorScheme.onSurface;
                          }

                          return Material(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _toggleDay(day),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$dayLetter $day',
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      code == 'R' ? '—' : code,
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 11,
                                        fontWeight: code == 'N' ? FontWeight.w800 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Compteurs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '$workingCount nuit(s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$vacationCount congé(s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.tertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${totalDays - workingCount - vacationCount} repos',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Enregistrer le mois'),
                    onPressed: _isLoading ? null : _saveMonth,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeChip(String code, String label, Color bg, Color fg) {
    final isSelected = _selectedCode == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCode = code),
    );
  }
}
