import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/billing_settings_service.dart';
import '../services/monthly_usage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseReference _smartMeterRef = FirebaseDatabase.instance.ref(
    'SmartMeter',
  );
  final MonthlyUsageService _monthlyService = MonthlyUsageService.instance;
  final BillingSettingsService _billingSettingsService =
      BillingSettingsService.instance;
  final DatabaseReference _usageHistoryRef = FirebaseDatabase.instance.ref(
    'UsageHistory',
  );

  StreamSubscription<DatabaseEvent>? _subscription;
  StreamSubscription<DatabaseEvent>? _historySubscription;
  StreamSubscription<BillingSettings>? _billingSettingsSubscription;
  Timer? _monthlyReloadDebounce;

  final List<FlSpot> _powerSpots = [];

  double _power = 0;
  double _energy = 0;
  double _voltage = 0;
  double _current = 0;
  MonthlyUsageSummary? _monthlySummary;
  BillingSettings _billingSettings = const BillingSettings();
  bool _loadingMonthly = true;
  bool _checkingPreviousMonth = false;
  String? _monthlyError;

  int _pointIndex = 0;

  MonthlyUsageSummary? get _billSummary {
    final base = _monthlySummary;
    if (base == null) {
      return null;
    }

    return _monthlyService.applyLiveMeterReading(
      base,
      liveEnergyKwh: _energy,
      livePowerW: _power,
    );
  }

  WholeHouseEstimate? get _wholeHouseEstimate {
    final summary = _billSummary;
    if (summary == null || !summary.hasEnoughData) {
      return null;
    }

    return _billingSettingsService.estimate(
      summary: summary,
      settings: _billingSettings,
    );
  }

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _showPreviousMonthBillDialog() async {
    setState(() => _checkingPreviousMonth = true);

    try {
      final previous = _monthlySummary?.previousMonth ??
          await _monthlyService.loadPreviousMonthBill();

      if (!mounted) {
        return;
      }

      final current = _billSummary?.currentMonth;
      final monthLabel = previous?.label ??
          _monthlyService.previousMonthLabel();

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Previous Month Bill'),
            content: previous == null
                ? Text(
                    'No UsageHistory readings found for $monthLabel.\n\n'
                    'Keep the ESP32 meter running through a full month to store last month\'s bill.',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _dialogRow('Usage', '${previous.kwh.toStringAsFixed(2)} kWh'),
                      _dialogRow(
                        'Bill',
                        'Rs. ${previous.bill.toStringAsFixed(2)}',
                      ),
                      _dialogRow(
                        'Tariff',
                        'Rs. ${MonthlyUsageService.tariffPerKwh.toStringAsFixed(0)}/kWh',
                      ),
                      _dialogRow(
                        'Readings',
                        '${previous.readingCount} saved samples',
                        showDivider: false,
                      ),
                      if (current != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          _formatMonthComparison(current: current, previous: previous),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _checkingPreviousMonth = false);
      }
    }
  }

  String _formatMonthComparison({
    required MonthUsageData current,
    required MonthUsageData previous,
  }) {
    final diff = current.kwh - previous.kwh;
    final absDiff = diff.abs();

    if (diff > 0.01) {
      final percent = previous.kwh > 0 ? (diff / previous.kwh) * 100 : null;
      final percentText =
          percent == null ? '' : ' (${percent.toStringAsFixed(0)}% higher)';
      return 'This month so far: ${current.kwh.toStringAsFixed(2)} kWh — '
          '${absDiff.toStringAsFixed(2)} kWh more than last month$percentText.';
    }

    if (diff < -0.01) {
      final percent = previous.kwh > 0 ? (diff / previous.kwh) * 100 : null;
      final percentText =
          percent == null ? '' : ' (${percent.abs().toStringAsFixed(0)}% lower)';
      return 'This month so far: ${current.kwh.toStringAsFixed(2)} kWh — '
          '${absDiff.toStringAsFixed(2)} kWh less than last month$percentText.';
    }

    return 'This month usage is about the same as last month so far.';
  }

  Widget _dialogRow(String label, String value, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: AppColors.border(0.06), height: 1),
      ],
    );
  }

  Widget _buildPreviousMonthButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _checkingPreviousMonth ? null : _showPreviousMonthBillDialog,
        icon: _checkingPreviousMonth
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.history_rounded),
        label: Text(
          _checkingPreviousMonth
              ? 'Checking previous month...'
              : 'Check Previous Month Bill',
        ),
      ),
    );
  }

  Future<void> _loadMonthlySummary({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingMonthly = true;
        _monthlyError = null;
      });
    }

    try {
      final summary = await _monthlyService.loadSummary();
      if (!mounted) return;

      setState(() {
        _monthlySummary = summary;
        _loadingMonthly = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _monthlyError = error.toString();
        _loadingMonthly = false;
      });
    }
  }

  void _scheduleMonthlyReload() {
    _monthlyReloadDebounce?.cancel();
    _monthlyReloadDebounce = Timer(const Duration(milliseconds: 800), () {
      _loadMonthlySummary(silent: true);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
    _billingSettingsService.loadSettings().then((settings) {
      if (!mounted) return;
      setState(() => _billingSettings = settings);
    });
    _billingSettingsSubscription =
        _billingSettingsService.watchSettings().listen((settings) {
      if (!mounted) return;
      setState(() => _billingSettings = settings);
    });

    _historySubscription = _usageHistoryRef.onValue.listen((_) {
      _scheduleMonthlyReload();
    });

    _subscription = _smartMeterRef.onValue.listen((event) {
      final rawData = event.snapshot.value;

      if (rawData == null || rawData is! Map) return;

      final data = Map<dynamic, dynamic>.from(rawData);
      final newPower = _readNumber(data, 'power');

      setState(() {
        _power = newPower;
        _energy = _readNumber(data, 'energy');
        _voltage = _readNumber(data, 'voltage');
        _current = _readNumber(data, 'current');

        _powerSpots.add(FlSpot(_pointIndex.toDouble(), newPower));
        _pointIndex++;

        if (_powerSpots.length > 20) {
          _powerSpots.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _historySubscription?.cancel();
    _billingSettingsSubscription?.cancel();
    _monthlyReloadDebounce?.cancel();
    super.dispose();
  }

  double get _maximumChartValue {
    if (_powerSpots.isEmpty) return 10;

    double maximum = _powerSpots.first.y;
    for (final spot in _powerSpots) {
      if (spot.y > maximum) maximum = spot.y;
    }

    if (maximum < 5) return 5;
    return maximum * 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final isNormal = _voltage >= 200 && _voltage <= 250;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh monthly usage',
            onPressed: _loadingMonthly ? null : _loadMonthlySummary,
            icon: _loadingMonthly
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await Future.wait([
            _loadMonthlySummary(),
            Future.delayed(const Duration(milliseconds: 600)),
          ]);
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
                  _buildSummaryGrid(isNormal),
                  const SizedBox(height: 16),
                  _buildFullMonthBillPredictionCard(),
                  const SizedBox(height: 16),
                  _buildWholeHouseEstimateCard(),
                  const SizedBox(height: 16),
                  _buildDailyAverageCard(),
                  const SizedBox(height: 16),
                  _buildMonthlyUsageSection(),
                  const SizedBox(height: 16),
                  _buildAccumulatedBillCard(),
                  const SizedBox(height: 16),
                  _buildBillComparisonCard(),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Live Power Consumption',
                    subtitle: 'Last 20 readings from your smart meter',
                  ),
                  const SizedBox(height: 14),
                  _buildPowerChart(),
                  const SizedBox(height: 24),
                  _buildUsageOverview(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullMonthBillPredictionCard() {
    if (_loadingMonthly) {
      return _buildHeroBillCard(
        title: 'Connected Appliance — Month-End Estimate',
        subtitle: 'Smart plug load only',
        amount: '--',
        detail: 'Calculating accumulated UsageHistory from your connected load',
        accent: AppColors.cyan,
      );
    }

    final summary = _billSummary;
    if (summary == null || !summary.hasEnoughData) {
      return _buildHeroBillCard(
        title: 'Connected Appliance — Month-End Estimate',
        subtitle: 'Smart plug load only',
        amount: '--',
        detail:
            'Keep the IoT meter running. Bill is calculated only from saved 5-minute usage readings of the connected appliance.',
        accent: AppColors.cyan,
      );
    }

    final usedKwh = summary.currentMonth.kwh;
    final projectedKwh = summary.projectedEndOfMonthKwh;
    final projectedBill = summary.projectedEndOfMonthBill;
    final usedBill = summary.currentMonth.bill;
    final dayOfMonth = summary.dayOfMonth;
    final daysInMonth = summary.daysInMonth;
    final dailyKwh = summary.dailyAverageKwh;

    return _buildHeroBillCard(
      title: 'Connected Appliance — Month-End Estimate',
      subtitle: 'Smart plug load — ${summary.currentMonth.label}',
      amount: 'Rs. ${projectedBill.toStringAsFixed(2)}',
      detail:
          'Daily average: ${dailyKwh.toStringAsFixed(3)} kWh/day × $daysInMonth days '
          '→ projected ${projectedKwh.toStringAsFixed(2)} kWh. '
          'Accumulated: ${usedKwh.toStringAsFixed(2)} kWh (day $dayOfMonth of $daysInMonth). '
          'Bill so far: Rs. ${usedBill.toStringAsFixed(2)}. '
          'This is not your whole-house CEB bill.',
      accent: AppColors.cyan,
    );
  }

  Widget _buildWholeHouseEstimateCard() {
    if (_loadingMonthly) {
      return _buildHeroBillCard(
        title: 'Estimated Whole House Bill',
        subtitle: 'Calibrated estimate — not official CEB bill',
        amount: '--',
        detail: 'Loading connected load and billing settings...',
        accent: AppColors.primary,
      );
    }

    final summary = _billSummary;
    final estimate = _wholeHouseEstimate;

    if (summary == null || !summary.hasEnoughData) {
      return _buildHeroBillCard(
        title: 'Estimated Whole House Bill',
        subtitle: 'Calibrated estimate — not official CEB bill',
        amount: '--',
        detail:
            'Collect plug usage first. Then add your last CEB bill and fixed loads in Profile.',
        accent: AppColors.primary,
      );
    }

    if (estimate == null || !estimate.isAvailable) {
      return _buildHeroBillCard(
        title: 'Estimated Whole House Bill',
        subtitle: 'Calibrated estimate — not official CEB bill',
        amount: '--',
        detail:
            'Go to Profile → Whole House Estimate. Enter last month\'s CEB bill and/or fixed daily loads (fridge, lights).',
        accent: AppColors.primary,
      );
    }

    final factorText = estimate.calibrationFactor != null
        ? 'Calibration factor: ×${estimate.calibrationFactor!.toStringAsFixed(2)} '
            '(CEB bill ÷ last month plug bill). '
        : '';
    final fixedText = estimate.hasFixedLoads
        ? 'Fixed loads: Rs. ${estimate.fixedLoadsProjectedBill.toStringAsFixed(2)}/month. '
        : '';

    return _buildHeroBillCard(
      title: 'Estimated Whole House Bill',
      subtitle: 'Calibrated estimate — ${summary.currentMonth.label}',
      amount: 'Rs. ${estimate.wholeHouseProjectedBill.toStringAsFixed(2)}',
      detail:
          '$factorText$fixedText'
          'Connected load projected: Rs. ${estimate.connectedProjectedBill.toStringAsFixed(2)}. '
          'Bill so far: Rs. ${estimate.wholeHouseBillSoFar.toStringAsFixed(2)}. '
          '${estimate.disclaimer}',
      accent: AppColors.primary,
    );
  }

  Widget _buildDailyAverageCard() {
    if (_loadingMonthly) {
      return _buildInfoCard(
        icon: Icons.speed_rounded,
        title: 'Daily Average Usage',
        child: const Text(
          'Calculating average from saved usage readings...',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final summary = _billSummary;
    if (summary == null || !summary.hasEnoughData) {
      return _buildInfoCard(
        icon: Icons.speed_rounded,
        title: 'Daily Average Usage',
        child: const Text(
          'Average daily usage appears after UsageHistory collects readings from your connected appliance.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }

    return _buildInfoCard(
      icon: Icons.speed_rounded,
      title: 'Daily Average Usage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBlock(
                  label: 'Avg. kWh / Day',
                  value: '${summary.dailyAverageKwh.toStringAsFixed(3)} kWh',
                  subValue:
                      '${summary.currentMonth.kwh.toStringAsFixed(2)} kWh ÷ ${summary.dayOfMonth} days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBlock(
                  label: 'Avg. Bill / Day',
                  value:
                      'Rs. ${summary.dailyAverageBill.toStringAsFixed(2)}',
                  subValue:
                      '× ${summary.daysInMonth} days → Rs. ${summary.projectedEndOfMonthBill.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Connected load bill = daily average usage × ${summary.daysInMonth} days × '
            'Rs. ${MonthlyUsageService.tariffPerKwh.toStringAsFixed(0)}/kWh',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBillCard({
    required String title,
    required String subtitle,
    required String amount,
    required String detail,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            amount,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyUsageSection() {
    if (_loadingMonthly) {
      return _buildInfoCard(
        icon: Icons.calendar_month_rounded,
        title: 'Monthly Usage',
        child: const Text(
          'Loading UsageHistory data...',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_monthlyError != null) {
      return _buildInfoCard(
        icon: Icons.error_outline_rounded,
        title: 'Monthly Usage',
        child: Text(
          'Could not load monthly data.\n$_monthlyError',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_monthlySummary == null) {
      return Column(
        children: [
          _buildInfoCard(
            icon: Icons.history_rounded,
            title: 'Monthly Usage',
            child: const Text(
              'No UsageHistory data yet. ESP32 saves readings every 5 minutes — check back after some usage.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          _buildPreviousMonthButton(),
        ],
      );
    }

    final summary = _billSummary!;
    final comparisonColor = summary.percentChange == null
        ? AppColors.info
        : summary.percentChange! > 0
            ? AppColors.orange
            : summary.percentChange! < 0
                ? AppColors.cyan
                : AppColors.primary;

    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.calendar_month_rounded,
          title: 'Monthly Usage — ${summary.currentMonth.label}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _metricBlock(
                      label: 'This Month',
                      value: '${summary.currentMonth.kwh.toStringAsFixed(2)} kWh',
                      subValue:
                          'Rs. ${summary.currentMonth.bill.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricBlock(
                      label: 'Plug Month-End Est.',
                      value:
                          '${summary.projectedEndOfMonthKwh.toStringAsFixed(2)} kWh',
                      subValue:
                          'Rs. ${summary.projectedEndOfMonthBill.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              if (summary.previousMonth != null) ...[
                const SizedBox(height: 14),
                _metricBlock(
                  label: 'Last Month',
                  value:
                      '${summary.previousMonth!.kwh.toStringAsFixed(2)} kWh',
                  subValue:
                      'Rs. ${summary.previousMonth!.bill.toStringAsFixed(0)}',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.tint(comparisonColor, 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.tint(comparisonColor, 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_outlined, color: comparisonColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.comparisonMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildPreviousMonthButton(),
      ],
    );
  }

  Widget _buildAccumulatedBillCard() {
    final summary = _billSummary;
    final hasMonthly = summary != null && summary.hasEnoughData;

    if (_loadingMonthly) {
      return _buildInfoCard(
        icon: Icons.summarize_rounded,
        title: 'Accumulated Usage Bill',
        child: const Text(
          'Loading saved usage readings...',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (!hasMonthly) {
      return _buildInfoCard(
        icon: Icons.summarize_rounded,
        title: 'Accumulated Usage Bill',
        child: const Text(
          'Bill is calculated from total saved usage (UsageHistory), not live power. '
          'Run the IoT meter for a while to collect readings.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }

    final kwh = summary.currentMonth.kwh;
    final bill = summary.currentMonth.bill;
    final readings = summary.currentMonth.readingCount;

    return _buildInfoCard(
      icon: Icons.summarize_rounded,
        title: 'Connected Load Bill — This Month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rs. ${bill.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${kwh.toStringAsFixed(2)} kWh × Rs. ${MonthlyUsageService.tariffPerKwh.toStringAsFixed(0)}/kWh '
            'from $readings saved readings of your connected appliance.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildBillComparisonCard() {
    final summary = _billSummary;
    final monthlyBill = summary?.currentMonth.bill ?? 0;
    final monthlyKwh = summary?.currentMonth.kwh ?? 0;
    final projectedBill = summary?.projectedEndOfMonthBill ?? 0;
    final projectedKwh = summary?.projectedEndOfMonthKwh ?? 0;
    final hasMonthly = summary != null && summary.hasEnoughData;

    return _buildInfoCard(
      icon: Icons.compare_arrows_rounded,
      title: 'Connected Load Bill Summary',
      child: Column(
        children: [
          if (hasMonthly) ...[
            _comparisonRow(
              label: 'Connected Load (This Month)',
              value: 'Rs. ${monthlyBill.toStringAsFixed(2)}',
              hint: '${monthlyKwh.toStringAsFixed(2)} kWh from smart plug so far',
              color: AppColors.orange,
            ),
            _comparisonRow(
              label: 'Plug Month-End Estimate',
              value: 'Rs. ${projectedBill.toStringAsFixed(2)}',
              hint:
                  'Projected ${projectedKwh.toStringAsFixed(2)} kWh from current usage pace',
              color: AppColors.cyan,
            ),
            if (_wholeHouseEstimate?.isAvailable == true)
              _comparisonRow(
                label: 'Whole House Estimate',
                value:
                    'Rs. ${_wholeHouseEstimate!.wholeHouseProjectedBill.toStringAsFixed(2)}',
                hint: _wholeHouseEstimate!.disclaimer,
                color: AppColors.primary,
                showDivider: false,
              )
            else
              _comparisonRow(
                label: 'Whole House Estimate',
                value: 'Not configured',
                hint: 'Add CEB bill or fixed loads in Profile',
                color: AppColors.textMuted,
                showDivider: false,
              ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Bill appears after UsageHistory collects enough readings from the connected load.',
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(bool isNormal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideScreen = constraints.maxWidth >= 800;

        return GridView.count(
          crossAxisCount: wideScreen ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: wideScreen ? 1.7 : 1.35,
          children: [
            StatCard(
              icon: Icons.electric_bolt_rounded,
              title: 'Live Power',
              value: '${_power.toStringAsFixed(1)} W',
              color: AppColors.orange,
            ),
            StatCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'Total Energy',
              value: '${_energy.toStringAsFixed(3)} kWh',
              color: AppColors.primary,
            ),
            StatCard(
              icon: Icons.payments_outlined,
              title: 'Plug Bill So Far',
              value: _billSummary != null && _billSummary!.hasEnoughData
                  ? 'Rs. ${_billSummary!.currentMonth.bill.toStringAsFixed(2)}'
                  : '--',
              subtitle: _billSummary != null && _billSummary!.hasEnoughData
                  ? '${_billSummary!.currentMonth.kwh.toStringAsFixed(2)} kWh — connected load'
                  : 'from saved usage',
              color: AppColors.amber,
            ),
            StatCard(
              icon: Icons.monitor_heart_outlined,
              title: 'Status',
              value: isNormal ? 'Normal' : 'Check',
              color: isNormal ? AppColors.cyan : AppColors.error,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPowerChart() {
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(18, 24, 24, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: _powerSpots.length < 2
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.primary, 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Collecting live power data...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_powerSpots.length}/2 readings',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: _maximumChartValue,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _maximumChartValue / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.border(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List<FlSpot>.generate(
                      _powerSpots.length,
                      (index) => FlSpot(index.toDouble(), _powerSpots[index].y),
                    ),
                    isCurved: true,
                    barWidth: 3,
                    color: AppColors.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUsageOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Electrical Overview'),
          const SizedBox(height: 8),
          _overviewRow(title: 'Voltage', value: '${_voltage.toStringAsFixed(1)} V'),
          _overviewRow(title: 'Current', value: '${_current.toStringAsFixed(3)} A'),
          _overviewRow(title: 'Power', value: '${_power.toStringAsFixed(1)} W'),
          if (_billSummary != null && _billSummary!.hasEnoughData) ...[
            _overviewRow(
              title: 'Daily Average',
              value:
                  '${_billSummary!.dailyAverageKwh.toStringAsFixed(3)} kWh/day',
            ),
            _overviewRow(
              title: 'Accumulated Usage',
              value:
                  '${_billSummary!.currentMonth.kwh.toStringAsFixed(2)} kWh',
            ),
            _overviewRow(
              title: 'Bill So Far',
              value:
                  'Rs. ${_billSummary!.currentMonth.bill.toStringAsFixed(2)}',
            ),
            _overviewRow(
              title: 'Plug Month-End Est.',
              value:
                  'Rs. ${_billSummary!.projectedEndOfMonthBill.toStringAsFixed(2)}',
            ),
            if (_wholeHouseEstimate?.isAvailable == true)
              _overviewRow(
                title: 'Whole House Est.',
                value:
                    'Rs. ${_wholeHouseEstimate!.wholeHouseProjectedBill.toStringAsFixed(2)}',
              ),
          ],
          _overviewRow(
            title: 'Meter Energy',
            value: '${_energy.toStringAsFixed(3)} kWh',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
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
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _metricBlock({
    required String label,
    required String value,
    required String subValue,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.primary, 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subValue,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow({
    required String label,
    required String value,
    required String hint,
    required Color color,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: AppColors.border(0.06), height: 1),
      ],
    );
  }

  Widget _overviewRow({
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(color: AppColors.border(0.06), height: 1),
      ],
    );
  }
}
