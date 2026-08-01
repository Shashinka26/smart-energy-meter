import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseReference _smartMeterRef = FirebaseDatabase.instance.ref(
    'SmartMeter',
  );

  StreamSubscription<DatabaseEvent>? _subscription;

  final List<FlSpot> _powerSpots = [];

  double _power = 0;
  double _energy = 0;
  double _voltage = 0;
  double _current = 0;

  int _pointIndex = 0;

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();

    _subscription = _smartMeterRef.onValue.listen((event) {
      final rawData = event.snapshot.value;

      if (rawData == null || rawData is! Map) {
        return;
      }

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
    super.dispose();
  }

  double get _estimatedCost {
    const double sampleRatePerKwh = 45;
    return _energy * sampleRatePerKwh;
  }

  double get _maximumChartValue {
    if (_powerSpots.isEmpty) {
      return 10;
    }

    double maximum = _powerSpots.first.y;

    for (final spot in _powerSpots) {
      if (spot.y > maximum) {
        maximum = spot.y;
      }
    }

    if (maximum < 5) {
      return 5;
    }

    return maximum * 1.3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09110D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09110D),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Energy Analytics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryGrid(),
                const SizedBox(height: 24),
                const Text(
                  'Live Power Consumption',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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

  Widget _buildSummaryGrid() {
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
            _summaryCard(
              icon: Icons.electric_bolt_rounded,
              title: 'Live Power',
              value: '${_power.toStringAsFixed(1)} W',
              color: Colors.orangeAccent,
            ),
            _summaryCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'Total Energy',
              value: '${_energy.toStringAsFixed(3)} kWh',
              color: Colors.greenAccent,
            ),
            _summaryCard(
              icon: Icons.payments_outlined,
              title: 'Estimated Cost',
              value: 'Rs. ${_estimatedCost.toStringAsFixed(2)}',
              color: Colors.amberAccent,
            ),
            _summaryCard(
              icon: Icons.monitor_heart_outlined,
              title: 'Status',
              value: _voltage >= 200 && _voltage <= 250 ? 'Normal' : 'Check',
              color:
                  _voltage >= 200 && _voltage <= 250
                      ? Colors.cyanAccent
                      : Colors.redAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17211C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerChart() {
    return Container(
      height: 340,
      padding: const EdgeInsets.fromLTRB(18, 24, 24, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17211C),
        borderRadius: BorderRadius.circular(22),
      ),
      child:
          _powerSpots.length < 2
              ? const Center(
                child: Text(
                  'Collecting live power data...',
                  style: TextStyle(color: Colors.white60),
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
                        color: Colors.white.withOpacity(0.08),
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
                              color: Colors.white54,
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
                        (index) =>
                            FlSpot(index.toDouble(), _powerSpots[index].y),
                      ),
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.greenAccent,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.greenAccent.withOpacity(0.12),
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
        color: const Color(0xFF17211C),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Electrical Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _overviewRow(
            title: 'Voltage',
            value: '${_voltage.toStringAsFixed(1)} V',
          ),
          _overviewRow(
            title: 'Current',
            value: '${_current.toStringAsFixed(3)} A',
          ),
          _overviewRow(title: 'Power', value: '${_power.toStringAsFixed(1)} W'),
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
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
      ],
    );
  }
}
