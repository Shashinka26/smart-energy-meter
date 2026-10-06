import 'package:firebase_database/firebase_database.dart';

class ScheduleSuggestion {
  final String peakHours;
  final String lowHours;
  final double peakAveragePower;
  final double lowAveragePower;
  final int suggestedStartHour;
  final int suggestedStartMinute;
  final int suggestedEndHour;
  final int suggestedEndMinute;
  final double estimatedMonthlySavings;
  final String tariffAdvice;
  final String applianceAdvice;

  const ScheduleSuggestion({
    required this.peakHours,
    required this.lowHours,
    required this.peakAveragePower,
    required this.lowAveragePower,
    required this.suggestedStartHour,
    required this.suggestedStartMinute,
    required this.suggestedEndHour,
    required this.suggestedEndMinute,
    required this.estimatedMonthlySavings,
    required this.tariffAdvice,
    required this.applianceAdvice,
  });
}

class ScheduleModelService {
  static const double highTariffPerKwh = 30;
  static const double lowTariffPerKwh = 22;

  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'UsageHistory',
  );

  String getTariff(int hour) {
    if (hour >= 6 && hour <= 18) {
      return 'HIGH';
    }
    return 'LOW';
  }

  String suggestApplianceUse(String appliance, int hour) {
    if (getTariff(hour) == 'HIGH') {
      return '$appliance: Avoid now (high tariff). Use after 6 PM to save cost.';
    }
    return '$appliance: Good time to use (low tariff).';
  }

  double estimateSavings(double kwh) {
    final normalCost = kwh * highTariffPerKwh;
    final optimizedCost = kwh * lowTariffPerKwh;
    return normalCost - optimizedCost;
  }

  Future<ScheduleSuggestion?> analyzeUsage() async {
    final snapshot = await _historyRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final dates = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (dates.isEmpty) {
      return null;
    }

    final hourlyPower = <int, List<double>>{};

    for (final dateEntry in dates.entries) {
      final dayData = Map<dynamic, dynamic>.from(dateEntry.value as Map);

      for (final readingEntry in dayData.entries) {
        final timeKey = readingEntry.key.toString();
        final parts = timeKey.split('-');

        if (parts.length != 2) {
          continue;
        }

        final hour = int.tryParse(parts[0]);
        if (hour == null) {
          continue;
        }

        final reading = Map<dynamic, dynamic>.from(readingEntry.value as Map);
        final power = _readNumber(reading, 'power');

        hourlyPower.putIfAbsent(hour, () => []).add(power);
      }
    }

    if (hourlyPower.isEmpty) {
      return null;
    }

    final hourlyAverage = <int, double>{};

    for (final entry in hourlyPower.entries) {
      hourlyAverage[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    int peakHour = hourlyAverage.keys.first;
    int lowHour = hourlyAverage.keys.first;
    double peakAvg = hourlyAverage.values.first;
    double lowAvg = hourlyAverage.values.first;

    for (final entry in hourlyAverage.entries) {
      if (entry.value > peakAvg) {
        peakAvg = entry.value;
        peakHour = entry.key;
      }
      if (entry.value < lowAvg) {
        lowAvg = entry.value;
        lowHour = entry.key;
      }
    }

    final highTariffHours = hourlyAverage.entries
        .where((entry) => getTariff(entry.key) == 'HIGH')
        .toList();

    if (highTariffHours.isNotEmpty) {
      highTariffHours.sort((a, b) => b.value.compareTo(a.value));
      peakHour = highTariffHours.first.key;
      peakAvg = highTariffHours.first.value;
    }

    final suggestedStartHour = peakHour;
    final suggestedEndHour = (peakHour + 3) % 24;

    final savingsKwh = (peakAvg / 1000) * 3 * 30;
    final estimatedSavings = estimateSavings(savingsKwh);

    return ScheduleSuggestion(
      peakHours: _formatHourRange(peakHour, 3),
      lowHours: _formatHourRange(lowHour, 3),
      peakAveragePower: peakAvg,
      lowAveragePower: lowAvg,
      suggestedStartHour: suggestedStartHour,
      suggestedStartMinute: 0,
      suggestedEndHour: suggestedEndHour,
      suggestedEndMinute: 0,
      estimatedMonthlySavings: estimatedSavings,
      tariffAdvice:
          'Peak tariff window is 6 AM - 6 PM (${getTariff(peakHour)} tariff detected at peak usage).',
      applianceAdvice: suggestApplianceUse('Heavy appliances', peakHour),
    );
  }

  double _readNumber(Map<dynamic, dynamic> data, String key) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatHourRange(int startHour, int durationHours) {
    final endHour = (startHour + durationHours) % 24;
    return '${_formatHour(startHour)} - ${_formatHour(endHour)}';
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:00 $period';
  }
}
