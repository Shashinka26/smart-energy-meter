import 'package:firebase_database/firebase_database.dart';

import 'appliance_config.dart';
import 'monthly_usage_service.dart';

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
  final ScheduleSuggestionKind kind;
  final String suggestionTitle;
  final String scheduleName;
  final int dataDaysUsed;
  final ApplianceType applianceType;

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
    required this.kind,
    required this.suggestionTitle,
    required this.scheduleName,
    required this.dataDaysUsed,
    required this.applianceType,
  });

  bool get canApply => kind == ScheduleSuggestionKind.schedulable;
}

class ScheduleModelService {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'UsageHistory',
  );

  String getTariff(int hour) {
    if (hour >= ApplianceConfig.dayTariffStartHour &&
        hour <= ApplianceConfig.dayTariffEndHour) {
      return 'HIGH';
    }
    return 'LOW';
  }

  double estimateAvoidedCost(double kwh) {
    return kwh * MonthlyUsageService.tariffPerKwh;
  }

  Future<ScheduleSuggestion?> analyzeUsage({
    ApplianceType applianceType = ApplianceType.notSet,
  }) async {
    final snapshot = await _historyRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final dates = Map<dynamic, dynamic>.from(snapshot.value as Map);
    if (dates.isEmpty) {
      return null;
    }

    final dataDaysUsed = dates.length;
    final profile = ApplianceConfig.profileFor(applianceType);

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

    if (dataDaysUsed < ApplianceConfig.minimumDataDays) {
      return _buildSuggestion(
        profile: profile,
        applianceType: applianceType,
        dataDaysUsed: dataDaysUsed,
        peakHour: hourlyPower.keys.first,
        lowHour: hourlyPower.keys.first,
        peakAvg: 0,
        lowAvg: 0,
        offDurationHours: ApplianceConfig.defaultOffWindowHours,
        kind: ScheduleSuggestionKind.insufficientData,
        tariffAdvice:
            'Need at least ${ApplianceConfig.minimumDataDays} days of meter readings '
            '(currently $dataDaysUsed day${dataDaysUsed == 1 ? '' : 's'}).',
        applianceAdvice:
            'Keep the smart plug connected. Suggestions appear after more usage history is collected.',
      );
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

    final offDurationHours = profile.useFullDayOffWindow
        ? (ApplianceConfig.dayTariffEndHour - ApplianceConfig.dayTariffStartHour)
        : ApplianceConfig.defaultOffWindowHours;

    final suggestedStartHour = profile.useFullDayOffWindow
        ? ApplianceConfig.dayTariffStartHour
        : peakHour;
    final suggestedEndHour = profile.useFullDayOffWindow
        ? ApplianceConfig.dayTariffEndHour
        : (peakHour + offDurationHours) % 24;

    final isHighTariffPeak = getTariff(peakHour) == 'HIGH';
    final peakHoursLabel = profile.useFullDayOffWindow
        ? _formatHourRange(
            ApplianceConfig.dayTariffStartHour,
            offDurationHours,
          )
        : _formatHourRange(peakHour, offDurationHours);

    final isLowPowerAppliance = profile.typicalLowPower;
    final isLowPowerReading =
        peakAvg < ApplianceConfig.lowPowerSkipThresholdW;

    if (applianceType != ApplianceType.notSet &&
        (isLowPowerAppliance || isLowPowerReading)) {
      final lowPowerMessage = isLowPowerAppliance
          ? '${profile.label} is a low power device — auto scheduling saves little.'
          : 'Peak usage is only ${peakAvg.toStringAsFixed(1)} W — scheduling will not save much.';

      return _buildSuggestion(
        profile: profile,
        applianceType: applianceType,
        dataDaysUsed: dataDaysUsed,
        peakHour: peakHour,
        lowHour: lowHour,
        peakAvg: peakAvg,
        lowAvg: lowAvg,
        offDurationHours: offDurationHours,
        suggestedStartHour: suggestedStartHour,
        suggestedEndHour: suggestedEndHour,
        peakHoursLabel: peakHoursLabel,
        kind: ScheduleSuggestionKind.lowPower,
        tariffAdvice: lowPowerMessage,
        applianceAdvice: ApplianceConfig.adviceFor(
          profile: profile,
          peakHours: _formatHourRange(peakHour, offDurationHours),
          peakHour: peakHour,
          isHighTariffPeak: isHighTariffPeak,
        ),
      );
    }

    final kind = profile.advisoryOnly
        ? ScheduleSuggestionKind.advisory
        : ScheduleSuggestionKind.schedulable;

    return _buildSuggestion(
      profile: profile,
      applianceType: applianceType,
      dataDaysUsed: dataDaysUsed,
      peakHour: peakHour,
      lowHour: lowHour,
      peakAvg: peakAvg,
      lowAvg: lowAvg,
      offDurationHours: offDurationHours,
      suggestedStartHour: suggestedStartHour,
      suggestedEndHour: suggestedEndHour,
      peakHoursLabel: peakHoursLabel,
      kind: kind,
      tariffAdvice:
          'Peak tariff window is 6 AM - 6 PM (${getTariff(peakHour)} tariff detected at peak usage).',
      applianceAdvice: ApplianceConfig.adviceFor(
        profile: profile,
        peakHours: _formatHourRange(peakHour, offDurationHours),
        peakHour: peakHour,
        isHighTariffPeak: isHighTariffPeak,
      ),
    );
  }

  ScheduleSuggestion _buildSuggestion({
    required ApplianceProfile profile,
    required ApplianceType applianceType,
    required int dataDaysUsed,
    required int peakHour,
    required int lowHour,
    required double peakAvg,
    required double lowAvg,
    required int offDurationHours,
    int? suggestedStartHour,
    int? suggestedEndHour,
    String? peakHoursLabel,
    required ScheduleSuggestionKind kind,
    required String tariffAdvice,
    required String applianceAdvice,
  }) {
    final startHour = suggestedStartHour ?? peakHour;
    final endHour = suggestedEndHour ?? ((peakHour + offDurationHours) % 24);
    final peakLabel =
        peakHoursLabel ?? _formatHourRange(peakHour, offDurationHours);

    final savingsKwh = (peakAvg / 1000) * offDurationHours * 30;
    final estimatedSavings = kind == ScheduleSuggestionKind.schedulable
        ? estimateAvoidedCost(savingsKwh)
        : 0.0;

    final suggestionTitle = kind == ScheduleSuggestionKind.insufficientData
        ? 'Collecting Usage Data'
        : kind == ScheduleSuggestionKind.lowPower
            ? 'Low Power Usage'
            : '${ApplianceConfig.suggestionTitleFor(profile)}${profile.useFullDayOffWindow ? '' : ': $peakLabel'}';

    final scheduleName = profile.type == ApplianceType.notSet
        ? 'Smart Suggested OFF'
        : 'Smart Suggested OFF - ${profile.label}';

    return ScheduleSuggestion(
      peakHours: peakLabel,
      lowHours: _formatHourRange(lowHour, ApplianceConfig.defaultOffWindowHours),
      peakAveragePower: peakAvg,
      lowAveragePower: lowAvg,
      suggestedStartHour: startHour,
      suggestedStartMinute: 0,
      suggestedEndHour: endHour,
      suggestedEndMinute: 0,
      estimatedMonthlySavings: estimatedSavings,
      tariffAdvice: tariffAdvice,
      applianceAdvice: applianceAdvice,
      kind: kind,
      suggestionTitle: suggestionTitle,
      scheduleName: scheduleName,
      dataDaysUsed: dataDaysUsed,
      applianceType: applianceType,
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
