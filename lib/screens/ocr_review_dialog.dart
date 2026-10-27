import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/planning_day_review.dart';

/// Vérification obligatoire d'une ligne de planning lue dans une image.
class OcrReviewDialog extends StatefulWidget {
  const OcrReviewDialog({
    super.key,
    required this.agent,
    required this.year,
    required this.month,
    required this.detectedCodes,
    this.imagePaths = const [],
  });

  final String agent;
  final int year;
  final int month;
  final Map<int, String> detectedCodes;
  final List<String> imagePaths;

  @override
  State<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends State<OcrReviewDialog> {
  late final PlanningDayReview _review;
  String _selectedCode = 'N';
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _review = PlanningDayReview(
      totalDays: DateTime(widget.year, widget.month + 1, 0).day,
      detected: widget.detectedCodes,
    );
  }

  Future<void> _showOriginal() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Document d’origine')),
          body: PageView.builder(
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              child: Center(
                child: Image.file(
                  File(widget.imagePaths[index]),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text('Image indisponible'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height - 32;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vérifier ${widget.agent}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppConstants.monthsFr[widget.month - 1]} ${widget.year}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comparez tous les jours avec le document : les cases « ? » '
                      'sont illisibles et même les autres peuvent être erronées. '
                      'Choisissez un code, puis touchez les jours à corriger.',
                    ),
                    if (widget.imagePaths.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _showOriginal,
                          icon: const Icon(Icons.zoom_in),
                          label: const Text('Voir le document et zoomer'),
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        for (final choice in PlanningDayReview.choices)
                          ChoiceChip(
                            label: Text(
                              choice == 'N'
                                  ? 'Nuit'
                                  : choice == 'R'
                                  ? 'Repos / autre'
                                  : choice,
                            ),
                            selected: _selectedCode == choice,
                            onSelected: (_) =>
                                setState(() => _selectedCode = choice),
                          ),
                      ],
                    ),
                    Text(
                      '« Repos / autre » ne crée ni garde ni congé. '
                      'Seuls CA, CET et CFR sont enregistrés comme congés.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_review.unresolvedCount > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _review.markUnresolvedAsOther();
                            _verified = false;
                          }),
                          child: Text(
                            'Mettre les ${_review.unresolvedCount} « ? » en repos / autre',
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Garder des cases confortables même sur un téléphone
                        // étroit, plutôt que de tasser sept colonnes illisibles.
                        final columns = ((constraints.maxWidth + 4) / 52)
                            .floor()
                            .clamp(1, 7);
                        return GridView.count(
                          crossAxisCount: columns,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          primary: false,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final entry in _review.days.entries)
                              _dayCell(entry.key, entry.value, colorScheme),
                          ],
                        );
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _verified,
                      title: const Text(
                        'J’ai vérifié tous les jours de cette ligne',
                      ),
                      onChanged: (value) =>
                          setState(() => _verified = value ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _review.isComplete && _verified
                        ? () => Navigator.of(context).pop(_review)
                        : null,
                    child: const Text('Continuer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int day, String code, ColorScheme colors) {
    final Color background;
    final Color foreground;
    if (code == PlanningDayReview.unknown) {
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
    } else if (code == 'N') {
      background = colors.primaryContainer;
      foreground = colors.onPrimaryContainer;
    } else if (code != PlanningDayReview.other) {
      background = colors.tertiaryContainer;
      foreground = colors.onTertiaryContainer;
    } else {
      background = colors.surfaceContainerHighest;
      foreground = colors.onSurface;
    }
    return Semantics(
      button: true,
      label: 'Jour $day, ${code == '?' ? 'non reconnu' : code}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() {
            _review.setDay(day, _selectedCode);
            _verified = false;
          }),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(code, style: TextStyle(color: foreground, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
