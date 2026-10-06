import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref("SmartMeter");

  Stream<DatabaseEvent> getEnergyData() {
    return _db.onValue;
  }

  Future<void> relayOn() async {
    await _db.child("relay").set(true);
  }

  Future<void> relayOff() async {
    await _db.child("relay").set(false);
  }

  Future<void> setScheduleMode(String mode) async {
    await _db.child("scheduleMode").set(mode);
  }

  Future<String> getScheduleMode() async {
    final snapshot = await _db.child("scheduleMode").get();
    return snapshot.value?.toString() ?? "manual";
  }
}
