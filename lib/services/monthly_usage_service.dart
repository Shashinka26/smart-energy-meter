import 'package:firebase_database/firebase_database.dart';

class MonthUsageData {
  final String monthKey;
  final String label;
  final double kwh;
  final double bill;
  final int readingCount;

  const MonthUsageData({
    required this.monthKey,
    required this.label,
    required this.kwh,
    required this.bill,
    required this.readingCount,
  });
}

class MonthlyUsageSummary {
  final MonthUsageData currentMonth;
  final MonthUsageData? previousMonth;
  final String comparisonMessage;
  final double? percentChange;
  final double projectedEndOfMonthKwh;
  final double projectedEndOfMonthBill;
  final double dailyAverageKwh;
  final double dailyAverageBill;
  final int dayOfMonth;
  final int daysInMonth;
  final bool hasEnoughData;
  final double maxHistoryEnergy;
  final DateTime? latestReadingAt;

  const MonthlyUsageSummary({
    required this.currentMonth,
    required this.previousMonth,
    required this.comparisonMessage,
    required this.percentChange,
    required this.projectedEndOfMonthKwh,
    required this.projectedEndOfMonthBill,
    required this.dailyAverageKwh,
    required this.dailyAverageBill,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.hasEnoughData,
    this.maxHistoryEnergy = 0,
    this.latestReadingAt,
  });
}

class _UsageReading {
  final DateTime timestamp;
  final double power;
  final double energy;

  const _UsageReading({
    required this.timestamp,
    required this.power,
    required this.energy,
  });
}

class MonthlyUsageService {
  MonthlyUsageService._();

  static final MonthlyUsageService instance = MonthlyUsageService._();

  static const double tariffPerKwh = 45;
  static const double readingIntervalHours = 5 / 60;

  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'UsageHistory',
  );

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<MonthlyUsageSummary?> loadSummary({DateTime? now}) async {
    final snapshot = await _historyRef.get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final referenceTime = now ?? DateTime.now();
    final readingsByMonth = _groupReadingsByMonth(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );

    if (readingsByMonth.isEmpty) {
      return null;
    }

    final currentKey = _monthKey(referenceTime);
    final previousKey = _monthKey(
      DateTime(referenceTime.year, referenceTime.month - 1, 1),
    );

    final currentReadings = readingsByMonth[currentKey] ?? [];
    final currentMonth = _buildMonthUsage(
      monthKey: currentKey,
      readings: currentReadings,
    );

    if (currentMonth.readingCount == 0) {
      return null;
    }

    final maxHistoryEnergy = _maxEnergyInReadings(currentReadings);
    final latestReadingAt = _latestReadingAt(currentReadings);

    final previousReadings = readingsByMonth[previousKey];
    final previousMonth = previousReadings != null && previousReadings.isNotEmpty
        ? _buildMonthUsage(monthKey: previousKey, readings: previousReadings)
        : null;

    final daysInMonth = DateTime(
      referenceTime.year,
      referenceTime.month + 1,
      0,
    ).day;
    final dayOfMonth = referenceTime.day.clamp(1, daysInMonth);
    final progress = dayOfMonth / daysInMonth;

    final projectedKwh = progress > 0
        ? currentMonth.kwh / progress
        : currentMonth.kwh;
    final projectedBill = projectedKwh * tariffPerKwh;
    final dailyAverageKwh =
        dayOfMonth > 0 ? currentMonth.kwh / dayOfMonth : currentMonth.kwh;
    final dailyAverageBill = dailyAverageKwh * tariffPerKwh;

    final comparison = _buildComparison(
      current: currentMonth,
      previous: previousMonth,
    );

    return MonthlyUsageSummary(
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      comparisonMessage: comparison.message,
      percentChange: comparison.percentChange,
      projectedEndOfMonthKwh: projectedKwh,
      projectedEndOfMonthBill: projectedBill,
      dailyAverageKwh: dailyAverageKwh,
      dailyAverageBill: dailyAverageBill,
      dayOfMonth: dayOfMonth,
      daysInMonth: daysInMonth,
      hasEnoughData: currentMonth.readingCount >= 2,
      maxHistoryEnergy: maxHistoryEnergy,
      latestReadingAt: latestReadingAt,
    );
  }

  MonthlyUsageSummary applyLiveMeterReading(
    MonthlyUsageSummary base, {
    required double liveEnergyKwh,
    required double livePowerW,
  }) {
    var kwh = base.currentMonth.kwh;

    if (liveEnergyKwh > base.maxHistoryEnergy && base.maxHistoryEnergy > 0) {
      kwh = base.currentMonth.kwh + (liveEnergyKwh - base.maxHistoryEnergy);
    } else if (base.latestReadingAt != null && livePowerW > 0) {
      final hours =
          DateTime.now().difference(base.latestReadingAt!).inSeconds / 3600.0;
      if (hours > 0 && hours <= 6) {
        final estimated =
            base.currentMonth.kwh + livePowerW / 1000 * hours;
        if (estimated > kwh) {
          kwh = estimated;
        }
      }
    }

    if ((kwh - base.currentMonth.kwh).abs() < 0.00001) {
      return base;
    }

    final bill = kwh * tariffPerKwh;
    final progress = base.dayOfMonth / base.daysInMonth;
    final projectedKwh = progress > 0 ? kwh / progress : kwh;
    final projectedBill = projectedKwh * tariffPerKwh;
    final dailyAverageKwh =
        base.dayOfMonth > 0 ? kwh / base.dayOfMonth : kwh;
    final dailyAverageBill = dailyAverageKwh * tariffPerKwh;

    final currentMonth = MonthUsageData(
      monthKey: base.currentMonth.monthKey,
      label: base.currentMonth.label,
      kwh: kwh,
      bill: bill,
      readingCount: base.currentMonth.readingCount,
    );

    final comparison = _buildComparison(
      current: currentMonth,
      previous: base.previousMonth,
    );

    return MonthlyUsageSummary(
      currentMonth: currentMonth,
      previousMonth: base.previousMonth,
      comparisonMessage: comparison.message,
      percentChange: comparison.percentChange,
      projectedEndOfMonthKwh: projectedKwh,
      projectedEndOfMonthBill: projectedBill,
      dailyAverageKwh: dailyAverageKwh,
      dailyAverageBill: dailyAverageBill,
      dayOfMonth: base.dayOfMonth,
      daysInMonth: base.daysInMonth,
      hasEnoughData: base.hasEnoughData,
      maxHistoryEnergy: base.maxHistoryEnergy,
      latestReadingAt: base.latestReadingAt,
    );
  }

  Future<MonthUsageData?> loadPreviousMonthBill({DateTime? now}) async {
    final snapshot = await _historyRef.get();
    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final referenceTime = now ?? DateTime.now();
    final readingsByMonth = _groupReadingsByMonth(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );

    final previousKey = _monthKey(
      DateTime(referenceTime.year, referenceTime.month - 1, 1),
    );
    final previousReadings = readingsByMonth[previousKey];

    if (previousReadings == null || previousReadings.isEmpty) {
      return null;
    }

    return _buildMonthUsage(
      monthKey: previousKey,
      readings: previousReadings,
    );
  }

  String previousMonthLabel({DateTime? now}) {
    final referenceTime = now ?? DateTime.now();
    final previousKey = _monthKey(
      DateTime(referenceTime.year, referenceTime.month - 1, 1),
    );
    return _formatMonthLabel(previousKey);
  }

  Map<String, List<_UsageReading>> _groupReadingsByMonth(
    Map<dynamic, dynamic> history,
  ) {
    final grouped = <String, List<_UsageReading>>{};

    for (final dateEntry in history.entries) {
      final dateKey = dateEntry.key.toString();
      if (dateKey.length < 10) {
        continue;
      }

      final monthKey = dateKey.substring(0, 7);
      final dayData = Map<dynamic, dynamic>.from(dateEntry.value as Map);

      for (final readingEntry in dayData.entries) {
        final reading = _parseReading(dateKey, readingEntry.key.toString(), readingEntry.value);
        if (reading == null) {
          continue;
        }

        grouped.putIfAbsent(monthKey, () => []).add(reading);
      }
    }

    for (final readings in grouped.values) {
      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return grouped;
  }

  _UsageReading? _parseReading(
    String dateKey,
    String timeKey,
    dynamic rawValue,
  ) {
    if (rawValue is! Map) {
      return null;
    }

    final reading = Map<dynamic, dynamic>.from(rawValue);
    final parts = timeKey.split('-');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    final dateParts = dateKey.split('-');
    if (dateParts.length != 3) {
      return null;
    }

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    return _UsageReading(
      timestamp: DateTime(year, month, day, hour, minute),
      power: _readNumber(reading, 'power'),
      energy: _readNumber(reading, 'energy'),
    );
  }

  MonthUsageData _buildMonthUsage({
    required String monthKey,
    required List<_UsageReading> readings,
  }) {
    final kwh = _estimateKwh(readings);
    return MonthUsageData(
      monthKey: monthKey,
      label: _formatMonthLabel(monthKey),
      kwh: kwh,
      bill: kwh * tariffPerKwh,
      readingCount: readings.length,
    );
  }

  double _maxEnergyInReadings(List<_UsageReading> readings) {
    var maxEnergy = 0.0;
    for (final reading in readings) {
      if (reading.energy > maxEnergy) {
        maxEnergy = reading.energy;
      }
    }
    return maxEnergy;
  }

  DateTime? _latestReadingAt(List<_UsageReading> readings) {
    if (readings.isEmpty) {
      return null;
    }
    return readings.last.timestamp;
  }

  double _estimateKwh(List<_UsageReading> readings) {
    if (readings.isEmpty) {
      return 0;
    }

    if (readings.length == 1) {
      return readings.first.power / 1000 * readingIntervalHours;
    }

    final energies = readings.map((reading) => reading.energy).where((value) => value > 0).toList();
    if (energies.length >= 2) {
      final minEnergy = energies.reduce((a, b) => a < b ? a : b);
      final maxEnergy = energies.reduce((a, b) => a > b ? a : b);
      final delta = maxEnergy - minEnergy;
      if (delta > 0) {
        return delta;
      }
    }

    var total = 0.0;
    for (final reading in readings) {
      total += reading.power / 1000 * readingIntervalHours;
    }
    return total;
  }

  ({String message, double? percentChange}) _buildComparison({
    required MonthUsageData current,
    required MonthUsageData? previous,
  }) {
    if (previous == null || previous.readingCount == 0) {
      return (
        message:
            'This month: ${current.kwh.toStringAsFixed(2)} kWh (Rs. ${current.bill.toStringAsFixed(0)}). '
            'Last month data is not available yet — keep the meter running to compare.',
        percentChange: null,
      );
    }

    final diff = current.kwh - previous.kwh;
    final absDiff = diff.abs();
    final percent = previous.kwh > 0 ? (diff / previous.kwh) * 100 : null;

    if (diff > 0.01) {
      final percentText = percent == null ? '' : ' (${percent.toStringAsFixed(0)}% higher)';
      return (
        message:
            'This month: ${current.kwh.toStringAsFixed(2)} kWh | '
            'Last month: ${previous.kwh.toStringAsFixed(2)} kWh — '
            '${absDiff.toStringAsFixed(2)} kWh more$percentText.',
        percentChange: percent,
      );
    }

    if (diff < -0.01) {
      final percentText = percent == null ? '' : ' (${percent.abs().toStringAsFixed(0)}% lower)';
      return (
        message:
            'This month: ${current.kwh.toStringAsFixed(2)} kWh | '
            'Last month: ${previous.kwh.toStringAsFixed(2)} kWh — '
            '${absDiff.toStringAsFixed(2)} kWh less$percentText. Good progress!',
        percentChange: percent,
      );
    }

    return (
      message:
          'This month: ${current.kwh.toStringAsFixed(2)} kWh | '
          'Last month: ${previous.kwh.toStringAsFixed(2)} kWh — usage is about the same.',
      percentChange: 0,
    );
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _formatMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return monthKey;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }

    return '${_monthNames[month - 1]} $year';
  }

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
