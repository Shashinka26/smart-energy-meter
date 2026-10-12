import 'package:firebase_database/firebase_database.dart';

import 'monthly_usage_service.dart';

class BillingSettings {
  final double lastMonthCebBill;
  final double fixedLoadsKwhPerDay;

  const BillingSettings({
    this.lastMonthCebBill = 0,
    this.fixedLoadsKwhPerDay = 0,
  });

  bool get hasCalibration => lastMonthCebBill > 0;
  bool get hasFixedLoads => fixedLoadsKwhPerDay > 0;
  bool get hasWholeHouseInputs => hasCalibration || hasFixedLoads;

  BillingSettings copyWith({
    double? lastMonthCebBill,
    double? fixedLoadsKwhPerDay,
  }) {
    return BillingSettings(
      lastMonthCebBill: lastMonthCebBill ?? this.lastMonthCebBill,
      fixedLoadsKwhPerDay: fixedLoadsKwhPerDay ?? this.fixedLoadsKwhPerDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastMonthCebBill': lastMonthCebBill,
      'fixedLoadsKwhPerDay': fixedLoadsKwhPerDay,
    };
  }

  factory BillingSettings.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
      return const BillingSettings();
    }

    return BillingSettings(
      lastMonthCebBill: _readNumber(raw, 'lastMonthCebBill'),
      fixedLoadsKwhPerDay: _readNumber(raw, 'fixedLoadsKwhPerDay'),
    );
  }

  static double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class WholeHouseEstimate {
  final double connectedBillSoFar;
  final double connectedProjectedBill;
  final double fixedLoadsBillSoFar;
  final double fixedLoadsProjectedBill;
  final double wholeHouseBillSoFar;
  final double wholeHouseProjectedBill;
  final double? calibrationFactor;
  final bool hasCalibration;
  final bool hasFixedLoads;

  const WholeHouseEstimate({
    required this.connectedBillSoFar,
    required this.connectedProjectedBill,
    required this.fixedLoadsBillSoFar,
    required this.fixedLoadsProjectedBill,
    required this.wholeHouseBillSoFar,
    required this.wholeHouseProjectedBill,
    required this.calibrationFactor,
    required this.hasCalibration,
    required this.hasFixedLoads,
  });

  bool get isAvailable => hasCalibration || hasFixedLoads;

  String get disclaimer {
    if (!isAvailable) {
      return 'Add your last CEB bill or fixed daily loads in Profile to estimate whole-house usage.';
    }

    final parts = <String>[];
    if (hasCalibration) {
      parts.add('calibrated from last CEB bill');
    }
    if (hasFixedLoads) {
      parts.add('includes unmonitored fixed loads');
    }
    return 'Estimated whole-house bill (${parts.join(' + ')}). Not an official CEB bill.';
  }
}

class BillingSettingsService {
  BillingSettingsService._();

  static final BillingSettingsService instance = BillingSettingsService._();

  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref(
    'BillingSettings',
  );

  BillingSettings _cached = const BillingSettings();

  BillingSettings get cached => _cached;

  Future<BillingSettings> loadSettings() async {
    final snapshot = await _settingsRef.get();
    if (!snapshot.exists || snapshot.value == null) {
      _cached = const BillingSettings();
      return _cached;
    }

    _cached = BillingSettings.fromMap(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
    return _cached;
  }

  Stream<BillingSettings> watchSettings() {
    return _settingsRef.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _cached = const BillingSettings();
        return _cached;
      }

      _cached = BillingSettings.fromMap(
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
      );
      return _cached;
    });
  }

  Future<void> saveSettings(BillingSettings settings) async {
    await _settingsRef.update(settings.toMap());
    _cached = settings;
  }

  WholeHouseEstimate estimate({
    required MonthlyUsageSummary summary,
    BillingSettings? settings,
  }) {
    final config = settings ?? _cached;
    final tariff = MonthlyUsageService.tariffPerKwh;

    final fixedKwhSoFar = config.fixedLoadsKwhPerDay * summary.dayOfMonth;
    final fixedBillSoFar = fixedKwhSoFar * tariff;
    final fixedProjectedBill =
        config.fixedLoadsKwhPerDay * summary.daysInMonth * tariff;

    final connectedBillSoFar = summary.currentMonth.bill;
    final connectedProjectedBill = summary.projectedEndOfMonthBill;

    double? calibrationFactor;
    var scaledConnectedSoFar = connectedBillSoFar;
    var scaledConnectedProjected = connectedProjectedBill;

    final previousPlugBill = summary.previousMonth?.bill ?? 0;
    if (config.lastMonthCebBill > 0 && previousPlugBill > 0) {
      calibrationFactor = config.lastMonthCebBill / previousPlugBill;
      scaledConnectedSoFar = connectedBillSoFar * calibrationFactor;
      scaledConnectedProjected = connectedProjectedBill * calibrationFactor;
    }

    return WholeHouseEstimate(
      connectedBillSoFar: connectedBillSoFar,
      connectedProjectedBill: connectedProjectedBill,
      fixedLoadsBillSoFar: fixedBillSoFar,
      fixedLoadsProjectedBill: fixedProjectedBill,
      wholeHouseBillSoFar: scaledConnectedSoFar + fixedBillSoFar,
      wholeHouseProjectedBill: scaledConnectedProjected + fixedProjectedBill,
      calibrationFactor: calibrationFactor,
      hasCalibration: calibrationFactor != null,
      hasFixedLoads: config.hasFixedLoads,
    );
  }
}
