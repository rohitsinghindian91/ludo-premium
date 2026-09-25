import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

FirebaseDatabase? _rtdb;
FirebaseDatabase getRtdb() {
  if (_rtdb == null) {
    _rtdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: "https://ludo-premium-50-e427e-default-rtdb.asia-southeast1.firebasedatabase.app",
    );
    try {
      _rtdb!.setPersistenceEnabled(true);
      _rtdb!.setPersistenceCacheSizeBytes(10000000);
    } catch (_) {}
    _rtdb!.goOnline();
  }
  return _rtdb!;
}