import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_value_text.dart';
import '../widgets/empty_state.dart';
import '../widgets/energy_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final FirebaseService firebaseService = FirebaseService();

  double readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool readBoolean(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.primary, 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Smart Energy Meter'),
          ],
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: firebaseService.getEnergyData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Connection Error',
              description: 'Unable to load data from Firebase.\n${snapshot.error}',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: ShimmerLoading(itemCount: 5),
            );
          }

          final rawData = snapshot.data?.snapshot.value;

          if (rawData == null || rawData is! Map) {
            return const EmptyState(
              icon: Icons.sensors_off_rounded,
              title: 'No Meter Data',
              description: 'Waiting for ESP32 to send readings to Firebase.',
            );
          }

          final data = Map<dynamic, dynamic>.from(rawData);

          final voltage = readNumber(data, 'voltage');
          final current = readNumber(data, 'current');
          final power = readNumber(data, 'power');
          final energy = readNumber(data, 'energy');
          final frequency = readNumber(data, 'frequency');
          final powerFactor = readNumber(data, 'powerFactor');
          final relayOn = readBoolean(data, 'relay');
          final scheduleMode = data['scheduleMode']?.toString() ?? 'manual';
          final isAutoMode = scheduleMode == 'auto';

          return LayoutBuilder(
            builder: (context, constraints) {
              final wideScreen = constraints.maxWidth >= 800;

              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 800));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLivePowerCard(power: power, relayOn: relayOn),
                          const SizedBox(height: 24),
                          const SectionHeader(
                            title: 'Live Measurements',
                            subtitle: 'Real-time sensor readings from PZEM',
                          ),
                          const SizedBox(height: 14),
                          GridView.count(
                            crossAxisCount: wideScreen ? 3 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: wideScreen ? 2.4 : 1.45,
                            children: [
                              EnergyCard(
                                icon: Icons.electric_bolt_rounded,
                                title: 'Voltage',
                                value: '${voltage.toStringAsFixed(1)} V',
                                color: AppColors.amber,
                              ),
                              EnergyCard(
                                icon: Icons.cable_rounded,
                                title: 'Current',
                                value: '${current.toStringAsFixed(3)} A',
                                color: AppColors.blue,
                              ),
                              EnergyCard(
                                icon: Icons.power_rounded,
                                title: 'Power',
                                value: '${power.toStringAsFixed(1)} W',
                                color: AppColors.orange,
                              ),
                              EnergyCard(
                                icon: Icons.battery_charging_full_rounded,
                                title: 'Energy',
                                value: '${energy.toStringAsFixed(3)} kWh',
                                color: AppColors.primary,
                              ),
                              EnergyCard(
                                icon: Icons.speed_rounded,
                                title: 'Frequency',
                                value: '${frequency.toStringAsFixed(1)} Hz',
                                color: AppColors.purple,
                              ),
                              EnergyCard(
                                icon: Icons.analytics_rounded,
                                title: 'Power Factor',
                                value: powerFactor.toStringAsFixed(2),
                                color: AppColors.cyan,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildScheduleModeBanner(isAutoMode),
                          const SizedBox(height: 14),
                          _buildRelayControl(context, relayOn, isAutoMode),
                          const SizedBox(height: 24),
                          _buildSystemStatus(
                            voltage: voltage,
                            frequency: frequency,
                            powerFactor: powerFactor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLivePowerCard({required double power, required bool relayOn}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Energy Monitoring',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedValueText(
                  value: '${power.toStringAsFixed(1)} W',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  relayOn ? 'Appliance running' : 'Appliance off',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              relayOn ? Icons.bolt_rounded : Icons.power_off_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleModeBanner(bool isAutoMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isAutoMode
            ? AppColors.tint(AppColors.primary, 0.12)
            : AppColors.tint(AppColors.info, 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAutoMode
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.info.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAutoMode ? Icons.auto_mode_rounded : Icons.touch_app_outlined,
            color: isAutoMode ? AppColors.primary : AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAutoMode
                  ? 'Auto mode — relay follows your schedules'
                  : 'Manual mode — control relay from here',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayControl(BuildContext context, bool relayOn, bool isAutoMode) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: relayOn
                  ? AppColors.tint(AppColors.primary, 0.16)
                  : AppColors.tint(AppColors.error, 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: relayOn ? AppColors.primary : AppColors.error,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Relay Control',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  isAutoMode
                      ? 'Switch to Manual on Schedule screen'
                      : relayOn
                      ? 'Connected appliance is ON'
                      : 'Connected appliance is OFF',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: relayOn,
            onChanged: isAutoMode
                ? null
                : (value) async {
                    HapticFeedback.lightImpact();
                    if (value) {
                      await firebaseService.relayOn();
                    } else {
                      await firebaseService.relayOff();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus({
    required double voltage,
    required double frequency,
    required double powerFactor,
  }) {
    final voltageNormal = voltage >= 200 && voltage <= 250;
    final frequencyNormal = frequency >= 49 && frequency <= 51;
    final powerFactorGood = powerFactor >= 0.8;
    final allHealthy = voltageNormal && frequencyNormal && powerFactorGood;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (allHealthy ? AppColors.primary : AppColors.warning)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tint(
                allHealthy ? AppColors.primary : AppColors.warning,
                0.14,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              allHealthy
                  ? Icons.health_and_safety_rounded
                  : Icons.warning_amber_rounded,
              color: allHealthy ? AppColors.primary : AppColors.warning,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Health',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  allHealthy
                      ? 'Electrical conditions are normal'
                      : 'Some values need attention',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tint(
                allHealthy ? AppColors.primary : AppColors.warning,
                0.14,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              allHealthy ? 'HEALTHY' : 'CHECK',
              style: TextStyle(
                color: allHealthy ? AppColors.primary : AppColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
