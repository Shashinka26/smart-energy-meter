import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BillPredictionResult {
  final double bill;
  final String source;

  const BillPredictionResult({
    required this.bill,
    required this.source,
  });
}

class BillPredictionService {
  BillPredictionService._();

  static final BillPredictionService instance = BillPredictionService._();

  static const String backendBaseUrl = String.fromEnvironment(
    'ML_BACKEND_URL',
    defaultValue: '',
  );

  Map<String, dynamic>? _modelConfig;
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString('assets/ml_model.json');
    _modelConfig = jsonDecode(raw) as Map<String, dynamic>;
    _loaded = true;
  }

  Future<BillPredictionResult> predict({
    required double voltage,
    required double current,
    required double power,
  }) async {
    await ensureLoaded();

    if (backendBaseUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('$backendBaseUrl/predict').replace(
          queryParameters: {
            'voltage': voltage.toString(),
            'current': current.toString(),
            'power': power.toString(),
          },
        );

        final response = await http.get(uri).timeout(
          const Duration(seconds: 4),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return BillPredictionResult(
            bill: (data['bill'] as num).toDouble(),
            source: 'Python ML Backend',
          );
        }
      } catch (_) {
        // Fall back to on-device coefficients.
      }
    }

    return BillPredictionResult(
      bill: _predictLocal(voltage: voltage, current: current, power: power),
      source: 'On-device ML Model',
    );
  }

  double _predictLocal({
    required double voltage,
    required double current,
    required double power,
  }) {
    final config = _modelConfig!;
    final coefficients = Map<String, dynamic>.from(
      config['coefficients'] as Map,
    );
    final intercept = (config['intercept'] as num).toDouble();

    return intercept +
        (coefficients['voltage'] as num).toDouble() * voltage +
        (coefficients['current'] as num).toDouble() * current +
        (coefficients['power'] as num).toDouble() * power;
  }

  double predictFromEnergyKwh(double energyKwh, {double tariffPerKwh = 45}) {
    return energyKwh * tariffPerKwh;
  }
}
