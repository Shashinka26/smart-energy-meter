import 'package:firebase_database/firebase_database.dart';

import 'appliance_config.dart';

class ApplianceSettingsService {
  ApplianceSettingsService._();

  static final ApplianceSettingsService instance = ApplianceSettingsService._();

  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref(
    'BillingSettings',
  );

  ApplianceType _cached = ApplianceType.notSet;

  ApplianceType get cached => _cached;

  ApplianceType _typeFromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return ApplianceType.notSet;
    }

    final raw = snapshot.value;
    if (raw is Map) {
      final map = Map<dynamic, dynamic>.from(raw);
      return ApplianceConfig.fromStorageKey(
        map['connectedAppliance']?.toString(),
      );
    }

    return ApplianceType.notSet;
  }

  Future<ApplianceType> loadAppliance() async {
    final snapshot = await _settingsRef.get();
    _cached = _typeFromSnapshot(snapshot);
    return _cached;
  }

  Stream<ApplianceType> watchAppliance() {
    return _settingsRef.onValue.map((event) {
      _cached = _typeFromSnapshot(event.snapshot);
      return _cached;
    });
  }

  Future<void> saveAppliance(ApplianceType type) async {
    if (type == ApplianceType.notSet) {
      await _settingsRef.child('connectedAppliance').remove();
    } else {
      final key = ApplianceConfig.profileFor(type).storageKey;
      await _settingsRef.child('connectedAppliance').set(key);
    }
    _cached = type;
  }
}
