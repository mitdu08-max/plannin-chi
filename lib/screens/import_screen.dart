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
import '../services/notification_service.dart';
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
      body: AuroraBackground(
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
    return SurfaceCard(
      gradient: AppColors.aurora,
      glow: true,
      borderColor: Colors.white.withValues(alpha: 0.16),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.nightlight_round, size: 26, color: Colors.white),
              ),
              const Spacer(),
              if (isConfigured && userConfig != null)
                TextButton(
                  onPressed: _showChangeUserDialog,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Changer'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.isFirstLaunch ? 'Bienvenue' : 'Importer un planning',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isFirstLaunch
                ? 'Chargez le planning de votre équipe pour commencer : vos nuits, vos collègues et vos rappels seront créés automatiquement.'
                : 'PDF officiel ou capture d\'écran du planning de l\'équipe.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          if (isConfigured && userConfig != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  InitialsAvatar(
                    name: userConfig.userTrigramme.isNotEmpty
                        ? userConfig.userTrigramme
                        : userConfig.userName,
                    size: 36,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userConfig.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Profil actif : ${userConfig.userTrigramme}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
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
        Text(
          'Source du planning',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
        Text(
          'Configuration requise',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, size: 23, color: theme.colorScheme.primary),
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
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
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
                  size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text('Format attendu', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• Une colonne par jour du mois, une ligne par agent\n'
            '• Codes lus : N = nuit travaillée, RH/R = repos,\n'
            '   CA/CET/CFR = congés, F/F EXT = formation\n'
            '• Le mois est lu dans le document (sinon il vous est demandé)',
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
      final parseResult = await PdfParserService.parsePlanningPdfFile(File(path));

      if (!mounted) return;
      setProcessing(false, '');
      await _showPreviewAndConfirm(parseResult, path);
    } catch (e) {
      setProcessing(false, '');
      if (mounted) {
        _showErrorSnackBar('Erreur lors de l\'import PDF: $e');
      }
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
      await _showPreviewAndConfirm(parseResult, file.path);
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

  /// Demande le mois et l'année quand le document ne les contient pas.
  Future<(int, int)?> _askMonthAndYear() async {
    final now = DateTime.now();
    var year = now.year;
    var month = now.month;

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
                const Text(
                  'Le mois n\'a pas pu être lu dans le document. '
                  'Indiquez-le pour éviter d\'enregistrer les gardes au mauvais mois.',
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
                    for (var y = now.year - 2; y <= now.year + 2; y++)
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
    String sourcePath,
  ) async {
    var result = parsed;

    // 1. Le mois n'est jamais deviné : si le titre est illisible, on demande.
    if (!result.monthDetected) {
      final picked = await _askMonthAndYear();
      if (picked == null) return;
      setProcessing(true, 'Nouvelle analyse avec le mois sélectionné...');
      result = PdfParserService.parsePlanningText(
        result.rawText,
        forcedYear: picked.$1,
        forcedMonth: picked.$2,
      );
      setProcessing(false, '');
    }

    if (result.agentShifts.isEmpty) {
      _showErrorSnackBar('Aucune donnée de planning détectée dans le fichier.');
      return;
    }

    final year = result.year!;
    final month = result.month!;

    final db = ref.read(databaseServiceProvider);
    final teamMembers = db.getAllTeamMembers();
    final userConfig = db.getUserConfig();

    var resolvedAgent = _resolveCurrentAgent(userConfig, result.agentShifts.keys.toList());
    if (resolvedAgent == null) {
      resolvedAgent = await _showUserSelectionDialog(result.agentShifts.keys.toList());
      if (resolvedAgent == null) return; // annulé
    }
    final currentAgent = resolvedAgent;

    final currentUserDays = result.agentShifts[currentAgent] ?? const <int>[];
    if (currentUserDays.isEmpty) {
      _showErrorSnackBar('Aucune nuit de garde détectée pour $currentAgent.');
      return;
    }

    // 2. Construction de l'aperçu
    final previewItems = <PreviewNightItem>[];
    final allTeamMembers = <TeamMember>[];

    for (final agent in result.agentShifts.keys) {
      final existing = teamMembers.firstWhere(
        (m) => m.trigramme == agent,
        orElse: () => TeamMember(
          id: agent,
          firstName: agent,
          lastName: '',
          trigramme: agent,
        ),
      );
      allTeamMembers.add(existing);
    }

    final shiftStartTime = userConfig?.shiftStartTime ?? AppConstants.defaultShiftStartTime;
    final shiftEndTime = userConfig?.shiftEndTime ?? AppConstants.defaultShiftEndTime;

    for (final day in currentUserDays) {
      final date = DateTime(year, month, day);
      final coWorkers = allTeamMembers
          .where((m) => m.trigramme != currentAgent &&
              (result.agentShifts[m.trigramme] ?? const <int>[]).contains(day))
          .toList();

      previewItems.add(PreviewNightItem(date: date, coWorkers: coWorkers));
    }

    final userVacations = result.agentVacations[currentAgent] ?? const <int, String>{};

    final confirmed = await _showPreviewDialog(
      agent: currentAgent,
      previewItems: previewItems,
      sourcePath: sourcePath,
      userVacations: userVacations,
      year: year,
      month: month,
      warnings: result.warnings,
    );

    if (!confirmed || !mounted) return;

    await _saveToDatabase(
      previewItems: previewItems,
      allTeamMembers: allTeamMembers,
      currentAgent: currentAgent,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
      year: year,
      month: month,
      userVacations: userVacations,
    );
  }

  Future<String?> _showUserSelectionDialog(List<String> detectedTrigrammes) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                height: 320,
                child: ListView.builder(
                  itemCount: detectedTrigrammes.length,
                  itemBuilder: (context, index) {
                    final trigramme = detectedTrigrammes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            trigramme.isNotEmpty ? trigramme.substring(0, 1).toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          trigramme,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      for (final warning in warnings.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $warning', style: const TextStyle(fontSize: 12)),
                        ),
                      if (warnings.length > 4)
                        Text(
                          '• … et ${warnings.length - 4} autre(s)',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
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
                          leading: CircleAvatar(
                            backgroundColor: AppColors.warning,
                            child: Text(
                              '${date.day}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        leading: CircleAvatar(
                          backgroundColor: AppColors.shiftEnd,
                          child: Text(
                            '${item.date.day}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(formattedDate),
                        subtitle: item.coWorkers.isEmpty
                            ? const Text('Seul de garde')
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
    required String currentAgent,
    required TimeOfDay shiftStartTime,
    required TimeOfDay shiftEndTime,
    required int year,
    required int month,
    required Map<int, String> userVacations,
  }) async {
    setProcessing(true, 'Enregistrement en base...');

    try {
      final db = ref.read(databaseServiceProvider);

      // 1. Équipe : upsert (on ne perd pas les noms déjà saisis)
      await db.saveAllTeamMembers(allTeamMembers);

      final currentUser =
          allTeamMembers.firstWhere((m) => m.trigramme == currentAgent);

      // 2. Import idempotent : on purge le mois avant de le réécrire, sinon
      // une garde retirée du nouveau planning restait indéfiniment en base.
      final deleted =
          await db.deleteNightShiftsForMonth(currentUser.id, year, month);

      // 3. Gardes du mois
      for (final item in previewItems) {
        final shift = NightShift(
          id: '${currentUser.id}_${year}_${month}_${item.date.day}',
          date: item.date,
          agentId: currentUser.id,
          agentTrigramme: currentAgent,
          startTime: shiftStartTime,
          endTime: shiftEndTime,
          isWorking: true,
          coWorkerIds: item.coWorkers.map((c) => c.id).toList(),
          isManualOverride: false,
        );
        await db.saveNightShift(shift);
      }

      // 4. Congés : uniquement les jours qui ne sont pas déjà une garde
      final workingDays = previewItems.map((item) => item.date.day).toSet();
      for (final entry in userVacations.entries) {
        final day = entry.key;
        if (workingDays.contains(day)) continue;

        await db.saveNightShift(
          NightShift(
            id: '${currentUser.id}_${year}_${month}_$day',
            date: DateTime(year, month, day),
            agentId: currentUser.id,
            agentTrigramme: currentAgent,
            startTime: shiftStartTime,
            endTime: shiftEndTime,
            isWorking: false,
            isVacation: true,
            vacationType: entry.value,
            coWorkerIds: const [],
          ),
        );
      }

      // 5. Configuration utilisateur (identité stable : l'id de l'agent)
      final existingConfig = db.getUserConfig();
      final userConfig = existingConfig == null
          ? UserConfig(
              userId: currentUser.id,
              userName: currentUser.firstName.isNotEmpty
                  ? currentUser.firstName
                  : currentAgent,
              userTrigramme: currentAgent,
              shiftStartTime: shiftStartTime,
              shiftEndTime: shiftEndTime,
              shiftDurationHours: AppConstants.defaultShiftDurationHours,
              notificationDelayMinutes: AppConstants.defaultNotificationDelayMinutes,
              notificationsEnabled: true,
            )
          : existingConfig.copyWith(
              userId: currentUser.id,
              userTrigramme: currentAgent,
              userName: existingConfig.userName.isEmpty
                  ? currentAgent
                  : existingConfig.userName,
            );

      await db.saveUserConfig(userConfig);

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
        _showErrorSnackBar('Erreur lors de l\'enregistrement: $e');
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
                leading: CircleAvatar(
                  backgroundColor: isCurrent
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  child: Text(
                    member.trigramme.isNotEmpty
                        ? member.trigramme.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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