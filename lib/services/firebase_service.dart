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
}
