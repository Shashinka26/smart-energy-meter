import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import '../services/schedule_model_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_header_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final DatabaseReference _scheduleRef = FirebaseDatabase.instance.ref(
    'Schedules',
  );
  final FirebaseService _firebaseService = FirebaseService();
  final ScheduleModelService _scheduleModelService = ScheduleModelService();

  final List<String> _repeatOptions = [
    'Once',
    'Every Day',
    'Weekdays',
    'Weekends',
  ];

  Stream<DatabaseEvent> get _scheduleStream => _scheduleRef.onValue;

  Future<void> _applySuggestion(ScheduleSuggestion suggestion) async {
    final newSchedule = _scheduleRef.push();

    await newSchedule.set({
      'name': 'Smart Suggested OFF',
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

  String _formatTime(Map<dynamic, dynamic> data, String prefix) {
    final hour = (data['${prefix}Hour'] ?? 0) as int;
    final minute = (data['${prefix}Minute'] ?? 0) as int;
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  Widget _buildAnalysisCard() {
    return FutureBuilder<ScheduleSuggestion?>(
      future: _scheduleModelService.analyzeUsage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: ShimmerLoading(itemCount: 1));
        }

        final suggestion = snapshot.data;

        if (suggestion == null) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border(0.06)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Usage Analysis',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Collecting usage history from your smart meter. '
                  'Check back after a few hours for schedule suggestions.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Usage Analysis',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _analysisRow(
                'Peak usage',
                '${suggestion.peakHours} (${suggestion.peakAveragePower.toStringAsFixed(1)} W avg)',
              ),
              const SizedBox(height: 8),
              _analysisRow(
                'Low usage',
                '${suggestion.lowHours} (${suggestion.lowAveragePower.toStringAsFixed(1)} W avg)',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.primary, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text(
                'Suggested OFF: ${suggestion.peakHours}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                suggestion.tariffAdvice,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                suggestion.applianceAdvice,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Save ~Rs. ${suggestion.estimatedMonthlySavings.toStringAsFixed(0)}/month',
                style: const TextStyle(color: AppColors.primary),
              ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _applySuggestion(suggestion),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Apply Suggestion'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _analysisRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildModeCard() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('SmartMeter/scheduleMode').onValue,
      builder: (context, snapshot) {
        final mode = snapshot.data?.snapshot.value?.toString() ?? 'manual';
        final isAuto = mode == 'auto';

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
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  _firebaseService.setScheduleMode(value ? 'auto' : 'manual');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _scheduleStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to Load',
              description: 'Could not load schedules from Firebase.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: ShimmerLoading(itemCount: 4),
            );
          }

          final value = snapshot.data?.snapshot.value;
          final schedules = value == null
              ? <MapEntry<dynamic, dynamic>>[]
              : Map<dynamic, dynamic>.from(value as Map).entries.toList();

          return ListView(
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
              _buildAnalysisCard(),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Your Schedules',
                subtitle: schedules.isEmpty ? 'No schedules created yet' : '${schedules.length} active schedule(s)',
              ),
              const SizedBox(height: 12),
              if (schedules.isEmpty)
                EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No schedules yet',
                  description:
                      'Create a schedule or apply a smart suggestion to control your relay automatically.',
                  actionLabel: 'Create Schedule',
                  onAction: _showAddScheduleDialog,
                )
              else
                ...schedules.map((entry) {
                  final id = entry.key.toString();
                  final schedule = Map<dynamic, dynamic>.from(entry.value);
                  return _scheduleCard(id, schedule);
                }),
            ],
          );
        },
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
              Switch(value: enabled, onChanged: (v) => _toggleSchedule(id, v)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(Icons.repeat, repeat),
              const SizedBox(width: 8),
              _infoChip(Icons.power_settings_new, 'Relay $action', actionColor),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteSchedule(id),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
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
