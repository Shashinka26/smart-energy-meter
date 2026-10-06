import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/gradient_header_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('SmartMeter').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: ShimmerLoading(itemCount: 4),
            );
          }

          final raw = snapshot.data?.snapshot.value;
          final data =
              raw is Map ? Map<dynamic, dynamic>.from(raw) : <dynamic, dynamic>{};

          final energy = _readNumber(data, 'energy');
          final relay = data['relay'] == true;
          final mode = data['scheduleMode']?.toString() ?? 'manual';
          const tariff = 45.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientHeaderCard(
                      icon: Icons.person_rounded,
                      title: 'Smart Energy User',
                      subtitle: 'Final Year Project — IoT Energy Monitoring System',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'v1.0.0',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(
                      title: 'Account Overview',
                      subtitle: 'Device and billing preferences',
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.35,
                      children: [
                        StatCard(
                          icon: Icons.payments_outlined,
                          title: 'Tariff Rate',
                          value: 'Rs. ${tariff.toStringAsFixed(0)}',
                          subtitle: 'per kWh',
                          color: AppColors.amber,
                        ),
                        StatCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'Est. Bill',
                          value: 'Rs. ${(energy * tariff).toStringAsFixed(2)}',
                          subtitle: 'current session',
                          color: AppColors.primary,
                        ),
                        StatCard(
                          icon: Icons.power_settings_new_rounded,
                          title: 'Relay Status',
                          value: relay ? 'ON' : 'OFF',
                          color: relay ? AppColors.primary : AppColors.error,
                        ),
                        StatCard(
                          icon: Icons.auto_mode_rounded,
                          title: 'Control Mode',
                          value: mode == 'auto' ? 'Auto' : 'Manual',
                          color: AppColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'System Info'),
                    const SizedBox(height: 14),
                    _infoTile(
                      context,
                      icon: Icons.memory_rounded,
                      title: 'Hardware',
                      value: 'ESP32 + PZEM-004T + Relay',
                    ),
                    _infoTile(
                      context,
                      icon: Icons.cloud_outlined,
                      title: 'Backend',
                      value: 'Firebase Realtime Database',
                    ),
                    _infoTile(
                      context,
                      icon: Icons.phone_android_rounded,
                      title: 'Application',
                      value: 'Flutter Cross-platform App',
                    ),
                    _infoTile(
                      context,
                      icon: Icons.psychology_outlined,
                      title: 'AI Assistant',
                      value: 'Gemini via Firebase AI',
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.primary, 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const SizedBox(height: 10),
      ],
    );
  }
}
