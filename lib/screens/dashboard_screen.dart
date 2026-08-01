import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../widgets/energy_card.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final FirebaseService firebaseService = FirebaseService();

  double readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool readBoolean(Map<dynamic, dynamic> data, String key) {
    final value = data[key];

    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
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
          'Smart Energy Meter',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: firebaseService.getEnergyData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Firebase error:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = snapshot.data?.snapshot.value;

          if (rawData == null || rawData is! Map) {
            return const Center(
              child: Text(
                'No SmartMeter data found',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool wideScreen = constraints.maxWidth >= 800;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLivePowerCard(power: power, relayOn: relayOn),
                        const SizedBox(height: 22),

                        const Text(
                          'Live Measurements',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
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
                              color: Colors.amber,
                            ),
                            EnergyCard(
                              icon: Icons.cable_rounded,
                              title: 'Current',
                              value: '${current.toStringAsFixed(3)} A',
                              color: Colors.lightBlueAccent,
                            ),
                            EnergyCard(
                              icon: Icons.power_rounded,
                              title: 'Power',
                              value: '${power.toStringAsFixed(1)} W',
                              color: Colors.orangeAccent,
                            ),
                            EnergyCard(
                              icon: Icons.battery_charging_full_rounded,
                              title: 'Energy',
                              value: '${energy.toStringAsFixed(3)} kWh',
                              color: Colors.greenAccent,
                            ),
                            EnergyCard(
                              icon: Icons.speed_rounded,
                              title: 'Frequency',
                              value: '${frequency.toStringAsFixed(1)} Hz',
                              color: Colors.purpleAccent,
                            ),
                            EnergyCard(
                              icon: Icons.analytics_rounded,
                              title: 'Power Factor',
                              value: powerFactor.toStringAsFixed(2),
                              color: Colors.cyanAccent,
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        _buildRelayControl(relayOn),

                        const SizedBox(height: 22),

                        _buildSystemStatus(
                          voltage: voltage,
                          frequency: frequency,
                          powerFactor: powerFactor,
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

  Widget _buildLivePowerCard({required double power, required bool relayOn}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF126B34), Color(0xFF28873D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Energy Monitoring',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '${power.toStringAsFixed(1)} W',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Current power consumption',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
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

  Widget _buildRelayControl(bool relayOn) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17211C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color:
                  relayOn
                      ? Colors.green.withOpacity(0.16)
                      : Colors.red.withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: relayOn ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Relay Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  relayOn
                      ? 'Connected appliance is ON'
                      : 'Connected appliance is OFF',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          Switch(
            value: relayOn,
            activeColor: Colors.greenAccent,
            onChanged: (value) async {
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
        color: const Color(0xFF17211C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            allHealthy
                ? Icons.health_and_safety_rounded
                : Icons.warning_amber_rounded,
            color: allHealthy ? Colors.greenAccent : Colors.orangeAccent,
            size: 34,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allHealthy
                      ? 'Electrical conditions are operating normally'
                      : 'Some electrical values require attention',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          Text(
            allHealthy ? 'HEALTHY' : 'CHECK',
            style: TextStyle(
              color: allHealthy ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
