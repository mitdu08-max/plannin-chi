import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Fiche d'une journée, affichée au-dessus du calendrier dans une feuille modale.
/// Les données et les opérations restent gérées par l'écran parent.
class CalendarDaySheet extends StatelessWidget {
  const CalendarDaySheet({
    super.key,
    required this.day,
    required this.shift,
    required this.colleagues,
    required this.scrollController,
    required this.onClose,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime day;
  final NightShift? shift;
  final List<TeamMember> colleagues;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWorking = shift?.isWorking ?? false;
    final isRest = shift?.isVacation == true && shift?.vacationType == 'REPOS';
    final isVacation = shift?.isVacation == true && !isRest;
    final accent = isWorking
        ? (isDark ? AppColors.shiftEnd : AppColors.dayPrimary)
        : isVacation
        ? (isDark ? AppColors.vacationEnd : AppColors.daySecondary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final status = isWorking
        ? 'Nuit de garde'
        : isVacation
        ? 'Congés · ${shift!.vacationType}'
        : isRest
        ? 'Repos'
        : 'Aucune garde enregistrée';
    const radius = BorderRadius.vertical(top: Radius.circular(30));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF15232D) : Colors.white)
                  .withValues(alpha: isDark ? 0.84 : 0.86),
              borderRadius: radius,
              border: Border.all(
                color: (isDark ? Colors.white : theme.colorScheme.outline)
                    .withValues(alpha: isDark ? 0.18 : 0.35),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      key: const ValueKey('calendar-sheet-handle'),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DÉTAIL DU JOUR',
                              style: AppFonts.tag(
                                size: 9,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.72,
                                ),
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(day),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Fermer le détail',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        status,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (isWorking)
                    _informationCard(
                      context,
                      icon: Icons.nightlight_round,
                      accent: accent,
                      title: 'Horaires de garde',
                      detail:
                          '${_formatTime(shift!.startTime)} — ${_formatTime(shift!.endTime)}',
                      footnote: 'Durée : ${_formatDuration(shift!.duration)}',
                    )
                  else if (isVacation)
                    _informationCard(
                      context,
                      icon: Icons.beach_access_outlined,
                      accent: accent,
                      title: _vacationLabel(shift!.vacationType),
                      detail: 'Congé enregistré pour cette journée.',
                    )
                  else if (isRest)
                    _informationCard(
                      context,
                      icon: Icons.wb_twilight_rounded,
                      accent: accent,
                      title: 'Jour de repos',
                      detail: 'Repos enregistré pour cette journée.',
                    )
                  else
                    _informationCard(
                      context,
                      icon: Icons.event_available_outlined,
                      accent: accent,
                      title: 'Aucune garde enregistrée',
                      detail:
                          'Aucune garde ou absence n’est enregistrée pour cette date.',
                    ),
                  if (shift?.isManualOverride == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Modifié manuellement',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    isWorking ? 'Collègues avec toi' : 'Équipe en poste',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (colleagues.isEmpty)
                    Text(
                      'Aucun collègue enregistré pour cette date.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final member in colleagues)
                          _colleagueChip(context, member),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _actions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _informationCard(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String detail,
    String? footnote,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.09),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (footnote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    footnote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colleagueChip(BuildContext context, TeamMember member) {
    final theme = Theme.of(context);
    final name = member.firstName.trim().isNotEmpty
        ? member.firstName
        : member.trigramme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 70,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialsAvatar(name: name, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    if (shift == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter une garde'),
          style: ElevatedButton.styleFrom(shape: shape),
        ),
      );
    }

    final edit = OutlinedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Modifier'),
      style: OutlinedButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    final delete = OutlinedButton.icon(
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: const Text('Supprimer'),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.error,
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 320
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [edit, const SizedBox(height: 10), delete],
            )
          : Row(
              children: [
                Expanded(child: edit),
                const SizedBox(width: 10),
                Expanded(child: delete),
              ],
            ),
    );
  }

  static String _formatDate(DateTime day) {
    try {
      final date = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(day);
      return date.isEmpty
          ? date
          : '${date[0].toUpperCase()}${date.substring(1)}';
    } catch (_) {
      return '${day.day}/${day.month}/${day.year}';
    }
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0
        ? '$hours h'
        : '$hours h ${minutes.toString().padLeft(2, '0')}';
  }

  static String _vacationLabel(String code) {
    switch (code) {
      case 'CA':
        return 'Congés annuels (CA)';
      case 'CET':
        return 'Compte épargne temps (CET)';
      case 'CFR':
        return 'Congés fractionnés (CFR)';
      default:
        return 'Absence ($code)';
    }
  }
}
