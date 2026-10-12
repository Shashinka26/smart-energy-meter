import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/appliance_config.dart';
import '../services/appliance_settings_service.dart';
import '../services/firebase_service.dart';
import '../services/schedule_model_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_header_card.dart';
import '../widgets/schedule_analysis_card.dart';
import '../widgets/section_header.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final DatabaseReference _scheduleRef = FirebaseDatabase.instance.ref(
    'Schedules',
  );
  final FirebaseService _firebaseService = FirebaseService();
  final ApplianceSettingsService _applianceSettings =
      ApplianceSettingsService.instance;

  StreamSubscription<DatabaseEvent>? _scheduleSubscription;
  StreamSubscription<ApplianceType>? _applianceSubscription;
  StreamSubscription<DatabaseEvent>? _scheduleModeSubscription;

  List<MapEntry<dynamic, dynamic>> _schedules = [];
  bool _schedulesLoaded = false;
  ApplianceType _applianceType = ApplianceType.notSet;
  bool _isAutoScheduleMode = false;

  final List<String> _repeatOptions = [
    'Once',
    'Every Day',
    'Weekdays',
    'Weekends',
  ];

  @override
  void initState() {
    super.initState();
    _scheduleSubscription = _scheduleRef.onValue.listen(
      _handleScheduleUpdate,
      onError: (_) {
        if (mounted) {
          setState(() => _schedulesLoaded = true);
        }
      },
    );
    _applianceSubscription = _applianceSettings.watchAppliance().listen(
      (type) {
        if (mounted) {
          setState(() => _applianceType = type);
        }
      },
    );
    _applianceSettings.loadAppliance().then((type) {
      if (mounted) {
        setState(() => _applianceType = type);
      }
    });
    _scheduleModeSubscription = FirebaseDatabase.instance
        .ref('SmartMeter/scheduleMode')
        .onValue
        .listen((event) {
      if (!mounted) {
        return;
      }

      final mode = event.snapshot.value?.toString() ?? 'manual';
      setState(() => _isAutoScheduleMode = mode == 'auto');
    });
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _applianceSubscription?.cancel();
    _scheduleModeSubscription?.cancel();
    super.dispose();
  }

  void _handleScheduleUpdate(DatabaseEvent event) {
    if (!mounted) {
      return;
    }

    final value = event.snapshot.value;
    setState(() {
      _schedulesLoaded = true;
      _schedules = value == null
          ? <MapEntry<dynamic, dynamic>>[]
          : Map<dynamic, dynamic>.from(value as Map).entries.toList();
    });
  }

  Future<void> _applySuggestion(ScheduleSuggestion suggestion) async {
    final confirmed = await _confirmApplySuggestion(suggestion);
    if (!confirmed || !mounted) {
      return;
    }

    final newSchedule = _scheduleRef.push();

    await newSchedule.set({
      'name': suggestion.scheduleName,
      'startHour': suggestion.suggestedStartHour,
      'startMinute': suggestion.suggestedStartMinute,
      'endHour': suggestion.suggestedEndHour,
      'endMinute': suggestion.suggestedEndMinute,
      'repeat': 'Every Day',
      'enabled': true,
      'action': 'OFF',
      'createdAt': ServerValue.timestamp,
    });

    await _firebaseService.setScheduleMode('auto');

    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Suggested schedule applied. Auto mode enabled.',
      );
    }
  }

  Future<bool> _confirmApplySuggestion(ScheduleSuggestion suggestion) async {
    final profile = ApplianceConfig.profileFor(suggestion.applianceType);
    final applianceLabel =
        suggestion.applianceType == ApplianceType.notSet
            ? 'Connected appliance'
            : profile.label;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apply Suggested Schedule?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('Appliance', applianceLabel),
              _confirmRow('Action', 'Relay OFF'),
              _confirmRow('Time', suggestion.peakHours),
              _confirmRow('Repeat', 'Every Day'),
              _confirmRow(
                'Est. savings',
                '~Rs. ${suggestion.estimatedMonthlySavings.toStringAsFixed(0)}/month',
              ),
              const SizedBox(height: 12),
              const Text(
                'Schedule mode will switch to auto so ESP32 follows this schedule.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddScheduleDialog() async {
    TimeOfDay startTime = const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 22, minute: 0);

    String repeat = 'Every Day';
    bool enabled = true;
    String action = 'OFF';

    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Schedule Name',
                        prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schedule Enabled'),
                      subtitle: const Text('Turn this schedule on or off'),
                      value: enabled,
                      onChanged: (value) => setDialogState(() => enabled = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: action,
                      dropdownColor: AppColors.surfaceLight,
                      decoration: const InputDecoration(
                        labelText: 'Relay Action During Window',
                        prefixIcon: Icon(Icons.power_settings_new, color: AppColors.primary),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ON', child: Text('Turn ON')),
                        DropdownMenuItem(value: 'OFF', child: Text('Turn OFF')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => action = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    _timePickerTile(
                      title: 'Start Time',
                      time: startTime,
                      icon: Icons.login_rounded,
                      onTap: () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (selected != null) setDialogState(() => startTime = selected);
                      },
                    ),
                    _timePickerTile(
                      title: 'End Time',
                      time: endTime,
                      icon: Icons.logout_rounded,
                      onTap: () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (selected != null) setDialogState(() => endTime = selected);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: repeat,
                      dropdownColor: AppColors.surfaceLight,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        prefixIcon: Icon(Icons.repeat, color: AppColors.primary),
                      ),
                      items: _repeatOptions
                          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => repeat = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      AppSnackbar.error(context, 'Please enter a schedule name');
                      return;
                    }

                    await _scheduleRef.push().set({
                      'name': name,
                      'startHour': startTime.hour,
                      'startMinute': startTime.minute,
                      'endHour': endTime.hour,
                      'endMinute': endTime.minute,
                      'repeat': repeat,
                      'enabled': enabled,
                      'action': action,
                      'createdAt': ServerValue.timestamp,
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      AppSnackbar.show(context, message: 'Schedule created successfully');
                    }
                  },
                  child: const Text('Save Schedule'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Widget _timePickerTile({
    required String title,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surfaceLight,
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: Text(
          time.format(context),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSchedule(String id, bool value) async {
    HapticFeedback.selectionClick();
    await _scheduleRef.child(id).update({'enabled': value});
  }

  Future<void> _deleteSchedule(String id) async {
    await _scheduleRef.child(id).remove();
    if (mounted) {
      AppSnackbar.show(context, message: 'Schedule deleted', icon: Icons.delete_outline);
    }
  }

  Future<void> _saveAppliance(ApplianceType type) async {
    HapticFeedback.selectionClick();

    setState(() => _applianceType = type);

    try {
      await _applianceSettings.saveAppliance(type);

      if (!mounted) {
        return;
      }

      AppSnackbar.show(
        context,
        message: type == ApplianceType.notSet
            ? 'Appliance selection cleared'
            : '${ApplianceConfig.profileFor(type).label} selected',
      );
    } catch (error) {
      final restored = await _applianceSettings.loadAppliance();
      if (!mounted) {
        return;
      }

      setState(() => _applianceType = restored);
      AppSnackbar.error(
        context,
        'Could not save appliance. Check your connection and try again.',
      );
    }
  }

  Future<void> _showAppliancePicker(ApplianceType selectedAppliance) async {
    if (!widget.isOwner) {
      return;
    }

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;

    final picked = await showModalBottomSheet<ApplianceType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Select Connected Appliance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.device_unknown_outlined),
                        title: const Text('Not set'),
                        trailing: selectedAppliance == ApplianceType.notSet
                            ? const Icon(Icons.check_circle, color: AppColors.primary)
                            : null,
                        onTap: () =>
                            Navigator.pop(sheetContext, ApplianceType.notSet),
                      ),
                      for (final category in ApplianceConfig.categories) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...ApplianceConfig.profilesInCategory(category).map(
                          (profile) => ListTile(
                            leading: Icon(profile.icon, color: AppColors.primary),
                            title: Text(profile.label),
                            trailing: selectedAppliance == profile.type
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () =>
                                Navigator.pop(sheetContext, profile.type),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      await _saveAppliance(picked);
    }
  }

  String _formatTime(Map<dynamic, dynamic> data, String prefix) {
    final hour = (data['${prefix}Hour'] ?? 0) as int;
    final minute = (data['${prefix}Minute'] ?? 0) as int;
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  Widget _buildApplianceCard(ApplianceType selectedAppliance) {
    final profile = ApplianceConfig.profileFor(selectedAppliance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.primary, 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(profile.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Appliance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      'Select what is plugged into the smart plug',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.isOwner
                  ? () => _showAppliancePicker(selectedAppliance)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.power_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appliance type',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isOwner)
                      const Icon(
                        Icons.unfold_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.isOwner) ...[
            const SizedBox(height: 8),
            const Text(
              'View-only account — only the owner can change the appliance.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard() {
    final isAuto = _isAutoScheduleMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isAuto ? AppColors.primary : AppColors.info).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tint(isAuto ? AppColors.primary : AppColors.info, 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAuto ? Icons.auto_mode_rounded : Icons.touch_app_outlined,
              color: isAuto ? AppColors.primary : AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Mode',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  isAuto
                      ? 'ESP32 follows your schedules automatically'
                      : 'Relay controlled manually from Dashboard',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isAuto,
            onChanged: widget.isOwner
                ? (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _isAutoScheduleMode = value);
                    _firebaseService.setScheduleMode(
                      value ? 'auto' : 'manual',
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Schedule')),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton.extended(
              onPressed: _showAddScheduleDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      body: !_schedulesLoaded
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const GradientHeaderCard(
                  icon: Icons.schedule_rounded,
                  title: 'Smart Energy Scheduling',
                  subtitle:
                      'Analyze usage, create schedules, and let ESP32 control the relay to save cost.',
                ),
                const SizedBox(height: 16),
                _buildModeCard(),
                const SizedBox(height: 16),
                _buildApplianceCard(_applianceType),
                const SizedBox(height: 16),
                ScheduleAnalysisCard(
                  applianceType: _applianceType,
                  isOwner: widget.isOwner,
                  onApply: _applySuggestion,
                  onCreateManual: _showAddScheduleDialog,
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Your Schedules',
                  subtitle: _schedules.isEmpty
                      ? 'No schedules created yet'
                      : '${_schedules.length} active schedule(s)',
                ),
                const SizedBox(height: 12),
                if (_schedules.isEmpty)
                  EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'No schedules yet',
                    description:
                        'Create a schedule or apply a smart suggestion to control your relay automatically.',
                    actionLabel: widget.isOwner ? 'Create Schedule' : null,
                    onAction: widget.isOwner ? _showAddScheduleDialog : null,
                  )
                else
                  ..._schedules.map((entry) {
                    final id = entry.key.toString();
                    final schedule = Map<dynamic, dynamic>.from(entry.value);
                    return _scheduleCard(id, schedule);
                  }),
              ],
            ),
    );
  }

  Widget _scheduleCard(String id, Map<dynamic, dynamic> schedule) {
    final name = schedule['name']?.toString() ?? 'Schedule';
    final repeat = schedule['repeat']?.toString() ?? 'Every Day';
    final enabled = schedule['enabled'] == true;
    final action = schedule['action']?.toString() ?? 'ON';
    final start = _formatTime(schedule, 'start');
    final end = _formatTime(schedule, 'end');
    final actionColor = action == 'OFF' ? AppColors.error : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? actionColor.withValues(alpha: 0.2)
              : AppColors.border(0.06),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tint(actionColor, 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  action == 'OFF' ? Icons.power_off_rounded : Icons.bolt_rounded,
                  color: actionColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$start → $end',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: widget.isOwner
                    ? (v) => _toggleSchedule(id, v)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(Icons.repeat, repeat),
              const SizedBox(width: 8),
              _infoChip(Icons.power_settings_new, 'Relay $action', actionColor),
              const Spacer(),
              if (widget.isOwner)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deleteSchedule(id),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, [Color? color]) {
    final chipColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(chipColor, 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: chipColor, fontSize: 12)),
        ],
      ),
    );
  }
}
