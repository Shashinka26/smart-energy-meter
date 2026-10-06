import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/bill_prediction_service.dart';
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
  final BillPredictionService _billService = BillPredictionService.instance;

  StreamSubscription<DatabaseEvent>? _subscription;

  final List<FlSpot> _powerSpots = [];

  double _power = 0;
  double _energy = 0;
  double _voltage = 0;
  double _current = 0;
  double _mlBill = 0;
  String _billSource = 'Loading ML model...';

  int _pointIndex = 0;

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _updateMlBill() async {
    final result = await _billService.predict(
      voltage: _voltage,
      current: _current,
      power: _power,
    );

    if (!mounted) return;

    setState(() {
      _mlBill = result.bill;
      _billSource = result.source;
    });
  }

  @override
  void initState() {
    super.initState();

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

      _updateMlBill();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  double get _energyBasedCost {
    return _billService.predictFromEnergyKwh(_energy);
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
      appBar: AppBar(title: const Text('Energy Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryGrid(isNormal),
                const SizedBox(height: 16),
                _buildMlPredictionCard(),
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
    );
  }

  Widget _buildMlPredictionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.model_training_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'ML Bill Prediction',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Rs. ${_mlBill.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Live prediction from Voltage, Current, and Power readings',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Source: $_billSource',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
              title: 'Energy Cost',
              value: 'Rs. ${_energyBasedCost.toStringAsFixed(2)}',
              subtitle: 'energy × Rs. 45/kWh',
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
          _overviewRow(
            title: 'ML Predicted Bill',
            value: 'Rs. ${_mlBill.toStringAsFixed(2)}',
          ),
          _overviewRow(
            title: 'Energy',
            value: '${_energy.toStringAsFixed(3)} kWh',
            showDivider: false,
          ),
        ],
      ),
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
