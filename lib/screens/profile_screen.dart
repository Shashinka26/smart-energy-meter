import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/billing_settings_service.dart';
import '../services/monthly_usage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_header_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/stat_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _cebBillController = TextEditingController();
  final _fixedLoadsController = TextEditingController();

  StreamSubscription<BillingSettings>? _settingsSubscription;
  BillingSettings _settings = const BillingSettings();
  bool _loadingSettings = true;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _settingsSubscription =
        BillingSettingsService.instance.watchSettings().listen((settings) {
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loadingSettings = false;
        _syncControllers(settings);
      });
    });
  }

  Future<void> _loadSettings() async {
    final settings = await BillingSettingsService.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loadingSettings = false;
      _syncControllers(settings);
    });
  }

  void _syncControllers(BillingSettings settings) {
    _cebBillController.text = settings.lastMonthCebBill > 0
        ? settings.lastMonthCebBill.toStringAsFixed(0)
        : '';
    _fixedLoadsController.text = settings.fixedLoadsKwhPerDay > 0
        ? settings.fixedLoadsKwhPerDay.toStringAsFixed(2)
        : '';
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _cebBillController.dispose();
    _fixedLoadsController.dispose();
    super.dispose();
  }

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _saveBillingSettings() async {
    final cebBill = double.tryParse(_cebBillController.text.trim()) ?? 0;
    final fixedLoads = double.tryParse(_fixedLoadsController.text.trim()) ?? 0;

    setState(() => _savingSettings = true);

    try {
      await BillingSettingsService.instance.saveSettings(
        BillingSettings(
          lastMonthCebBill: cebBill.clamp(0, double.infinity),
          fixedLoadsKwhPerDay: fixedLoads.clamp(0, double.infinity),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing settings saved')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save settings: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingSettings = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? 'Unknown user';

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
          const tariff = MonthlyUsageService.tariffPerKwh;

          return FutureBuilder<MonthlyUsageSummary?>(
            future: MonthlyUsageService.instance.loadSummary(),
            builder: (context, monthlySnapshot) {
              final monthlyBill = monthlySnapshot.data?.currentMonth.bill;
              final monthlyKwh = monthlySnapshot.data?.currentMonth.kwh;
              final billLabel = monthlyBill != null
                  ? 'Rs. ${monthlyBill.toStringAsFixed(2)}'
                  : 'Rs. ${(energy * tariff).toStringAsFixed(2)}';
              final billSubtitle = monthlyKwh != null
                  ? '${monthlyKwh.toStringAsFixed(2)} kWh — connected load'
                  : 'connected appliance only';

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
                          title: email,
                          subtitle: widget.isOwner
                              ? 'Device Owner — full relay control'
                              : 'Viewer — monitor only, no relay control',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.isOwner ? 'OWNER' : 'VIEWER',
                              style: const TextStyle(
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
                              title: 'Connected Load Bill',
                              value: billLabel,
                              subtitle: billSubtitle,
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
                        const SectionHeader(
                          title: 'Whole House Estimate',
                          subtitle:
                              'Calibrate from your last CEB bill and add unmonitored loads',
                        ),
                        const SizedBox(height: 14),
                        _buildBillingSettingsCard(),
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => AuthService.instance.signOut(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign Out'),
                          ),
                        ),
                      ],
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

  Widget _buildBillingSettingsCard() {
    if (_loadingSettings) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(0.06)),
        ),
        child: const Text(
          'Loading billing settings...',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The smart plug monitors one connected appliance. Use these settings to estimate your full household bill.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cebBillController,
            enabled: widget.isOwner,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Last Month CEB Bill (Rs.)',
              hintText: 'e.g. 5000',
              helperText:
                  'Used with last month\'s plug reading to calibrate whole-house estimate',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _fixedLoadsController,
            enabled: widget.isOwner,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Fixed Loads (kWh/day)',
              hintText: 'e.g. 2.5',
              helperText:
                  'Daily usage for fridge, lights, fans — not on the smart plug',
              border: OutlineInputBorder(),
            ),
          ),
          if (!widget.isOwner) ...[
            const SizedBox(height: 12),
            const Text(
              'Only the device owner can edit billing settings.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (widget.isOwner) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingSettings ? null : _saveBillingSettings,
                icon: _savingSettings
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_savingSettings ? 'Saving...' : 'Save Billing Settings'),
              ),
            ),
          ],
          if (_settings.hasWholeHouseInputs) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.cyan, 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.tint(AppColors.cyan, 0.25)),
              ),
              child: Text(
                _settings.hasCalibration && _settings.hasFixedLoads
                    ? 'Calibration + fixed loads active. See Analytics for whole-house estimate.'
                    : _settings.hasCalibration
                        ? 'CEB calibration active. See Analytics for whole-house estimate.'
                        : 'Fixed loads added. See Analytics for whole-house estimate.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
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
