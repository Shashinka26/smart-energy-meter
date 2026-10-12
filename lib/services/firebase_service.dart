import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref('SmartMeter');

  Stream<DatabaseEvent> getEnergyData() {
    return _db.onValue;
  }

  Future<void> relayOn() async {
    _ensureOwner();
    await _db.child('relayCommand').set(true);
    await _db.child('relay').set(true);
  }

  Future<void> relayOff() async {
    _ensureOwner();
    await _db.child('relayCommand').set(false);
    await _db.child('relay').set(false);
  }

  Future<void> setScheduleMode(String mode) async {
    _ensureOwner();
    await _db.child('scheduleMode').set(mode);
  }

  Future<String> getScheduleMode() async {
    final snapshot = await _db.child('scheduleMode').get();
    return snapshot.value?.toString() ?? 'manual';
  }

  void _ensureOwner() {
    if (!AuthService.instance.isOwner) {
      throw StateError('Only the device owner can control the relay.');
    }
  }
}
