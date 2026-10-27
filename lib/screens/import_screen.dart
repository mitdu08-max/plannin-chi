import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/pdf_parser_service.dart';
import '../services/ocr_parser_service.dart';
import '../services/pdf_image_renderer.dart';
import '../services/planning_day_review.dart';
import '../services/notification_service.dart';
import 'ocr_review_dialog.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ImportScreen extends ConsumerStatefulWidget {
  final bool isFirstLaunch;

  const ImportScreen({super.key, this.isFirstLaunch = false});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userConfigAsync = ref.watch(userConfigProvider);
    final teamMembersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer'),
        automaticallyImplyLeading: !widget.isFirstLaunch,
      ),
      body: NeonBackground(
        child: userConfigAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error),
        data: (userConfig) {
          final isConfigured = userConfig != null;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(theme, isConfigured, userConfig),

                    const SizedBox(height: 24),

                    // Import Options
                    if (isConfigured) ...[
                      _buildImportSection(theme),
                    ] else ...[
                      _buildSetupRequiredSection(theme, teamMembersAsync),
                    ],

                    const SizedBox(height: 24),

                    // Info card
                    _buildInfoCard(theme),
                  ],
                ),
              ),

              // Processing overlay
              if (_isProcessing) _buildProcessingOverlay(),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isConfigured, UserConfig? userConfig) {
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return SurfaceCard(
      brackets: true,
      glow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: isDark ? 0.12 : 0.07),
          primary.withValues(alpha: 0.0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: primary.withValues(alpha: 0.55)),
                  boxShadow: AppColors.glow(primary, blur: 18, alpha: 0.22),
                ),
                child: Icon(Icons.nightlight_round, size: 22, color: primary),
              ),
              const Spacer(),
              if (isConfigured && userConfig != null)
                TextButton(
                  onPressed: _showChangeUserDialog,
                  child: const Text('Changer'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.isFirstLaunch ? 'Bienvenue' : 'Importer un planning',
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.isFirstLaunch
                ? 'Chargez le planning de votre équipe pour commencer : vos nuits, vos collègues et vos rappels seront créés automatiquement.'
                : 'PDF officiel ou capture d\'écran du planning de l\'équipe.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          if (isConfigured && userConfig != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  InitialsAvatar(
                    name: userConfig.userTrigramme.isNotEmpty
                        ? userConfig.userTrigramme
                        : userConfig.userName,
                    size: 34,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userConfig.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        TechLabel(
                          'Profil actif · ${userConfig.userTrigramme}',
                          size: 8.5,
                          color: primary,
                          letterSpacing: 1.2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TechLabel(
          'Source du planning',
          size: 9.5,
          color: theme.colorScheme.onSurface,
          letterSpacing: 1.8,
        ),
        const SizedBox(height: 12),

        // PDF Import
        _buildImportOption(
          context,
          icon: Icons.picture_as_pdf_outlined,
          title: 'Fichier PDF',
          subtitle: 'Planning officiel au format PDF',
          onTap: _pickAndParsePdf,
        ),

        const SizedBox(height: 12),

        // Gallery / Screenshots Import (Main option)
        _buildImportOption(
          context,
          icon: Icons.photo_library_outlined,
          title: 'Galerie / Capture d\'écran',
          subtitle: 'Sélectionner un screenshot ou une photo (OCR)',
          onTap: () => _pickAndParseImage(fromGallery: true),
        ),

        const SizedBox(height: 12),

        // Camera Import (Secondary option)
        _buildImportOption(
          context,
          icon: Icons.camera_alt_outlined,
          title: 'Prendre une photo',
          subtitle: 'Photographier le planning directement (OCR)',
          onTap: () => _pickAndParseImage(fromGallery: false),
        ),
      ],
    );
  }

  Widget _buildSetupRequiredSection(ThemeData theme, AsyncValue<List<TeamMember>> teamMembersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TechLabel(
          'Configuration requise',
          size: 9.5,
          color: theme.colorScheme.onSurface,
          letterSpacing: 1.8,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil non configuré',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Importez d\'abord un planning pour détecter l\'équipe, puis sélectionnez votre nom.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Importer PDF'),
                        onPressed: _pickAndParsePdf,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galerie / Screenshot'),
                        onPressed: () => _pickAndParseImage(fromGallery: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: theme.colorScheme.secondary),
              const SizedBox(width: 7),
              TechLabel(
                'Format attendu',
                size: 9,
                color: theme.colorScheme.onSurface,
                letterSpacing: 1.6,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• Une colonne par jour, une ligne par agent ; un mois par fichier\n'
            '• N = nuit ; CA/CET/CFR = congés ; RH/R = repos\n'
            '• Pour une image ou un PDF scanné, confirmez le mois et vérifiez '
            'chaque jour sur le document. Le PDF original est préférable à une capture.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
          ),
        ],
      ),
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
            onPressed: () => ref.invalidate(userConfigProvider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _processingMessage,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== FILE PICKING & PARSING ==========

  Future<void> _pickAndParsePdf() async {
    var temporaryPages = <File>[];
    try {
      setProcessing(true, 'Sélection du fichier PDF...');

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) {
        setProcessing(false, '');
        return;
      }

      final path = files.first.path;
      if (path == null) {
        setProcessing(false, '');
        _showErrorSnackBar('Fichier inaccessible (chemin introuvable).');
        return;
      }

      setProcessing(true, 'Lecture du PDF...');
      var parseResult = await PdfParserService.parsePlanningPdfFile(File(path));
      if (parseResult.agentShifts.isEmpty) {
        // Un PDF scanné ne contient parfois aucun texte : rendre les pages en
        // haute résolution, puis utiliser le même OCR local que les photos.
        setProcessing(true, 'Lecture du PDF scanné (OCR local)...');
        temporaryPages = await PdfImageRenderer.renderPages(File(path));
        parseResult = await OcrParserService.parsePlanningImages(temporaryPages);
      }

      if (!mounted) return;
      setProcessing(false, '');
      await _showPreviewAndConfirm(
        parseResult,
        path,
        imagePaths: temporaryPages.map((file) => file.path).toList(),
      );
    } catch (e) {
      setProcessing(false, '');
      if (mounted) {
        _showErrorSnackBar('Erreur lors de l\'import PDF: $e');
      }
    } finally {
      await PdfImageRenderer.deleteTemporaryPages(temporaryPages);
    }
  }

  Future<void> _pickAndParseImage({bool fromGallery = true}) async {
    try {
      setProcessing(true, fromGallery ? 'Ouverture de la galerie...' : 'Ouverture de la caméra...');

      final pickedFile = await _imagePicker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (pickedFile == null) {
        setProcessing(false, '');
        return;
      }

      final file = File(pickedFile.path);
      setProcessing(true, 'Analyse de l\'image (OCR)...');

      final parseResult = await OcrParserService.parsePlanningImage(file);

      if (!mounted) return;
      setProcessing(false, '');
      await _showPreviewAndConfirm(
        parseResult,
        file.path,
        imagePaths: [file.path],
      );
    } catch (e) {
      setProcessing(false, '');
      if (mounted) {
        _showErrorSnackBar('Erreur lors de l\'import image: $e');
      }
    }
  }

  // ========== PREVIEW & CONFIRMATION ==========

  /// Résout l'agent correspondant à l'utilisateur configuré.
  String? _resolveCurrentAgent(UserConfig? userConfig, List<String> detectedAgents) {
    if (userConfig == null) return null;

    final trigramme = userConfig.userTrigramme.trim().toUpperCase();
    final name = userConfig.userName.trim().toUpperCase();

    for (final agent in detectedAgents) {
      final upper = agent.toUpperCase();
      if (trigramme.isNotEmpty && upper == trigramme) return agent;
      if (name.isNotEmpty && upper == name) return agent;
      // tolérance : "DUPONT" saisi pour l'agent "DUPONT J." ou inverse
      if (name.length >= 3 && upper.startsWith(name)) return agent;
    }
    return null;
  }

  /// Demande ou confirme le mois avant d'utiliser les dates reconnues.
  Future<(int, int)?> _askMonthAndYear({int? detectedYear, int? detectedMonth}) async {
    final now = DateTime.now();
    var year = detectedYear ?? now.year;
    var month = detectedMonth ?? now.month;
    final years = <int>{
      for (var y = 2020; y <= 2030; y++) y,
      for (var y = now.year - 2; y <= now.year + 2; y++) y,
      year,
    }.toList()..sort();

    return showDialog<(int, int)>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Mois du planning'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detectedYear == null || detectedMonth == null
                      ? 'Le mois n\'a pas pu être lu dans le document. Indiquez-le pour éviter une erreur.'
                      : 'Vérifiez le mois et l\'année lus sur le document avant de continuer.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: month,
                  decoration: const InputDecoration(labelText: 'Mois'),
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(AppConstants.monthsFr[i - 1]),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocalState(() => month = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(labelText: 'Année'),
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocalState(() => year = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop((year, month)),
                child: const Text('Continuer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPreviewAndConfirm(
    PlanningParseResult parsed,
    String sourcePath, {
    List<String> imagePaths = const [],
  }) async {
    var result = parsed;

    // L'OCR peut lire une autre date sur la page (signature, mois voisin).
    // Demander une confirmation explicite, même si un mois a été détecté.
    if (!result.monthDetected || result.isOcr) {
      final picked = await _askMonthAndYear(
        detectedYear: result.year,
        detectedMonth: result.month,
      );
      if (picked == null || !mounted) return;
      setProcessing(true, 'Nouvelle analyse avec le mois sélectionné...');
      result = PdfParserService.parsePlanningText(
        result.rawText,
        forcedYear: picked.$1,
        forcedMonth: picked.$2,
        ocrPages: result.ocrPages,
      );
      setProcessing(false, '');
    }

    final year = result.year!;
    final month = result.month!;
    final db = ref.read(databaseServiceProvider);
    final teamMembers = db.getAllTeamMembers();
    final userConfig = db.getUserConfig();
    final agentShifts = <String, List<int>>{
      for (final entry in result.agentShifts.entries)
        entry.key: List<int>.from(entry.value),
    };
    final agentVacations = <String, Map<int, String>>{
      for (final entry in result.agentVacations.entries)
        entry.key: Map<int, String>.from(entry.value),
    };

    // Si aucun nom n'est reconnu, on peut quand même vérifier et renseigner
    // sa ligne manuellement, y compris lors du tout premier import.
    String? manualAgent;
    if (agentShifts.isEmpty && result.isOcr) {
      final name = userConfig != null
          ? (userConfig.userTrigramme.isNotEmpty
              ? userConfig.userTrigramme
              : userConfig.userId)
          : await _askManualAgentName();
      if (!mounted || name == null || name.isEmpty) return;
      manualAgent = name;
      agentShifts[name] = <int>[];
    }
    if (agentShifts.isEmpty) {
      _showErrorSnackBar('Aucune donnée de planning détectée dans le fichier.');
      return;
    }

    var resolvedAgent = manualAgent ??
        _resolveCurrentAgent(userConfig, agentShifts.keys.toList());
    // Même une correspondance automatique de nom peut être fausse après OCR.
    // La sélection explicite protège le profil et ses autres mois.
    if (resolvedAgent == null || (result.isOcr && manualAgent == null)) {
      final manualProfile = result.isOcr && userConfig != null
          ? (userConfig.userTrigramme.isNotEmpty
              ? userConfig.userTrigramme
              : userConfig.userId)
          : null;
      resolvedAgent = await _showUserSelectionDialog(
        agentShifts.keys.toList(),
        manualProfile: manualProfile,
        allowManualEntry: result.isOcr,
        suggestedAgent: resolvedAgent,
      );
      if (resolvedAgent == null || !mounted) return;
      agentShifts.putIfAbsent(resolvedAgent, () => <int>[]);
    }
    final currentAgent = resolvedAgent;

    var importTeam = !result.isOcr;
    if (result.isOcr && agentShifts.length > 1) {
      final choice = await _showOcrImportScopeDialog(agentShifts.keys.toList());
      if (choice == null || !mounted) return;
      importTeam = choice;
    }

    // Une lecture OCR peut modifier l'orthographe d'un nom. Associez chaque
    // ligne à une identité unique et conservez le profil déjà configuré.
    TeamMember? configuredMember;
    if (result.isOcr && userConfig != null) {
      configuredMember = db.getTeamMemberById(userConfig.userId) ??
          TeamMember(
            id: userConfig.userId,
            firstName: userConfig.userName,
            lastName: '',
            trigramme: userConfig.userTrigramme,
          );
    }
    final selectedAgents = <String>[
      currentAgent,
      if (importTeam) ...agentShifts.keys.where((agent) => agent != currentAgent),
    ];
    final membersByAgent = <String, TeamMember>{};
    final usedIds = <String>{};
    for (final agent in selectedAgents) {
      TeamMember? member;
      if (agent == currentAgent && configuredMember != null) {
        member = configuredMember;
      } else {
        final matches = teamMembers.where((candidate) {
          final label = agent.trim().toUpperCase();
          return !usedIds.contains(candidate.id) &&
              (candidate.trigramme.trim().toUpperCase() == label ||
                  candidate.id.trim().toUpperCase() == label);
        }).toList();
        if (matches.length == 1 || (!result.isOcr && matches.isNotEmpty)) {
          member = matches.first;
        } else if (result.isOcr && teamMembers.isNotEmpty) {
          member = await _showOcrAgentMapping(
            agent,
            teamMembers.where((candidate) => !usedIds.contains(candidate.id)).toList(),
            canCreate: !usedIds.contains(agent) &&
                !teamMembers.any((candidate) => candidate.id == agent),
          );
          if (member == null || !mounted) return;
        } else {
          member = TeamMember(id: agent, firstName: agent, lastName: '', trigramme: agent);
        }
      }
      if (member.id.isEmpty || !usedIds.add(member.id)) {
        _showErrorSnackBar('Deux lignes correspondent au même profil. Import annulé.');
        return;
      }
      membersByAgent[agent] = member;
    }
    final currentUser = membersByAgent[currentAgent]!;
    final allTeamMembers = membersByAgent.values.toList();

    if (result.isOcr) {
      // La revue est obligatoire pour chaque ligne qui sera enregistrée. Cela
      // évite d'importer les jours manquants comme du repos sans confirmation.
      for (final agent in selectedAgents) {
        final member = membersByAgent[agent]!;
        final reviewLabel = member.trigramme == agent
            ? agent
            : '$agent → ${member.trigramme}';
        final reviewed = await showDialog<PlanningDayReview>(
          context: context,
          barrierDismissible: false,
          builder: (_) => OcrReviewDialog(
            agent: reviewLabel,
            year: year,
            month: month,
            detectedCodes: result.dayCodes[agent] ?? const {},
            imagePaths: imagePaths,
          ),
        );
        if (reviewed == null || !mounted) return;
        agentShifts[agent] = reviewed.workingDays;
        agentVacations[agent] = reviewed.vacations;
      }
    } else if ((agentShifts[currentAgent] ?? const <int>[]).isEmpty) {
      _showErrorSnackBar('Aucune nuit de garde détectée pour $currentAgent.');
      return;
    }

    final shiftStartTime = userConfig?.shiftStartTime ?? AppConstants.defaultShiftStartTime;
    final shiftEndTime = userConfig?.shiftEndTime ?? AppConstants.defaultShiftEndTime;
    final previewItems = <PreviewNightItem>[];
    for (final day in agentShifts[currentAgent] ?? const <int>[]) {
      final coWorkers = importTeam
          ? membersByAgent.entries
              .where((entry) => entry.key != currentAgent &&
                  (agentShifts[entry.key] ?? const <int>[]).contains(day))
              .map((entry) => entry.value)
              .toList()
          : <TeamMember>[];
      previewItems.add(
        PreviewNightItem(date: DateTime(year, month, day), coWorkers: coWorkers),
      );
    }
    final userVacations = agentVacations[currentAgent] ?? const <int, String>{};

    final warnings = result.isOcr
        ? <String>[
            if (!importTeam)
              'Seul votre planning sera importé ; les collègues ne sont pas déduits de cette image.',
            for (final warning in result.warnings)
              if (!agentShifts.keys.any((agent) => warning.startsWith('$agent :')))
                warning,
          ]
        : result.warnings;
    final confirmed = await _showPreviewDialog(
      agent: currentAgent,
      previewItems: previewItems,
      sourcePath: sourcePath,
      userVacations: userVacations,
      year: year,
      month: month,
      warnings: warnings,
      colleaguesImported: importTeam,
    );
    if (!confirmed || !mounted) return;

    final existingCount = membersByAgent.values
        .map((member) => member.id)
        .toSet()
        .fold<int>(0, (count, id) => count + db.countNightShiftsForMonth(id, year, month));
    if (existingCount > 0) {
      final replace = await _confirmMonthReplacement(existingCount, year, month);
      if (!replace || !mounted) return;
    }

    await _saveToDatabase(
      previewItems: previewItems,
      allTeamMembers: allTeamMembers,
      currentUser: currentUser,
      currentAgent: currentAgent,
      membersByAgent: membersByAgent,
      preserveExistingProfile: result.isOcr && userConfig != null,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
      year: year,
      month: month,
      userVacations: userVacations,
      allAgentShifts: importTeam ? agentShifts : null,
      allAgentVacations: importTeam ? agentVacations : null,
    );
  }

  /// Choisir son planning seul évite d'importer des lignes de collègues que
  /// l'on n'a pas vérifiées. L'import d'équipe demande ensuite une revue par agent.
  Future<bool?> _showOcrImportScopeDialog(List<String> agents) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Que souhaitez-vous importer ?'),
          content: SingleChildScrollView(
            child: Text(
              '${agents.length} ligne(s) détectée(s) : ${agents.join(', ')}.\n\n'
              'Des personnes peuvent manquer. Pour éviter les erreurs, chaque '
              'ligne importée devra être comparée au document.\n\n'
              '« Mon planning » n’importe pas les collègues. « Toute l’équipe » '
              'demande de vérifier chaque ligne détectée.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Mon planning'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Toute l’équipe'),
            ),
          ],
        ),
      );

  Future<bool> _confirmMonthReplacement(int count, int year, int month) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le planning existant ?'),
          content: Text(
            '$count entrée(s) existent déjà pour ${AppConstants.monthsFr[month - 1]} $year '
            'chez les personnes importées. Elles seront remplacées, y compris '
            'les corrections manuelles. Les autres mois ne seront pas effacés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      ) ?? false;

  Future<TeamMember?> _showOcrAgentMapping(
    String recognizedName,
    List<TeamMember> availableMembers, {
    required bool canCreate,
  }) => showDialog<TeamMember>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text('Identifier « $recognizedName »'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le nom lu peut être déformé. Choisissez la personne déjà '
              'enregistrée, ou créez une fiche si elle est nouvelle.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (MediaQuery.sizeOf(dialogContext).height * 0.4).clamp(100, 320).toDouble(),
              child: ListView(
                children: [
                  if (canCreate)
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1),
                      title: Text('Créer « $recognizedName »'),
                      onTap: () => Navigator.of(dialogContext).pop(
                        TeamMember(
                          id: recognizedName,
                          firstName: recognizedName,
                          lastName: '',
                          trigramme: recognizedName,
                        ),
                      ),
                    ),
                  for (final member in availableMembers)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(member.fullName),
                      subtitle: Text(member.trigramme),
                      onTap: () => Navigator.of(dialogContext).pop(member),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Annuler l’import'),
        ),
      ],
    ),
  );

  Future<String?> _askManualAgentName() {
    var enteredName = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Votre nom sur le planning'),
        content: TextField(
          onChanged: (value) => enteredName = value,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nom ou identifiant',
            helperText: 'Vous vérifierez ensuite chaque jour manuellement.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = enteredName.trim().toUpperCase();
              if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showUserSelectionDialog(
    List<String> detectedTrigrammes, {
    String? manualProfile,
    bool allowManualEntry = false,
    String? suggestedAgent,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Sélectionnez votre profil'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sélectionnez votre nom parmi les agents détectés dans le planning :'),
              const SizedBox(height: 16),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.4).clamp(100, 320).toDouble(),
                child: ListView.builder(
                  itemCount: detectedTrigrammes.length + (allowManualEntry ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == detectedTrigrammes.length) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.edit_calendar_outlined),
                          title: const Text('Mon nom n’a pas été détecté'),
                          subtitle: const Text('Renseigner ma ligne manuellement'),
                          onTap: () async {
                            final name = manualProfile?.isNotEmpty == true
                                ? manualProfile
                                : await _askManualAgentName();
                            if (context.mounted && name != null && name.isNotEmpty) {
                              // Une ligne manuelle ne doit pas réutiliser par
                              // hasard les cases d'une ligne OCR homonyme.
                              var manualName = name;
                              var suffix = 1;
                              while (detectedTrigrammes.contains(manualName)) {
                                manualName = '$name (saisie manuelle ${suffix++})';
                              }
                              Navigator.of(context).pop(manualName);
                            }
                          },
                        ),
                      );
                    }
                    final trigramme = detectedTrigrammes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: InitialsAvatar(
                          name: trigramme.isEmpty ? '?' : trigramme,
                          size: 34,
                        ),
                        title: Text(
                          trigramme,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: trigramme == suggestedAgent
                            ? const Text('Correspondance suggérée : vérifiez')
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.of(context).pop(trigramme),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showPreviewDialog({
    required String agent,
    required List<PreviewNightItem> previewItems,
    required String sourcePath,
    required Map<int, String> userVacations,
    required int year,
    required int month,
    required List<String> warnings,
    required bool colleaguesImported,
  }) async {
    // Build combined list of preview items (night shifts + vacation days)
    final List<Map<String, dynamic>> allItems = [];

    for (final item in previewItems) {
      allItems.add({
        'type': 'shift',
        'date': item.date,
        'item': item,
      });
    }

    for (final entry in userVacations.entries) {
      final day = entry.key;
      final code = entry.value;
      if (!previewItems.any((i) => i.date.day == day)) {
        allItems.add({
          'type': 'vacation',
          'date': DateTime(year, month, day),
          'code': code,
        });
      }
    }

    allItems.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.preview_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text('Aperçu - $agent')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: (MediaQuery.sizeOf(context).height * 0.55).clamp(100, 420).toDouble(),
          child: ListView(
            children: [
              Text(
                userVacations.isNotEmpty
                    ? '${previewItems.length} nuit(s) de garde • ${userVacations.length} jour(s) de vacances'
                    : '${previewItems.length} nuit(s) détectée(s)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppConstants.monthsFr[month - 1]} $year - source : ${sourcePath.split('/').last}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vérifiez ces lignes avant de valider',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final warning in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $warning', style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final row = allItems[index];
                    final date = row['date'] as DateTime;
                    final isVacation = row['type'] == 'vacation';
                    String formattedDate;
                    try {
                      formattedDate = DateFormat('EEEE d MMMM', 'fr_FR').format(date);
                    } catch (_) {
                      formattedDate = '${date.day}/${date.month}/${date.year}';
                    }

                    if (isVacation) {
                      final code = row['code'] as String;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: AppColors.warning.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: AppColors.warning.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
                            ),
                            child: Text(
                              '${date.day}'.padLeft(2, '0'),
                              style: AppFonts.monoText(
                                size: 13,
                                weight: FontWeight.w800,
                                color: AppColors.warning,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                            '🏖️ Jour de congé',
                            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            code,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }

                    final item = row['item'] as PreviewNightItem;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.shiftEnd.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.shiftEnd.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '${item.date.day}'.padLeft(2, '0'),
                            style: AppFonts.monoText(
                              size: 13,
                              weight: FontWeight.w800,
                              color: AppColors.shiftEnd,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        title: Text(formattedDate),
                        subtitle: item.coWorkers.isEmpty
                            ? Text(colleaguesImported
                                ? 'Aucun collègue enregistré'
                                : 'Collègues non importés')
                            : Text(
                                'Avec: ${item.coWorkers.map((c) => c.trigramme).join(', ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                        trailing: Icon(
                          item.coWorkers.isEmpty ? Icons.person_outline : Icons.people_outline,
                          color: item.coWorkers.isEmpty ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    );
                  },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Valider et Enregistrer'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _saveToDatabase({
    required List<PreviewNightItem> previewItems,
    required List<TeamMember> allTeamMembers,
    required TeamMember currentUser,
    required String currentAgent,
    required Map<String, TeamMember> membersByAgent,
    required bool preserveExistingProfile,
    required TimeOfDay shiftStartTime,
    required TimeOfDay shiftEndTime,
    required int year,
    required int month,
    required Map<int, String> userVacations,
    Map<String, List<int>>? allAgentShifts,
    Map<String, Map<int, String>>? allAgentVacations,
  }) async {
    setProcessing(true, 'Enregistrement en base...');

    try {
      final db = ref.read(databaseServiceProvider);

      // 1. Équipe : upsert (on ne perd pas les noms déjà saisis)
      await db.saveAllTeamMembers(allTeamMembers);

      var deleted = 0;

      // 2. Import des gardes et congés pour TOUS les agents
      if (allAgentShifts != null && allAgentShifts.isNotEmpty) {
        for (final entry in allAgentShifts.entries) {
          final member = membersByAgent[entry.key]!;
          final agentId = member.id;
          final agentDays = entry.value;
          final isCurrent = entry.key == currentAgent;
          final vacations = allAgentVacations?[entry.key] ??
              (isCurrent ? userVacations : const <int, String>{});

          final count = await db.deleteNightShiftsForMonth(agentId, year, month);
          if (isCurrent) deleted = count;

          for (final day in agentDays) {
            final date = DateTime(year, month, day);
            final coWorkerIds = allAgentShifts.entries
                .where((e) => e.key != entry.key && e.value.contains(day))
                .map((e) => membersByAgent[e.key]!.id)
                .toList();

            final shift = NightShift(
              id: '${agentId}_${year}_${month}_$day',
              date: date,
              agentId: agentId,
              agentTrigramme: member.trigramme,
              startTime: shiftStartTime,
              endTime: shiftEndTime,
              isWorking: true,
              coWorkerIds: coWorkerIds,
              isManualOverride: false,
            );
            await db.saveNightShift(shift);
          }

          for (final vacEntry in vacations.entries) {
            final day = vacEntry.key;
            if (agentDays.contains(day)) continue;

            final shift = NightShift(
              id: '${agentId}_${year}_${month}_$day',
              date: DateTime(year, month, day),
              agentId: agentId,
              agentTrigramme: member.trigramme,
              startTime: shiftStartTime,
              endTime: shiftEndTime,
              isWorking: false,
              isVacation: true,
              vacationType: vacEntry.value,
              coWorkerIds: const [],
            );
            await db.saveNightShift(shift);
          }
        }
      } else {
        // Fallback: sauvegarder au moins currentUser
        deleted = await db.deleteNightShiftsForMonth(currentUser.id, year, month);

        for (final item in previewItems) {
          final shift = NightShift(
            id: '${currentUser.id}_${year}_${month}_${item.date.day}',
            date: item.date,
            agentId: currentUser.id,
            agentTrigramme: currentUser.trigramme,
            startTime: shiftStartTime,
            endTime: shiftEndTime,
            isWorking: true,
            coWorkerIds: item.coWorkers.map((c) => c.id).toList(),
            isManualOverride: false,
          );
          await db.saveNightShift(shift);
        }

        final workingDays = previewItems.map((item) => item.date.day).toSet();
        for (final entry in userVacations.entries) {
          final day = entry.key;
          if (workingDays.contains(day)) continue;

          await db.saveNightShift(
            NightShift(
              id: '${currentUser.id}_${year}_${month}_$day',
              date: DateTime(year, month, day),
              agentId: currentUser.id,
              agentTrigramme: currentUser.trigramme,
              startTime: shiftStartTime,
              endTime: shiftEndTime,
              isWorking: false,
              isVacation: true,
              vacationType: entry.value,
              coWorkerIds: const [],
            ),
          );
        }
      }

      // 5. Configuration utilisateur (identité stable : l'id de l'agent)
      final existingConfig = db.getUserConfig();
      final userConfig = existingConfig == null
          ? UserConfig(
              userId: currentUser.id,
              userName: currentUser.firstName.isNotEmpty
                  ? currentUser.firstName
                  : currentAgent,
              userTrigramme: currentUser.trigramme,
              shiftStartTime: shiftStartTime,
              shiftEndTime: shiftEndTime,
              shiftDurationHours: AppConstants.defaultShiftDurationHours,
              notificationDelayMinutes: AppConstants.defaultNotificationDelayMinutes,
              notificationsEnabled: true,
            )
          : preserveExistingProfile
              ? existingConfig
              : existingConfig.copyWith(
                  userId: currentUser.id,
                  userTrigramme: currentUser.trigramme,
                  userName: existingConfig.userName.isEmpty
                      ? currentUser.trigramme
                      : existingConfig.userName,
                );

      if (!preserveExistingProfile || existingConfig == null) {
        await db.saveUserConfig(userConfig);
      }

      // 6. Rappels (autorisation demandée ici : c'est le moment où
      // l'utilisateur attend explicitement des notifications)
      if (userConfig.notificationsEnabled) {
        try {
          await NotificationService().requestPermissions();
          await NotificationService().rescheduleAllNotifications(
            userId: currentUser.id,
            shiftStartTime: shiftStartTime,
            notificationDelayMinutes: userConfig.notificationDelayMinutes,
          );
        } catch (e) {
          debugPrint('Replanification des rappels impossible : $e');
        }
      }

      // 7. Rafraîchissement de l'UI
      ref.invalidate(teamMembersProvider);
      ref.invalidate(allNightShiftsProvider);
      ref.invalidate(userConfigProvider);
      // Écran poussé depuis le tableau de bord : on revient en arrière.
      // Premier lancement (écran racine) : on renvoie vers l'accueil.
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        ref.read(selectedTabProvider.notifier).state = 0;
      }

      setProcessing(false, '');

      if (mounted) {
        final suffix = deleted > 0 ? ' ($deleted ancienne(s) garde(s) remplacée(s))' : '';
        _showSuccessSnackBar(
          '${previewItems.length} nuit(s) enregistrée(s) pour ${AppConstants.monthsFr[month - 1]} $year$suffix',
        );
      }
    } catch (e) {
      setProcessing(false, '');
      if (mounted) {
        _showErrorSnackBar(
          'Erreur lors de l’enregistrement. Le mois a pu être partiellement modifié : '
          'vérifiez-le avant de réessayer. $e',
        );
      }
    }
  }

  // ========== HELPER METHODS ==========

  void setProcessing(bool processing, String message) {
    if (mounted) {
      setState(() {
        _isProcessing = processing;
        _processingMessage = message;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Permet de changer d'agent associé (réintégration, changement de poste...).
  Future<void> _showChangeUserDialog() async {
    final db = ref.read(databaseServiceProvider);
    final members = db.getAllTeamMembers();

    if (members.isEmpty) {
      _showErrorSnackBar('Importez d\'abord un planning pour choisir un profil.');
      return;
    }

    final currentTrigramme = db.getUserConfig()?.userTrigramme;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer de profil'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrent = member.trigramme == currentTrigramme;
              return ListTile(
                leading: InitialsAvatar(
                  name: member.trigramme.isEmpty ? '?' : member.trigramme,
                  size: 34,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(member.trigramme),
                subtitle: Text(member.firstName),
                trailing: isCurrent ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(member.trigramme),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selected == null || selected == currentTrigramme) return;

    final member = members.firstWhere((m) => m.trigramme == selected);
    final config = db.getUserConfig();

    final updated = config == null
        ? UserConfig(
            userId: member.id,
            userName: member.firstName.isEmpty ? member.trigramme : member.firstName,
            userTrigramme: member.trigramme,
          )
        : config.copyWith(
            userId: member.id,
            userTrigramme: member.trigramme,
            userName: member.firstName.isEmpty ? member.trigramme : member.firstName,
          );

    await db.saveUserConfig(updated);

    ref.invalidate(userConfigProvider);
    ref.invalidate(allNightShiftsProvider);

    if (updated.notificationsEnabled) {
      await NotificationService().rescheduleAllNotifications(
        userId: updated.userId,
        shiftStartTime: updated.shiftStartTime,
        notificationDelayMinutes: updated.notificationDelayMinutes,
      );
    }

    if (mounted) {
      _showSuccessSnackBar('Profil actif : ${member.trigramme}');
    }
  }
}

// Preview data class
class PreviewNightItem {
  final DateTime date;
  final List<TeamMember> coWorkers;

  PreviewNightItem({
    required this.date,
    required this.coWorkers,
  });
}