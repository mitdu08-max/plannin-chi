import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/notification_service.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _trigrammeController = TextEditingController();

  TimeOfDay _shiftStartTime = AppConstants.defaultShiftStartTime;
  TimeOfDay _shiftEndTime = AppConstants.defaultShiftEndTime;
  int _shiftDurationHours = AppConstants.defaultShiftDurationHours;
  bool _notificationsEnabled = true;
  int _notificationDelayMinutes = AppConstants.defaultNotificationDelayMinutes;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _trigrammeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseServiceProvider);
    final userConfig = db.getUserConfig();

    if (userConfig != null) {
      setState(() {
        _nameController.text = userConfig.userName;
        _trigrammeController.text = userConfig.userTrigramme;
        _shiftStartTime = userConfig.shiftStartTime;
        _shiftEndTime = userConfig.shiftEndTime;
        _shiftDurationHours = userConfig.shiftDurationHours;
        _notificationsEnabled = userConfig.notificationsEnabled;
        _notificationDelayMinutes = userConfig.notificationDelayMinutes;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseServiceProvider);
    final userConfig = db.getUserConfig();

    final trigramme = _trigrammeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    // L'identifiant doit rester l'agent (trigramme/nom) : c'est la clé des
    // gardes (agentId). Un `user_<timestamp>` rendait les statistiques vides.
    final baseConfig = userConfig ??
        UserConfig(userId: trigramme, userName: name, userTrigramme: trigramme);

    final keepUserId = (userConfig?.userId ?? '').isNotEmpty;
    final updatedConfig = baseConfig.copyWith(
      // On conserve l'identifiant historique s'il existe : c'est lui qui lie
      // les gardes déjà importées (agentId).
      userId: keepUserId ? userConfig!.userId : trigramme,
      userName: name,
      userTrigramme: trigramme,
      shiftDurationHours: _shiftDurationHours,
      notificationDelayMinutes: _notificationDelayMinutes,
      shiftStartTime: _shiftStartTime,
      shiftEndTime: _shiftEndTime,
      notificationsEnabled: _notificationsEnabled,
    );

    await db.saveUserConfig(updatedConfig);

    // Reschedule notifications if enabled
    if (_notificationsEnabled) {
      final notificationService = NotificationService();
      final granted = await notificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications refusées par le système : activez-les dans les réglages Android.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      await notificationService.rescheduleAllNotifications(
        userId: updatedConfig.userId,
        shiftStartTime: _shiftStartTime,
        notificationDelayMinutes: _notificationDelayMinutes,
      );
    } else {
      final notificationService = NotificationService();
      await notificationService.cancelAllNotifications();
    }

    ref.invalidate(userConfigProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés avec succès'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _shiftStartTime : _shiftEndTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Theme.of(context).colorScheme.surface,
            hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
            dayPeriodTextColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _shiftStartTime = picked;
        } else {
          _shiftEndTime = picked;
        }
      });
    }
  }

  Future<void> _sendTestNotification() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get user config for shift time
    final db = ref.read(databaseServiceProvider);
    final userConfig = db.getUserConfig();
    final teamMembers = db.getAllTeamMembers();

    // Get current user's shifts to find colleagues for a sample night
    List<TeamMember> sampleCoWorkers = [];
    if (userConfig != null) {
      final allShifts = db.getAllNightShifts();
      final userShifts = allShifts
          .where((s) => s.agentId == userConfig.userId && s.isWorking)
          .toList();

      if (userShifts.isNotEmpty) {
        // Find colleagues for the first upcoming shift
        final firstShift = userShifts.first;
        sampleCoWorkers = teamMembers
            .where((m) => firstShift.coWorkerIds.contains(m.id))
            .toList();
      }
    }

    try {
      await notificationService.sendTestNotification(
        shiftStartTime: _shiftStartTime,
        coWorkers: sampleCoWorkers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification de test envoyée !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur notification: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section Profil
              _buildSectionHeader(theme, Icons.person, 'Profil'),
              const SizedBox(height: 12),
              _buildProfileSection(theme),

              const SizedBox(height: 24),

              // Section Horaires de garde
              _buildSectionHeader(theme, Icons.access_time, 'Horaires de garde'),
              const SizedBox(height: 12),
              _buildShiftHoursSection(theme),

              const SizedBox(height: 24),

              // Section Notifications
              _buildSectionHeader(theme, Icons.notifications, 'Notifications & Rappels'),
              const SizedBox(height: 12),
              _buildNotificationsSection(theme),

              const SizedBox(height: 24),

              // Section À propos
              _buildSectionHeader(theme, Icons.info, 'À propos'),
              const SizedBox(height: 12),
              _buildAboutSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProfileSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                hintText: 'Jean Dupont',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer votre nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _trigrammeController,
              decoration: const InputDecoration(
                labelText: 'Trigramme / nom sur le planning',
                hintText: 'JDU ou RINAUDO',
                prefixIcon: Icon(Icons.badge_outlined),
                counterText: '',
                helperText: 'Trigramme ou nom utilisé dans le planning',
              ),
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer votre trigramme';
                }
                if (value.trim().length < 2) {
                  return 'Saisissez au moins 2 caractères';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftHoursSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Heure de début
            ListTile(
              leading: Icon(Icons.nightlight_round, color: theme.colorScheme.primary),
              title: const Text('Heure de début'),
              subtitle: Text('Début de la garde de nuit'),
              trailing: Text(
                _formatTimeOfDay(_shiftStartTime),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              onTap: () => _pickTime(context, true),
            ),
            const Divider(),

            // Heure de fin
            ListTile(
              leading: Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.tertiary),
              title: const Text('Heure de fin'),
              subtitle: Text('Fin de la garde de nuit'),
              trailing: Text(
                _formatTimeOfDay(_shiftEndTime),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              onTap: () => _pickTime(context, false),
            ),
            const Divider(),

            // Durée forfaitaire
            ListTile(
              leading: Icon(Icons.timer_outlined, color: theme.colorScheme.secondary),
              title: const Text('Durée forfaitaire d\'une nuit'),
              subtitle: Text('Utilisée pour le calcul des heures totales'),
              trailing: DropdownButton<int>(
                value: _shiftDurationHours,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 heures')),
                  DropdownMenuItem(value: 11, child: Text('11 heures')),
                  DropdownMenuItem(value: 12, child: Text('12 heures')),
                ],
                onChanged: (value) => setState(() => _shiftDurationHours = value!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Activer/Désactiver notifications
            SwitchListTile(
              secondary: Icon(Icons.notifications_active, color: _notificationsEnabled ? theme.colorScheme.primary : theme.colorScheme.outline),
              title: const Text('Activer les notifications'),
              subtitle: Text(_notificationsEnabled ? 'Vous recevrez des rappels avant chaque garde' : 'Aucune notification ne sera envoyée'),
              value: _notificationsEnabled,
              onChanged: (value) => setState(() => _notificationsEnabled = value),
            ),
            const Divider(),

            // Délai d'alerte
            ListTile(
              leading: Icon(Icons.schedule, color: theme.colorScheme.secondary),
              title: const Text('Délai avant la prise de poste'),
              subtitle: Text('Rappel $_formatDelay(_notificationDelayMinutes) avant le début de la garde'),
              trailing: DropdownButton<int>(
                value: _notificationDelayMinutes,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 heure avant')),
                  DropdownMenuItem(value: 120, child: Text('2 heures avant')),
                  DropdownMenuItem(value: 180, child: Text('3 heures avant')),
                ],
                onChanged: (value) => setState(() => _notificationDelayMinutes = value!),
              ),
            ),
            const Divider(),

            // Bouton test notification
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.science_outlined),
                label: const Text('Tester une notification'),
                onPressed: _sendTestNotification,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
              title: const Text('Night Shift Planning'),
              subtitle: Text('Version ${AppConstants.appVersion}'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.description_outlined, color: theme.colorScheme.secondary),
              title: const Text('Licences open source'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenses(),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
              title: const Text('Réinitialiser l\'application'),
              subtitle: const Text('Supprimer toutes les données (plannings, stats, config)'),
              onTap: _confirmResetAll,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDelay(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return '${hours}h';
    }
    return '${minutes}min';
  }

  void _showLicenses() {
    showLicensePage(context: context, applicationName: AppConstants.appName, applicationVersion: AppConstants.appVersion);
  }

  void _confirmResetAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser l\'application'),
        content: const Text('Cette action supprimera TOUTES les données : plannings importés, statistiques, configuration utilisateur. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllData() async {
    final db = ref.read(databaseServiceProvider);
    final notificationService = NotificationService();
    await notificationService.cancelAllNotifications();
    await db.clearAll();
    await notificationService.initialize();

    ref.invalidate(userConfigProvider);
    ref.invalidate(teamMembersProvider);
    ref.invalidate(allNightShiftsProvider);
    ref.read(selectedTabProvider.notifier).state = 0;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application réinitialisée'), backgroundColor: Colors.orange),
      );
      setState(() {
        _nameController.clear();
        _trigrammeController.clear();
        _shiftStartTime = AppConstants.defaultShiftStartTime;
        _shiftEndTime = AppConstants.defaultShiftEndTime;
        _shiftDurationHours = AppConstants.defaultShiftDurationHours;
        _notificationsEnabled = true;
        _notificationDelayMinutes = AppConstants.defaultNotificationDelayMinutes;
      });
    }
  }
}