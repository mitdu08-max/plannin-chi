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
        title: const Text('Import Planning'),
        automaticallyImplyLeading: widget.isFirstLaunch,
      ),
      body: userConfigAsync.when(
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
    );
  }

  Widget _buildHeader(ThemeData theme, bool isConfigured, UserConfig? userConfig) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.nightlight_round,
              size: 64,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isFirstLaunch
                  ? 'Bienvenue dans Night Shift Planning'
                  : 'Importer un planning',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isFirstLaunch
                  ? 'Configurez votre profil et importez votre premier planning d\'équipe pour commencer.'
                  : 'Importez un planning d\'équipe au format PDF ou capture d\'écran pour extraire vos nuits de garde et identifier vos collègues.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (isConfigured && userConfig != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        userConfig.userTrigramme.isNotEmpty
                            ? userConfig.userTrigramme.substring(0, 1).toUpperCase()
                            : (userConfig.userName.isNotEmpty
                                ? userConfig.userName.substring(0, 1).toUpperCase()
                                : '?'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userConfig.userName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Trigramme: ${userConfig.userTrigramme}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showChangeUserDialog(),
                      child: const Text('Changer'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Format attendu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Colonnes = Jours du mois (1 à 31)\n'
              '• Lignes = 12 agents de l\'équipe\n'
              '• Codes: N/NUIT/GARDE = Travail, R/REPOS/CONGE = Repos',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

      final file = File(files.first.path!);
      setProcessing(true, 'Lecture du PDF...');

      final parseResult = await PdfParserService.parsePlanningPdfFull(file);

      if (!mounted) return;
      setProcessing(false, '');
      await _showPreviewAndConfirm(
        parseResult.agentShifts,
        parseResult.agentVacations,
        file.path,
        year: parseResult.year,
        month: parseResult.month,
      );
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

      final XFile? pickedFile = await _imagePicker.pickImage(
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

      final parseResult = await OcrParserService.parsePlanningImageFull(file);

      if (!mounted) return;
      setProcessing(false, '');
      await _showPreviewAndConfirm(
        parseResult.agentShifts,
        parseResult.agentVacations,
        file.path,
        year: parseResult.year,
        month: parseResult.month,
      );
    } catch (e) {
      setProcessing(false, '');
      if (mounted) {
        _showErrorSnackBar('Erreur lors de l\'import image: $e');
      }
    }
  }

  // ========== PREVIEW & CONFIRMATION ==========

  Future<void> _showPreviewAndConfirm(
    Map<String, List<int>> agentShifts,
    Map<String, Map<int, String>> agentVacations,
    String sourcePath, {
    int? year,
    int? month,
  }) async {
    if (agentShifts.isEmpty) {
      _showErrorSnackBar('Aucune donnée de planning détectée dans le fichier.');
      return;
    }

    final db = ref.read(databaseServiceProvider);
    final teamMembers = db.getAllTeamMembers();
    final userConfig = db.getUserConfig();

    // Determine current month/year from file or use current
    final now = DateTime.now();
    final int resolvedYear = year ?? now.year;
    final int resolvedMonth = month ?? now.month;

    String? currentUserTrigramme = userConfig?.userTrigramme;

    // If user not configured or trigramme not in detected agents, show selection dialog
    if (currentUserTrigramme == null || !agentShifts.containsKey(currentUserTrigramme)) {
      currentUserTrigramme = await _showUserSelectionDialog(agentShifts.keys.toList());
      if (currentUserTrigramme == null) return; // User cancelled
    }

    final currentUserDays = agentShifts[currentUserTrigramme] ?? [];

    if (currentUserDays.isEmpty) {
      _showErrorSnackBar('Aucune nuit de garde détectée pour $currentUserTrigramme.');
      return;
    }

    // Build preview data
    final previewItems = <PreviewNightItem>[];
    final allTeamMembers = <TeamMember>[];

    // Create TeamMember objects for all detected agents
    for (final trigramme in agentShifts.keys) {
      final existing = teamMembers.firstWhere(
        (m) => m.trigramme == trigramme,
        orElse: () => TeamMember(
          id: trigramme,
          firstName: trigramme,
          lastName: '',
          trigramme: trigramme,
        ),
      );
      allTeamMembers.add(existing);
    }

    // Get shift times from user config or defaults
    final shiftStartTime = userConfig?.shiftStartTime ?? AppConstants.defaultShiftStartTime;
    final shiftEndTime = userConfig?.shiftEndTime ?? AppConstants.defaultShiftEndTime;

    for (final day in currentUserDays) {
      final date = DateTime(resolvedYear, resolvedMonth, day);
      final coWorkers = <TeamMember>[];

      for (final entry in agentShifts.entries) {
        if (entry.key != currentUserTrigramme && entry.value.contains(day)) {
          final colleague = allTeamMembers.firstWhere(
            (m) => m.trigramme == entry.key,
            orElse: () => TeamMember(
              id: entry.key,
              firstName: entry.key,
              lastName: '',
              trigramme: entry.key,
            ),
          );
          coWorkers.add(colleague);
        }
      }

      previewItems.add(PreviewNightItem(
        date: date,
        coWorkers: coWorkers,
      ));
    }

    // Get vacations for current user
    final userVacations = agentVacations[currentUserTrigramme] ??
        agentVacations.entries
            .firstWhere(
              (e) => e.key.toUpperCase() == currentUserTrigramme!.toUpperCase() ||
                     e.key.toUpperCase().startsWith(currentUserTrigramme!.toUpperCase()) ||
                     currentUserTrigramme!.toUpperCase().startsWith(e.key.toUpperCase()),
              orElse: () => const MapEntry('', {}),
            )
            .value;

    // Show preview dialog with night shifts and vacations
    final confirmed = await _showPreviewDialog(
      trigramme: currentUserTrigramme,
      previewItems: previewItems,
      allTeamMembers: allTeamMembers,
      sourcePath: sourcePath,
      userVacations: userVacations,
      year: resolvedYear,
      month: resolvedMonth,
    );

    if (confirmed && mounted) {
      await _saveToDatabase(
        previewItems: previewItems,
        allTeamMembers: allTeamMembers,
        currentUserTrigramme: currentUserTrigramme,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        year: resolvedYear,
        month: resolvedMonth,
        agentVacations: agentVacations,
      );
    }
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
    required String trigramme,
    required List<PreviewNightItem> previewItems,
    required List<TeamMember> allTeamMembers,
    required String sourcePath,
    required Map<int, String> userVacations,
    required int year,
    required int month,
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
            Expanded(child: Text('Aperçu - $trigramme')),
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
                'Source: ${sourcePath.split('/').last}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
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
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade800,
                            child: Text(
                              '${date.day}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '🏖️ Vacances ($code)',
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          ),
                          trailing: Icon(Icons.beach_access, color: Colors.orange.shade800),
                        ),
                      );
                    }

                    final item = row['item'] as PreviewNightItem;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade700,
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
                          color: item.coWorkers.isEmpty ? Colors.orange : Colors.green,
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
    required String currentUserTrigramme,
    required TimeOfDay shiftStartTime,
    required TimeOfDay shiftEndTime,
    required int year,
    required int month,
    required Map<String, Map<int, String>> agentVacations,
  }) async {
    setProcessing(true, 'Enregistrement en base...');

    try {
      final db = ref.read(databaseServiceProvider);

      // Save all team members
      await db.saveAllTeamMembers(allTeamMembers);

      // Create and save night shifts
      final currentUser = allTeamMembers.firstWhere((m) => m.trigramme == currentUserTrigramme);

      for (final item in previewItems) {
        final coWorkerIds = item.coWorkers.map((c) => c.id).toList();

        final shift = NightShift(
          id: '${currentUser.id}_${year}_${month}_${item.date.day}',
          date: item.date,
          agentId: currentUser.id,
          agentTrigramme: currentUserTrigramme,
          startTime: shiftStartTime,
          endTime: shiftEndTime,
          isWorking: true,
          coWorkerIds: coWorkerIds,
          isManualOverride: false,
        );

        await db.saveNightShift(shift);
      }

      // Save vacation days for current user
      final userVacations = agentVacations[currentUserTrigramme] ??
          agentVacations.entries
              .firstWhere(
                (e) => e.key.toUpperCase() == currentUserTrigramme.toUpperCase() ||
                       e.key.toUpperCase().startsWith(currentUserTrigramme.toUpperCase()) ||
                       currentUserTrigramme.toUpperCase().startsWith(e.key.toUpperCase()),
                orElse: () => const MapEntry('', {}),
              )
              .value;
      for (final entry in userVacations.entries) {
        final day = entry.key;
        final vacationCode = entry.value;
        final date = DateTime(year, month, day);

        // Only save if not already a working shift
        final existingShift = previewItems.firstWhere(
          (item) => item.date.day == day,
          orElse: () => PreviewNightItem(date: date, coWorkers: []),
        );

        // If there's already a working shift for this day, skip vacation
        if (existingShift.date.day == day && existingShift.coWorkers.isNotEmpty || previewItems.any((i) => i.date.day == day)) {
          // Check if this day already has a working shift
          final hasWorkingShift = previewItems.any((i) => i.date.day == day);
          if (hasWorkingShift) continue;
        }

        final vacationShift = NightShift(
          id: '${currentUser.id}_${year}_${month}_$day',
          date: date,
          agentId: currentUser.id,
          agentTrigramme: currentUserTrigramme,
          startTime: shiftStartTime,
          endTime: shiftEndTime,
          isWorking: false,
          isVacation: true,
          vacationType: vacationCode,
          coWorkerIds: const [],
        );

        await db.saveNightShift(vacationShift);
      }

      // Update or create user config with selected agent
      var userConfig = db.getUserConfig();
      if (userConfig != null) {
        final updatedConfig = userConfig.copyWith(
          userId: currentUser.id,
          userTrigramme: currentUserTrigramme,
          userName: userConfig.userName.isEmpty ? currentUserTrigramme : userConfig.userName,
        );
        await db.saveUserConfig(updatedConfig);
        userConfig = updatedConfig;
      } else {
        final newConfig = UserConfig(
          userId: currentUser.id,
          userName: currentUser.firstName.isNotEmpty ? currentUser.firstName : currentUserTrigramme,
          userTrigramme: currentUserTrigramme,
          shiftStartTime: shiftStartTime,
          shiftEndTime: shiftEndTime,
          shiftDurationHours: AppConstants.defaultShiftDurationHours,
          notificationDelayMinutes: AppConstants.defaultNotificationDelayMinutes,
          notificationsEnabled: true,
        );
        await db.saveUserConfig(newConfig);
        userConfig = newConfig;
      }

      // Schedule notifications for upcoming shifts if enabled
      if (userConfig.notificationsEnabled) {
        try {
          await NotificationService().rescheduleAllNotifications(
            userId: currentUser.id,
            shiftStartTime: shiftStartTime,
            notificationDelayMinutes: userConfig.notificationDelayMinutes,
          );
        } catch (e) {
          print('Notification reschedule warning: $e');
        }
      }

      // Invalidate providers to refresh UI
      ref.invalidate(teamMembersProvider);
      ref.invalidate(allNightShiftsProvider);
      ref.invalidate(userConfigProvider);

      setProcessing(false, '');

      if (mounted) {
        _showSuccessSnackBar('${previewItems.length} nuit(s) enregistrée(s) avec succès !');
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showChangeUserDialog() {
    // TODO: Implement user change dialog
    _showErrorSnackBar('Fonctionnalité à venir');
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