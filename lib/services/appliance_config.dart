import 'package:flutter/material.dart';

enum ApplianceType {
  notSet,
  waterHeater,
  washingMachine,
  iron,
  riceCooker,
  fan,
  airConditioner,
  electricKettle,
  microwave,
  tv,
  computer,
  laptopCharger,
  phoneCharger,
  hairDryer,
  lamp,
  refrigerator,
  blender,
  other,
}

enum ScheduleSuggestionKind {
  insufficientData,
  lowPower,
  advisory,
  schedulable,
}

class ApplianceProfile {
  const ApplianceProfile({
    required this.type,
    required this.label,
    required this.storageKey,
    required this.category,
    required this.icon,
    this.advisoryOnly = false,
    this.useFullDayOffWindow = false,
    this.typicalLowPower = false,
  });

  final ApplianceType type;
  final String label;
  final String storageKey;
  final String category;
  final IconData icon;
  final bool advisoryOnly;
  final bool useFullDayOffWindow;
  final bool typicalLowPower;
}

class ApplianceConfig {
  ApplianceConfig._();

  static const double lowPowerSkipThresholdW = 100;
  static const int minimumDataDays = 3;
  static const int defaultOffWindowHours = 3;
  static const int dayTariffStartHour = 6;
  static const int dayTariffEndHour = 18;

  static const List<ApplianceProfile> profiles = [
    ApplianceProfile(
      type: ApplianceType.waterHeater,
      label: 'Water Heater',
      storageKey: 'water_heater',
      category: 'Heating & Cooling',
      icon: Icons.water_drop_outlined,
      useFullDayOffWindow: true,
    ),
    ApplianceProfile(
      type: ApplianceType.airConditioner,
      label: 'Air Conditioner',
      storageKey: 'air_conditioner',
      category: 'Heating & Cooling',
      icon: Icons.ac_unit_outlined,
      useFullDayOffWindow: true,
    ),
    ApplianceProfile(
      type: ApplianceType.fan,
      label: 'Fan',
      storageKey: 'fan',
      category: 'Heating & Cooling',
      icon: Icons.air_outlined,
      typicalLowPower: true,
    ),
    ApplianceProfile(
      type: ApplianceType.washingMachine,
      label: 'Washing Machine',
      storageKey: 'washing_machine',
      category: 'Laundry',
      icon: Icons.local_laundry_service_outlined,
      useFullDayOffWindow: true,
    ),
    ApplianceProfile(
      type: ApplianceType.iron,
      label: 'Iron',
      storageKey: 'iron',
      category: 'Laundry',
      icon: Icons.iron_outlined,
      advisoryOnly: true,
    ),
    ApplianceProfile(
      type: ApplianceType.riceCooker,
      label: 'Rice Cooker',
      storageKey: 'rice_cooker',
      category: 'Kitchen',
      icon: Icons.rice_bowl_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.electricKettle,
      label: 'Electric Kettle',
      storageKey: 'electric_kettle',
      category: 'Kitchen',
      icon: Icons.coffee_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.microwave,
      label: 'Microwave',
      storageKey: 'microwave',
      category: 'Kitchen',
      icon: Icons.microwave_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.refrigerator,
      label: 'Refrigerator',
      storageKey: 'refrigerator',
      category: 'Kitchen',
      icon: Icons.kitchen_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.blender,
      label: 'Blender',
      storageKey: 'blender',
      category: 'Kitchen',
      icon: Icons.blender_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.tv,
      label: 'TV',
      storageKey: 'tv',
      category: 'Electronics',
      icon: Icons.tv_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.computer,
      label: 'Computer / Desktop',
      storageKey: 'computer',
      category: 'Electronics',
      icon: Icons.computer_outlined,
    ),
    ApplianceProfile(
      type: ApplianceType.laptopCharger,
      label: 'Laptop Charger',
      storageKey: 'laptop_charger',
      category: 'Electronics',
      icon: Icons.laptop_mac_outlined,
      typicalLowPower: true,
    ),
    ApplianceProfile(
      type: ApplianceType.phoneCharger,
      label: 'Phone Charger',
      storageKey: 'phone_charger',
      category: 'Electronics',
      icon: Icons.phone_android_outlined,
      typicalLowPower: true,
    ),
    ApplianceProfile(
      type: ApplianceType.hairDryer,
      label: 'Hair Dryer',
      storageKey: 'hair_dryer',
      category: 'Personal Care',
      icon: Icons.dry_outlined,
      advisoryOnly: true,
    ),
    ApplianceProfile(
      type: ApplianceType.lamp,
      label: 'Lamp / Light',
      storageKey: 'lamp',
      category: 'Lighting',
      icon: Icons.lightbulb_outline,
      typicalLowPower: true,
    ),
    ApplianceProfile(
      type: ApplianceType.other,
      label: 'Other',
      storageKey: 'other',
      category: 'Other',
      icon: Icons.electrical_services_outlined,
    ),
  ];

  static List<String> get categories {
    final seen = <String>{};
    final result = <String>[];
    for (final profile in profiles) {
      if (seen.add(profile.category)) {
        result.add(profile.category);
      }
    }
    return result;
  }

  static List<ApplianceProfile> profilesInCategory(String category) {
    return profiles.where((profile) => profile.category == category).toList();
  }

  static ApplianceProfile profileFor(ApplianceType type) {
    if (type == ApplianceType.notSet) {
      return const ApplianceProfile(
        type: ApplianceType.notSet,
        label: 'Not set',
        storageKey: '',
        category: '',
        icon: Icons.device_unknown_outlined,
      );
    }

    return profiles.firstWhere(
      (profile) => profile.type == type,
      orElse: () => profiles.last,
    );
  }

  static ApplianceType fromStorageKey(String? value) {
    if (value == null || value.isEmpty) {
      return ApplianceType.notSet;
    }

    for (final profile in profiles) {
      if (profile.storageKey == value) {
        return profile.type;
      }
    }

    return ApplianceType.other;
  }

  static String adviceFor({
    required ApplianceProfile profile,
    required String peakHours,
    required int peakHour,
    required bool isHighTariffPeak,
  }) {
    final label = profile.label;

    if (profile.typicalLowPower) {
      return '$label: Low power device — auto scheduling saves little. '
          'Use the Add button if you want a custom schedule.';
    }

    if (profile.advisoryOnly) {
      if (isHighTariffPeak) {
        return '$label: You use most power at $peakHours (expensive hours). '
            'Use after 6 PM to save cost. Create a manual schedule if you want relay control.';
      }
      return '$label: Peak usage is at $peakHours. '
          'Use after 6 PM when possible to save cost.';
    }

    if (profile.useFullDayOffWindow) {
      return '$label: Avoid running 6 AM - 6 PM (peak tariff). '
          'Best time: after 6 PM.';
    }

    if (isHighTariffPeak) {
      return '$label: Avoid $peakHours (high tariff). Use after 6 PM to save cost.';
    }

    return '$label: Good time to use (low tariff).';
  }

  static String suggestionTitleFor(ApplianceProfile profile) {
    if (profile.typicalLowPower) {
      return '${profile.label} — Low Power';
    }
    if (profile.advisoryOnly) {
      return '${profile.label} Advice';
    }
    if (profile.useFullDayOffWindow) {
      return 'Suggested OFF: 6 AM - 6 PM';
    }
    return 'Suggested OFF';
  }
}
