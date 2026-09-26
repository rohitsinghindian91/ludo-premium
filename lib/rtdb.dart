import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

FirebaseDatabase? _rtdb;

FirebaseDatabase getRtdb() {
  if (_rtdb == null) {
    _rtdb = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: "https://ludo-premium-50-e427e-default-rtdb.asia-southeast1.firebasedatabase.app",
    );
    // Persistence hata diya hai - isi se T0/T1 desync ho raha tha
    _rtdb!.goOnline();
  }
  return _rtdb!;
}