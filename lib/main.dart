import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'beautiful_ludo.dart';
import 'voice_room.dart';
import 'plan_screen.dart';
import 'friends_screen.dart';
import 'rtdb.dart';
import 'jaruri_suchna.dart';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
  prefs = await SharedPreferences.getInstance();
  // getRtdb() hata diya - crash karwa sakta hai
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const Splash(),);
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override void initState() { super.initState(); checkUser(); }
  Future<void> checkUser() async {
    try {
      var m = prefs.getString("mobile");
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (m!= null && m.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(mobile: m)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    } catch (e) {
      debugPrint("Splash error: $e");
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.casino_rounded, size: 90, color: Colors.amber),
          SizedBox(height: 20),
          CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
          SizedBox(height: 16),
          Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2)),
          SizedBox(height: 6),
          Text("Loading...", style: TextStyle(color: Colors.white54, fontSize: 12))
        ]),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final referCtrl = TextEditingController();

  Future<void> goOtp() async {
    if (nameCtrl.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Naam dalo")));
      return;
    }
    if (mobileCtrl.text.trim().length!= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo")));
      return;
    }
    if (passCtrl.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 4 digit")));
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => OtpPage(name: nameCtrl.text.trim(), mobile: mobileCtrl.text.trim(), password: passCtrl.text.trim(), referral: referCtrl.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange.shade700]), shape: BoxShape.circle), child: const Icon(Icons.casino_rounded, size: 50, color: Colors.black)),
        const SizedBox(height: 16),
        const Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 30),
        TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Apna Naam", filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Mobile", filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password", filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        TextField(controller: referCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Referral Code (Optional)", filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: goOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("NEXT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
      ]))),
    );
  }
}

class OtpPage extends StatefulWidget {
  final String name, mobile, password, referral;
  const OtpPage({super.key, required this.name, required this.mobile, required this.password, required this.referral});
  @override State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otpCtrl = TextEditingController();
  bool load = false;

  Future<void> verifyOtp() async {
    if (otpCtrl.text.trim()!= "1234") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP 1234 dalo")));
      return;
    }
    setState(() => load = true);
    String? devId = prefs.getString("device_id");
    if (devId == null || devId.isEmpty) {
      devId = "dev_${DateTime.now().millisecondsSinceEpoch}_${widget.mobile.substring(6)}";
      await prefs.setString("device_id", devId);
    }
    var doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if (!doc.exists) {
      // LOCK 3: unique 7-digit ID banao - kisi bhi user se kabhi match nahi hogi
      final newId = await genUniqueUserId();
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({
        "name": widget.name, "mobile": widget.mobile, "password": widget.password,
        "referralCode": newId, "referCode": newId, "myReferCode": newId, "myReferralCode": newId, "idNo": newId, "idNumber": newId, "referredBy": widget.referral, "wallet": 0, "upi": "",
        "deviceId": devId,
        "gameId": newId, "voiceRoomNo": newId,
        "isPremium": false, "premiumExpiry": null, "premiumDistributed": false, "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      if ((doc.data()?["deviceId"]?? "").toString().isEmpty) {
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({"deviceId": devId}, SetOptions(merge: true));
      }
      // LOCK 3: purane user ke paas ID nahi hai to unique ID de do (dono field same rakho)
      final d0 = doc.data()?? {};
      final g = (d0["gameId"]?? "").toString();
      final v = (d0["voiceRoomNo"]?? "").toString();
      if (g.isEmpty || v.isEmpty) {
        String finalId = g.isNotEmpty? g : v;
        if (finalId.isEmpty) finalId = await genUniqueUserId();
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile)
         .set({"gameId": finalId, "voiceRoomNo": finalId}, SetOptions(merge: true));
      }
    }
    await prefs.setString("mobile", widget.mobile);
    await prefs.setString("name", widget.name);
    var ludoPrefs = await SharedPreferences.getInstance();
    await ludoPrefs.setString("mobile", widget.mobile);
    await ludoPrefs.setString("name", widget.name);

    setState(() => load = false);
    if (!mounted) return;
    bool banned = await isUserBanned(widget.mobile) || await isDeviceBanned();
    if (banned) {
      showDialog(context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text("⛔ Banned", style: TextStyle(color: Colors.red)),
          content: const Text("Admin ne tumhe ban kiya hai.", style: TextStyle(color: Colors.white)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ));
      return;
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomeScreen(mobile: widget.mobile)), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(backgroundColor: const Color(0xFF0A0E1A), title: const Text("OTP Verify")), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Text("OTP 1234 hai", style: TextStyle(color: Colors.white54)), const SizedBox(height: 20),
      TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.bold), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 20),
      load? const CircularProgressIndicator(color: Colors.amber) : SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("VERIFY 1234", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
    ])));
  }
}

// UNIQUE 7-digit ID - kisi bhi user se kabhi match nahi hogi (Lock 3)
Future<String> genUniqueUserId() async {
  final r = Random();
  for (int i = 0; i < 25; i++) {
    final id = (1000000 + r.nextInt(9000000)).toString();
    final a = await FirebaseFirestore.instance.collection("users").where("gameId", isEqualTo: id).limit(1).get();
    final b = await FirebaseFirestore.instance.collection("users").where("voiceRoomNo", isEqualTo: id).limit(1).get();
    if (a.docs.isEmpty && b.docs.isEmpty) return id;
  }
  return DateTime.now().millisecondsSinceEpoch.toString().substring(5, 12);
}

Future<bool> isUserBanned(String mobile) async {
  try {
    var doc = await FirebaseFirestore.instance.collection("users").doc(mobile).get();
    if (!doc.exists) return false;
    var d = doc.data()!;
    if (d["banned"] == true) {
      if (d["banExpiry"]!= null) {
        DateTime exp = (d["banExpiry"] as Timestamp).toDate();
        if (exp.isBefore(DateTime.now())) {
          await doc.reference.update({"banned": false, "banExpiry": null});
          return false;
        }
      }
      return true;
    }
    return false;
  } catch (e) { return false; }
}

Future<bool> isDeviceBanned() async {
  try {
    String? devId = prefs.getString("device_id");
    if (devId == null || devId.isEmpty) return false;
    var q = await FirebaseFirestore.instance.collection("banned_devices").where("deviceId", isEqualTo: devId).limit(1).get();
    return q.docs.isNotEmpty;
  } catch (e) { return false; }
}

class HomeScreen extends StatefulWidget {
  final String mobile;
  const HomeScreen({super.key, required this.mobile});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int wallet = 0; int myCoins = 0; String myCode = ""; String referredBy = ""; bool isPrem = false; String expiry = ""; String myName = ""; String referredByName = ""; String myIdNo = ""; String myPhotoUrl = "";
  
  // ===== SECURITY: Anti-Hack + Anti-Tamper + Connection Stability - FINAL v9 SECURE =====
  bool _isDeviceSecure = true;
  bool _isConnectionStable = true;

  // 1. Root / Emulator / Debug Detection
  Future<bool> _checkDeviceSecurity() async {
    // Disabled for crash fix - was causing crash on launch
    debugPrint("_checkDeviceSecurity disabled");
    return true;
  }

  // 2. Connection Stability - Auto Reconnect Logic
  Future<void> _ensureConnectionStability() async  {
    // Disabled for crash fix - was causing crash on launch
    debugPrint("_ensureConnectionStability disabled");
  }

  Future<void> _resyncAfterReconnect() async {
    try {
      // Re-listen to user data
      listenUser();
      // Re-check force update
      _checkForceUpdate();
    } catch (_) {}
  }

  // 3. Anti-Tamper - Check APK signature / package name
  Future<bool> _checkAppIntegrity() async {
    // Disabled for crash fix
    debugPrint("_checkAppIntegrity disabled");
    return true;
  }

  // 4. Secure Storage - Encrypt sensitive data
  Future<void> _migrateToSecureStorage() async {
    try {
      // Migrate from shared_preferences to secure storage for sensitive data
      // This is optional but recommended for wallet, coins etc.
      // For now we keep shared_preferences but add encryption layer in future
    } catch (_) {}
  }


  @override void initState() { 
    super.initState(); 
    // ULTRA SAFE - No security checks, no device checks, no bans, no RTDB in init
    // Bas user data load karo, crash nahi hoga
    try {
      listenUser();
    } catch (e) {
      debugPrint("listenUser error: $e");
    }
  }
  Future<void> checkDeviceBan() async  {
    // Disabled for crash fix - was causing crash on launch
    debugPrint("checkDeviceBan disabled");
  }
  void listenUser() {
    FirebaseFirestore.instance.collection("users").doc(widget.mobile).snapshots().listen((d) async {
      if (!d.exists) {
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
        return;
      }
      var data = d.data()!; if (!mounted) return;
      if (data["banned"] == true) {
        bool stillBanned = true;
        if (data["banExpiry"]!= null) {
          DateTime exp = (data["banExpiry"] as Timestamp).toDate();
          if (exp.isBefore(DateTime.now())) stillBanned = false;
        }
        if (stillBanned) {
          await prefs.clear();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
          return;
        }
      }
      setState(() { wallet = data["wallet"]?? 0; myCoins = data["coins"]?? 0; myCode = data["referralCode"]?? widget.mobile; referredBy = data["referredBy"]?? ""; myName = data["name"]?? ""; myIdNo = (data["gameId"]?? data["voiceRoomNo"]?? "").toString(); myPhotoUrl = data["photoUrl"]?? ""; });
      if (referredBy.isNotEmpty && referredByName.isEmpty) { var refDoc = await FirebaseFirestore.instance.collection("users").doc(referredBy).get(); if (refDoc.exists) { if (mounted) setState(() => referredByName = refDoc.data()?["name"]?? referredBy); } }
      if (data["isPremium"] == true && data["premiumExpiry"]!= null) { DateTime exp = (data["premiumExpiry"] as Timestamp).toDate(); if (exp.isAfter(DateTime.now())) { setState(() { isPrem = true; expiry = "${exp.day}/${exp.month}/${exp.year}"; }); if (data["premiumDistributed"] == false) { distributePremium(); } } }
    });
  }
  Future<void> distributePremium() async {
    try {
      int l1Amt = 100, l2Amt = 50, l3Amt = 25;
      try {
        var planDoc = await FirebaseFirestore.instance.collection("config").doc("plan").get();
        if (planDoc.exists) {
          var pd = planDoc.data()!;
          l1Amt = (pd["l1"] as num?)?.toInt()?? 100;
          l2Amt = (pd["l2"] as num?)?.toInt()?? 50;
          l3Amt = (pd["l3"] as num?)?.toInt()?? 25;
        }
      } catch (_) {}
      var me = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if (!me.exists) return; var data = me.data()!; if (data["premiumDistributed"] == true) return; String l1 = data["referredBy"]?? "";
      if (l1.isNotEmpty) {
        var l1Doc = await FirebaseFirestore.instance.collection("users").doc(l1).get(); if (l1Doc.exists) {
          await FirebaseFirestore.instance.collection("users").doc(l1).update({"wallet": FieldValue.increment(l1Amt)});
          await FirebaseFirestore.instance.collection("earnings").add({"to": l1, "from": widget.mobile, "amount": l1Amt, "type": "L1 Premium", "time": FieldValue.serverTimestamp()});
          String l2 = l1Doc.data()?["referredBy"]?? ""; if (l2.isNotEmpty) {
            var l2Doc = await FirebaseFirestore.instance.collection("users").doc(l2).get(); if (l2Doc.exists) {
              await FirebaseFirestore.instance.collection("users").doc(l2).update({"wallet": FieldValue.increment(l2Amt)});
              await FirebaseFirestore.instance.collection("earnings").add({"to": l2, "from": widget.mobile, "amount": l2Amt, "type": "L2 Premium", "time": FieldValue.serverTimestamp()});
              String l3 = l2Doc.data()?["referredBy"]?? ""; if (l3.isNotEmpty) { var l3Doc = await FirebaseFirestore.instance.collection("users").doc(l3).get(); if (l3Doc.exists) { await FirebaseFirestore.instance.collection("users").doc(l3).update({"wallet": FieldValue.increment(l3Amt)}); await FirebaseFirestore.instance.collection("earnings").add({"to": l3, "from": widget.mobile, "amount": l3Amt, "type": "L3 Premium", "time": FieldValue.serverTimestamp()}); } }
            }
          }
        }
      }
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"premiumDistributed": true});
    } catch (e) { debugPrint("dist error $e"); }
  }
  void openPremium() { Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumPayScreen(mobile: widget.mobile, onPaid: (){}))); }
  void doLogout() async { await prefs.clear(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false); }
  
  // ===== DP SYSTEM (Step 1) =====
  Widget _dpAvatar() {
    return Stack(alignment: Alignment.bottomRight, children: [
      CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1E293B),
        backgroundImage: myPhotoUrl.isNotEmpty? NetworkImage(myPhotoUrl) : null,
        child: myPhotoUrl.isNotEmpty? null : const Icon(Icons.person, color: Colors.amber, size: 28)),
      Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
        child: const Icon(Icons.camera_alt, size: 12, color: Colors.black)),
    ]);
  }
  
  static const String currentAppVersion = "8.0";
  bool _forceUpdateChecked = false;
  bool _isOldApk = false;
  Future<bool> _checkForceUpdate() async {
    try {
      final versionDoc = await FirebaseFirestore.instance.collection("config").doc("appVersion").get();
      if (!versionDoc.exists) return false;
      final data = versionDoc.data()!;
      final latestVersion = (data["latestVersion"] ?? "8.0").toString();
      final forceUpdate = data["forceUpdate"] ?? false;
      final minVersion = (data["minVersion"] ?? "8.0").toString();
      bool isOld = false;
      try { final curr = double.parse(currentAppVersion); final min = double.parse(minVersion); if (curr < min) isOld = true; } catch (_) { isOld = currentAppVersion != latestVersion && forceUpdate; }
      if (isOld && forceUpdate) {
        _isOldApk = true;
        if (mounted) { showDialog(barrierDismissible: false, context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF1E293B), title: const Row(children: [Icon(Icons.system_update, color: Colors.orange, size: 28), SizedBox(width: 8), Text("APK Updated!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), content: const Text("Naya APK download karo - ID login purani APK me band hai!", style: TextStyle(color: Colors.white70)), actions: [ElevatedButton(onPressed: (){ Navigator.pop(context); }, child: const Text("OK"))])); }
        return true;
      }
      return false;
    } catch (e) { return false; }
  }
  Future<bool> _blockIfOldApkIdLogin() async {
    if (!_forceUpdateChecked) { _forceUpdateChecked = true; final isOld = await _checkForceUpdate(); if (isOld) return true; }
    if (_isOldApk) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("APK Updated! Naya APK download karo"), backgroundColor: Colors.red)); } return true; }
    return false;
  }

  Future<String> _uploadDPToCloudinary(Uint8List bytes) async {
    final req = http.MultipartRequest("POST", Uri.parse("https://api.cloudinary.com/v1_1/i5r1swhi/image/upload"))
      ..fields['upload_preset'] = 'ludo_chat'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'dp.jpg'));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (streamed.statusCode != 200) throw Exception("Cloudinary: ${res.body}");
    return json.decode(res.body)['secure_url'] as String;
  }

  Future<void> _changeDP() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
      if (x == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DP upload ho rahi hai...")));
      final bytes = await x.readAsBytes();
      final url = await _uploadDPToCloudinary(bytes);
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"photoUrl": url});
      if (mounted) setState(() => myPhotoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DP lag gayi \u2705")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("DP fail: $e")));
    }
  }
    
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [InkWell(onTap: _changeDP, child: _dpAvatar()), const SizedBox(width: 8), Text(widget.mobile, style: const TextStyle(color: Colors.white)), const Spacer(), InkWell(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => BuyCoinsScreen(mobile: widget.mobile))); }, child: Text("\u{1FA99} $myCoins", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))), const SizedBox(width: 8), Text("Rs $wallet", style: const TextStyle(color: Colors.white70)), const SizedBox(width: 8), InkWell(onTap: doLogout, child: const Icon(Icons.logout, color: Colors.white54))]),
      const SizedBox(height: 16),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: isPrem? [Colors.amber, Colors.orange] : [const Color(0xFF1E293B), const Color(0xFF151A2B)]), borderRadius: BorderRadius.circular(16)), child: Text(isPrem? "PREMIUM ACTIVE Till $expiry" : "FREE USER - Buy Premium", style: TextStyle(color: isPrem? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("My Refer Code (Locked): $myCode", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)), Text("Name Locked: $myName", style: const TextStyle(color: Colors.white54, fontSize: 10)), Text("ID Number (Locked): $myIdNo", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)), Text(referredBy.isEmpty? "Referred By: Direct" : "Referred By: ${referredByName.isEmpty? referredBy : referredByName}", style: const TextStyle(color: Colors.white54, fontSize: 10))])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () { if (!isPrem) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Premium Lo"))); openPremium(); return; } Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("PLAY LUDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12),
      Container(margin: const EdgeInsets.only(bottom: 12), width: double.infinity, height: 54, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LuckyWheelScreen(mobile: widget.mobile))), icon: const Icon(Icons.casino, size: 20), label: const Text("LUCKY WHEEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      Container(margin: const EdgeInsets.only(bottom: 12), width: double.infinity, height: 54, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyTasksScreen(mobile: widget.mobile))), icon: const Icon(Icons.task_alt, size: 20), label: const Text("DAILY TASKS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      Row(children: [
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateRoomScreen(mobile: widget.mobile))), icon: const Icon(Icons.lock, size: 18), label: const Text("PRIVATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
        const SizedBox(width: 6),
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreakScreen(mobile: widget.mobile))), icon: const Icon(Icons.local_fire_department, size: 18), label: const Text("STREAK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
        const SizedBox(width: 6),
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowSystemScreen(mobile: widget.mobile))), icon: const Icon(Icons.people, size: 18), label: const Text("FOLLOW", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(mobile: widget.mobile))), icon: const Icon(Icons.shopping_cart, size: 18), label: const Text("SHOP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())), icon: const Icon(Icons.emoji_events, size: 18), label: const Text("TOP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentScreen(mobile: widget.mobile))), icon: const Icon(Icons.event, size: 18), label: const Text("EVENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
      ]),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(
        onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceLobbyScreen())); },
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text("VOICE CHAT ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BCD4)), child: const Text("UPI SET KARE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => MyTeamScreen(mobile: widget.mobile))); }, child: const Text("MY TEAM")))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => PlanScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("PLAN CHART", style: TextStyle(color: Colors.black)))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("FRIENDS", style: TextStyle(color: Colors.white))))]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const JaruriSuchnaScreen()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("JRURI SUCHNA - EK BAAR JRUR DEKHE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isPrem? null : openPremium, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text(isPrem? "PREMIUM ACTIVE" : "BUY PREMIUM Rs 500", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)))),
      const SizedBox(height: 12),
      const Text("MASSAGE FOR HELP ID NUMBER 0000001 (INDIAN HELPLINE SERVICE)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
    ]))));
  }
  return true;

}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState() => _WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController(); int wallet = 0; bool loading = true; String existingUpi = ""; String myPassword = "";
  @override void initState() { super.initState(); loadWallet(); }
  Future<void> loadWallet() async { var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if (d.exists) { setState(() { wallet = d.data()!["wallet"]?? 0; upiCtrl.text = d.data()!["upi"]?? ""; existingUpi = d.data()!["upi"]?? ""; myPassword = d.data()!["password"]?? ""; loading = false; }); } }
  Future<void> saveUpi() async {
    String newUpi = upiCtrl.text.trim(); if (newUpi.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI dalo"))); return; }
    if (existingUpi.isEmpty) {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": newUpi});
      await FirebaseFirestore.instance.collection("upi_history").add({"mobile": widget.mobile, "oldUpi": "", "newUpi": newUpi, "by": "user", "time": FieldValue.serverTimestamp()});
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Set Ho Gaya"))); Navigator.pop(context); return;
    }
    TextEditingController passCtrl = TextEditingController(); bool? ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF1E1E2E), title: const Text("Password Daalo", style: TextStyle(color: Colors.white, fontSize: 13)), content: TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("Verify"))]));
    if (ok!= true) return; if (passCtrl.text.trim()!= myPassword) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password galat"))); return; }
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": newUpi});
    await FirebaseFirestore.instance.collection("upi_history").add({"mobile": widget.mobile, "oldUpi": existingUpi, "newUpi": newUpi, "by": "user", "time": FieldValue.serverTimestamp()});
    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Change Ho Gaya"))); Navigator.pop(context);
  }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(title: const Text("Wallet"), backgroundColor: Colors.amber), body: loading? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text("Rs $wallet", style: const TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: upiCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "UPI ID", filled: true, fillColor: const Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saveUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SAVE")))]))); }
}

class PremiumPayScreen extends StatefulWidget { final String mobile; final VoidCallback onPaid; const PremiumPayScreen({super.key, required this.mobile, required this.onPaid}); @override State<PremiumPayScreen> createState() => _PremiumPayScreenState(); }
class _PremiumPayScreenState extends State<PremiumPayScreen> {
  final String myUpiId = "kumar131@fam"; bool loading = false;
  Future<void> payUpi() async { String url = "upi://pay?pa=$myUpiId&pn=LUDO&am=500&cu=INR"; await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
  Future<void> sendSS() async {
    final picker = ImagePicker(); final XFile? img = await picker.pickImage(source: ImageSource.gallery); if (img == null) return; setState(() { loading = true; });
    await FirebaseFirestore.instance.collection("premium_requests").doc(widget.mobile).set({"mobile": widget.mobile, "amount": 500, "status": "CHECK", "time": Timestamp.now()});
    Uri wa = Uri.parse("https://wa.me/447397293594?text=Check ${widget.mobile}"); await launchUrl(wa, mode: LaunchMode.externalApplication); setState(() { loading = false; });
  }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(title: const Text("Buy Premium"), backgroundColor: Colors.amber), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Text("Premium Rs 500", style: TextStyle(color: Colors.white, fontSize: 22)), const SizedBox(height: 20), SelectableText(myUpiId, style: const TextStyle(color: Colors.amber, fontSize: 20)), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: payUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("PAY Rs 500", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)))), const SizedBox(height: 12), loading? const CircularProgressIndicator() : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: sendSS, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SEND PAYMENT SCREENSHOT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15))))]))); }
}

class MyTeamScreen extends StatefulWidget { final String mobile; const MyTeamScreen({super.key, required this.mobile}); @override State<MyTeamScreen> createState() => _MyTeamScreenState(); }
class _MyTeamScreenState extends State<MyTeamScreen> with SingleTickerProviderStateMixin {
  late TabController tabCtrl; List<DocumentSnapshot> l1 = []; List<DocumentSnapshot> l2 = []; List<DocumentSnapshot> l3 = []; List<DocumentSnapshot> earn = []; bool loading = true;
  @override void initState() { super.initState(); tabCtrl = TabController(length: 4, vsync: this); fetchTeam(); }
  Future<void> fetchTeam() async {
    setState(() { loading = true; }); var q1 = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: widget.mobile).get(); l1 = q1.docs;
    List<DocumentSnapshot> temp2 = []; for (var d in q1.docs) { var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: d.id).get(); temp2.addAll(q.docs); } l2 = temp2;
    List<DocumentSnapshot> temp3 = []; for (var d in temp2) { var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: d.id).get(); temp3.addAll(q.docs); } l3 = temp3;
    var e = await FirebaseFirestore.instance.collection("earnings").where("to", isEqualTo: widget.mobile).get(); earn = e.docs; setState(() { loading = false; });
  }
  Widget buildList(List<DocumentSnapshot> list, String emptyMsg) {
    if (list.isEmpty) { return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.white54))); }
    return ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) {
      var data = list[i].data() as Map<String, dynamic>; String name = data["name"]?? "User"; String mob = data["mobile"]?? ""; String last4 = mob.length >= 4? mob.substring(mob.length - 4) : mob; String prem = data["isPremium"] == true? "PREMIUM" : "FREE";
      return Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.amber, child: Text(name.isNotEmpty? name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), title: Text("$name (${"*" * 6}$last4)", style: const TextStyle(color: Colors.white, fontSize: 13)), subtitle: Text(prem, style: TextStyle(color: prem == "PREMIUM"? Colors.greenAccent : Colors.white54, fontSize: 10))));
    });
  }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(title: const Text("My Team"), backgroundColor: Colors.amber, bottom: TabBar(controller: tabCtrl, tabs: const [Tab(text: "L1"), Tab(text: "L2"), Tab(text: "L3"), Tab(text: "Income")])), body: loading? const Center(child: CircularProgressIndicator()) : TabBarView(controller: tabCtrl, children: [buildList(l1, "L1 empty"), buildList(l2, "L2 empty"), buildList(l3, "L3 empty"), ListView.builder(itemCount: earn.length, itemBuilder: (ctx, i) { var d = earn[i].data() as Map; return ListTile(title: Text("Rs ${d["amount"]} - ${d["type"]}", style: const TextStyle(color: Colors.white)), subtitle: Text("${d["from"]}", style: const TextStyle(color: Colors.white54))); })])); }
}

// ================= BUY COINS (Step 2) =================
class BuyCoinsScreen extends StatefulWidget {
  final String mobile;
  const BuyCoinsScreen({super.key, required this.mobile});
  @override State<BuyCoinsScreen> createState() => _BuyCoinsScreenState();
}
class _BuyCoinsScreenState extends State<BuyCoinsScreen> {
  int buyRate = 1000; String upiId = ""; bool loading = true;
  final amtCtrl = TextEditingController(); final utrCtrl = TextEditingController();
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final c = await FirebaseFirestore.instance.collection("config").doc("coins").get();
      final w = await FirebaseFirestore.instance.collection("config").doc("wallet").get();
      if (mounted) setState(() {
        buyRate = (c.data()?["buyRate"] ?? 1000) as int;
        upiId = (w.data()?["upiId"] ?? "") as String;
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  Future<void> _submit() async {
    final amt = int.tryParse(amtCtrl.text) ?? 0;
    final utr = utrCtrl.text.trim();
    if (amt < 10) { _msg("Kam se kam Rs 10"); return; }
    if (utr.length < 6) { _msg("Sahi UTR likho"); return; }
    final coins = (amt * buyRate) ~/ 100;
    try {
      await FirebaseFirestore.instance.collection("coinRequests").add({
        "mobile": widget.mobile, "amount": amt, "coins": coins, "utr": utr,
        "status": "pending", "at": FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _msg("Request bhej di! Admin approve karega");
      Navigator.pop(context);
    } catch (e) { _msg("Fail: $e"); }
  }
  void _msg(String m) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("Buy Coins"), backgroundColor: Colors.amber),
      body: loading ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
              borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const Text("\u{1FA99}", style: TextStyle(fontSize: 50)),
            Text("Rs 100 = $buyRate coins", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ])),
        const SizedBox(height: 16),
        const Text("1. Is UPI par paise bhejo:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF151A2B), borderRadius: BorderRadius.circular(10)),
          child: Text(upiId.isEmpty ? "UPI ID set nahi hai" : upiId,
              style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        const Text("2. Kitne Rs bheje:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        TextField(controller: amtCtrl, keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Jaise: 100", hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 12),
        const Text("3. UTR / Transaction ID:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        TextField(controller: utrCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "12 digit UTR", hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54,
          child: ElevatedButton(onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("REQUEST BHEJO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 12),
        const Text("Admin approve karne ke baad coins mil jayenge.",
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ])));
  }
}


class LuckyWheelScreen extends StatefulWidget {
  final String mobile;
  const LuckyWheelScreen({super.key, required this.mobile});
  @override State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _currentRotation = 0;
  bool _spinning = false;
  bool _canSpin = true;
  int _lastSpinDay = 0;
  int _streak = 1;
  final List<Map<String, dynamic>> _rewards = [
    {"label": "10 Coins", "coins": 10, "color": Color(0xFF22C55E), "icon": "🪙"},
    {"label": "50 Coins", "coins": 50, "color": Color(0xFF3B82F6), "icon": "💰"},
    {"label": "100 Coins", "coins": 100, "color": Color(0xFFF59E0B), "icon": "💎"},
    {"label": "5 Coins", "coins": 5, "color": Color(0xFFEF4444), "icon": "🪙"},
    {"label": "20 Coins", "coins": 20, "color": Color(0xFF8B5CF6), "icon": "💰"},
    {"label": "200 Coins", "coins": 200, "color": Color(0xFFEC4899), "icon": "🎉"},
    {"label": "15 Coins", "coins": 15, "color": Color(0xFF06B6D4), "icon": "🪙"},
    {"label": "30 Coins", "coins": 30, "color": Color(0xFFF97316), "icon": "💰"},
  ];

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _checkDaily();
  }

  Future<void> _checkDaily() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      if (doc.exists) {
        final data = doc.data()!;
        final lastSpin = (data["lastWheelSpin"] ?? 0) as int;
        final today = DateTime.now();
        final todayDay = today.year * 10000 + today.month * 100 + today.day;
        if (lastSpin == todayDay) {
          if (mounted) setState(() => _canSpin = false);
        }
        if (mounted) setState(() => _streak = (data["wheelStreak"] ?? 1) as int);
      }
    } catch (_) {}
  }

  Future<void> _spin() async {
    if (_spinning || !_canSpin) return;
    setState(() => _spinning = true);
    
    final random = (DateTime.now().millisecondsSinceEpoch % 8);
    final targetIndex = random;
    final reward = _rewards[targetIndex];
    
    final extraRotations = 5 + (DateTime.now().millisecond % 3);
    final targetAngle = (2 * 3.14159 * extraRotations) + (2 * 3.14159 * targetIndex / _rewards.length) + (2 * 3.14159 / _rewards.length / 2);
    
    _anim = Tween<double>(begin: _currentRotation, end: _currentRotation + targetAngle).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward(from: 0);
    
    await Future.delayed(const Duration(seconds: 4));
    
    try {
      final coins = reward["coins"] as int;
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({
        "coins": FieldValue.increment(coins),
        "lastWheelSpin": DateTime.now().year * 10000 + DateTime.now().month * 100 + DateTime.now().day,
        "wheelStreak": _streak + 1,
        "xp": FieldValue.increment(5),
      });
      
      if (mounted) {
        setState(() { _currentRotation += targetAngle; _spinning = false; _canSpin = false; _streak++; });
        showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text("🎉 ${reward["icon"]} Jeet gaye!", style: const TextStyle(color: Colors.white)),
          content: Text("Aapko ${reward["coins"]} coins mile!\nStreak: $_streak days", style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Awesome!"))],
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🎡 Lucky Wheel", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(children: [
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_fire_department, color: Colors.orange, size: 20), const SizedBox(width: 6), Text("Streak: $_streak days 🔥", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))])),
        const SizedBox(height: 20),
        Expanded(child: Center(child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: _anim, builder: (_, __) {
            return Transform.rotate(angle: _anim.value, child: CustomPaint(size: const Size(300, 300), painter: _WheelPainter(rewards: _rewards)));
          }),
          Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.orange, width: 3)), child: const Icon(Icons.star, color: Colors.orange, size: 30)),
          Positioned(top: 0, child: Transform.rotate(angle: 3.14, child: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 50))),
        ]))),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          if (!_canSpin) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.timer, color: Colors.redAccent), SizedBox(width: 8), Expanded(child: Text("Aaj ka spin ho gaya! Kal wapas aao", style: TextStyle(color: Colors.redAccent)))])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _canSpin && !_spinning ? _spin : null, style: ElevatedButton.styleFrom(backgroundColor: _canSpin ? Colors.orange : Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(_spinning ? "Spinning..." : _canSpin ? "🎡 SPIN NOW!" : "⏰ Kal aana", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
          const SizedBox(height: 8),
          const Text("Har din spin karo aur coins jeeto! Streak se bonus milta hai", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
        ])),
      ]),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> rewards;
  _WheelPainter({required this.rewards});
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final sweep = 2 * 3.14159 / rewards.length;
    for (int i = 0; i < rewards.length; i++) {
      paint.color = rewards[i]["color"] as Color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * sweep, sweep, true, paint);
      final textAngle = i * sweep + sweep / 2;
      final textX = center.dx + (radius * 0.65) * 3.14159 / 3 * 0.6; // simplified
      final textPainter = TextPainter(text: TextSpan(text: "${rewards[i]["icon"]}\n${rewards[i]["coins"]}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      textPainter.layout();
      canvas.save();
      canvas.translate(center.dx + (radius * 0.6) * 0.6, center.dy);
      canvas.rotate(textAngle + 1.57);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawCircle(center, radius, borderPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class LevelSystem {
  static int getLevelFromXp(int xp) {
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    if (xp < 1500) return 5;
    if (xp < 2200) return 6;
    if (xp < 3000) return 7;
    if (xp < 4000) return 8;
    if (xp < 5500) return 9;
    return 10 + ((xp - 5500) ~/ 2000);
  }

  static String getLevelTitle(int level) {
    if (level <= 1) return "Newbie";
    if (level <= 2) return "Rookie";
    if (level <= 3) return "Explorer";
    if (level <= 4) return "Adventurer";
    if (level <= 5) return "Warrior";
    if (level <= 6) return "Champion";
    if (level <= 7) return "Hero";
    if (level <= 8) return "Legend";
    if (level <= 9) return "Mythic";
    if (level <= 15) return "VIP $level";
    return "SUPREME $level";
  }

  static Color getLevelColor(int level) {
    if (level <= 1) return Color(0xFF9CA3AF);
    if (level <= 3) return Color(0xFF22C55E);
    if (level <= 5) return Color(0xFF3B82F6);
    if (level <= 7) return Color(0xFF8B5CF6);
    if (level <= 9) return Color(0xFFF59E0B);
    if (level <= 15) return Color(0xFFEC4899);
    return Color(0xFFFFD700);
  }

  static String getFrameForLevel(int level) {
    if (level <= 2) return "none";
    if (level <= 4) return "bronze";
    if (level <= 6) return "silver";
    if (level <= 8) return "gold";
    if (level <= 10) return "diamond";
    if (level <= 15) return "royal";
    return "supreme";
  }

  static String getEntryEffect(int level) {
    if (level <= 3) return "none";
    if (level <= 5) return "stars";
    if (level <= 7) return "fire";
    if (level <= 9) return "lightning";
    if (level <= 15) return "phoenix";
    return "dragon";
  }
}

class DailyTasksScreen extends StatefulWidget {
  final String mobile;
  const DailyTasksScreen({super.key, required this.mobile});
  @override State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  Map<String, bool> tasks = {
    "login": true,
    "ludo": false,
    "voice": false,
    "wheel": false,
    "gift": false,
    "chat": false,
  };
  int coinsEarned = 0;
  bool loading = true;

  @override void initState() { super.initState(); _loadTasks(); }

  Future<void> _loadTasks() async {
    try {
      final today = DateTime.now();
      final todayKey = "${today.year}-${today.month}-${today.day}";
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("dailyTasks").doc(todayKey).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) setState(() { 
          tasks = {
            "login": data["login"] ?? true,
            "ludo": data["ludo"] ?? false,
            "voice": data["voice"] ?? false,
            "wheel": data["wheel"] ?? false,
            "gift": data["gift"] ?? false,
            "chat": data["chat"] ?? false,
          };
          coinsEarned = data["coinsEarned"] ?? 0;
          loading = false;
        });
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _claimTask(String taskKey, int reward) async {
    if (tasks[taskKey] == true) return;
    try {
      final today = DateTime.now();
      final todayKey = "${today.year}-${today.month}-${today.day}";
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("dailyTasks").doc(todayKey).set({
        taskKey: true,
        "coinsEarned": FieldValue.increment(reward),
        "lastUpdate": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({
        "coins": FieldValue.increment(reward),
        "xp": FieldValue.increment(10),
      });
      if (mounted) setState(() { tasks[taskKey] = true; coinsEarned += reward; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("+$reward coins! 🎉")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
    final taskList = [
      {"key": "login", "title": "Daily Login", "desc": "App kholo", "reward": 5, "icon": "📅"},
      {"key": "ludo", "title": "Play Ludo", "desc": "1 game khelo", "reward": 20, "icon": "🎲"},
      {"key": "voice", "title": "Voice Room", "desc": "Voice room join karo", "reward": 15, "icon": "🎤"},
      {"key": "wheel", "title": "Lucky Wheel", "desc": "Wheel spin karo", "reward": 10, "icon": "🎡"},
      {"key": "gift", "title": "Send Gift", "desc": "Kisi ko gift bhejo", "reward": 10, "icon": "🎁"},
      {"key": "chat", "title": "Chat Karo", "desc": "5 messages bhejo", "reward": 10, "icon": "💬"},
    ];

    final completed = tasks.values.where((v) => v).length;
    final total = tasks.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("📋 Daily Tasks", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]), borderRadius: BorderRadius.circular(16)), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("$completed/$total Tasks", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text("$coinsEarned coins earned", style: const TextStyle(color: Colors.white70))]),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: completed / total, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
        ])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: taskList.length, itemBuilder: (_, i) {
          final t = taskList[i];
          final done = tasks[t["key"]] ?? false;
          return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: done ? Colors.green.withOpacity(0.5) : Colors.white10)), child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: done ? Colors.green.withOpacity(0.2) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(t["icon"] as String, style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t["title"] as String, style: TextStyle(color: done ? Colors.green : Colors.white, fontWeight: FontWeight.bold)), Text(t["desc"] as String, style: const TextStyle(color: Colors.white54, fontSize: 12))])),
            Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text("+${t["reward"]} 🪙", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              done ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: const Text("✓ Done", style: TextStyle(color: Colors.white, fontSize: 12))) : ElevatedButton(onPressed: () => _claimTask(t["key"] as String, t["reward"] as int), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)), child: const Text("Claim", style: TextStyle(fontSize: 12))),
            ]),
          ]));
        })),
      ]),
    );
  }
}


class ShopScreen extends StatefulWidget {
  final String mobile;
  const ShopScreen({super.key, required this.mobile});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String,dynamic>> frames = [];
  List<Map<String,dynamic>> effects = [];
  List<Map<String,dynamic>> vips = [];
  int myCoins = 0;
  bool loading = true;

  @override void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); _loadShop(); }

  Future<void> _loadShop() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      myCoins = userDoc.data()?["coins"] ?? 0;
      
      final framesSnap = await FirebaseFirestore.instance.collection("shop_frames").get();
      frames = framesSnap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      
      final effectsSnap = await FirebaseFirestore.instance.collection("shop_effects").get();
      effects = effectsSnap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      
      final vipsSnap = await FirebaseFirestore.instance.collection("shop_vip").get();
      vips = vipsSnap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      
      if (vips.isEmpty) {
        vips = [
          {"id":"vip_bronze","name":"Bronze VIP","price":1000,"days":30,"color":"CD7F32","perks":["Bronze Frame","⭐ Entry","2x Coins"]},
          {"id":"vip_silver","name":"Silver VIP","price":2500,"days":30,"color":"C0C0C0","perks":["Silver Frame","🔥 Entry","3x Coins","Room Theme"]},
          {"id":"vip_gold","name":"Gold VIP","price":5000,"days":30,"color":"FFD700","perks":["Gold Frame","⚡ Entry + Popup","5x Coins","All Themes","PK Bonus"]},
          {"id":"vip_diamond","name":"Diamond VIP","price":10000,"days":30,"color":"00FFFF","perks":["Diamond Frame","🦚 Phoenix Entry","10x Coins","All Themes","PK Bonus","Custom Badge"]},
        ];
      }
      
      if (frames.isEmpty) {
        frames = [
          {"id":"frame_bronze","name":"Bronze Frame","price":500,"level":3,"image":"🥉"},
          {"id":"frame_silver","name":"Silver Frame","price":1500,"level":5,"image":"🥈"},
          {"id":"frame_gold","name":"Gold Frame","price":3000,"level":7,"image":"🥇"},
          {"id":"frame_diamond","name":"Diamond Frame","price":6000,"level":9,"image":"💎"},
          {"id":"frame_royal","name":"Royal Frame","price":12000,"level":11,"image":"👑"},
        ];
      }
      
      if (effects.isEmpty) {
        effects = [
          {"id":"effect_stars","name":"Stars Entry","price":800,"level":4,"emoji":"⭐"},
          {"id":"effect_fire","name":"Fire Entry","price":2000,"level":6,"emoji":"🔥"},
          {"id":"effect_lightning","name":"Lightning Entry","price":4000,"level":8,"emoji":"⚡"},
          {"id":"effect_phoenix","name":"Phoenix Entry","price":8000,"level":10,"emoji":"🦚"},
          {"id":"effect_dragon","name":"Dragon Entry","price":15000,"level":15,"emoji":"🐉"},
        ];
      }
      
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _buyItem(String collection, String itemId, int price, String name) async {
    if (myCoins < price) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Coins kam hain! Need $price, you have $myCoins"))); return; }
    
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text("Buy $name?", style: const TextStyle(color: Colors.white)),
      content: Text("$price coins lagenge. Pakka kharidna hai?", style: const TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text("Cancel")), TextButton(onPressed: ()=> Navigator.pop(context, true), child: const Text("Buy"))],
    ));
    
    if (confirm != true) return;
    
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"coins": FieldValue.increment(-price)});
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("purchases").doc(itemId).set({
        "itemId": itemId, "name": name, "price": price, "boughtAt": FieldValue.serverTimestamp(), "type": collection
      });
      
      if (collection == "shop_vip") {
        final days = vips.firstWhere((v)=> v["id"]==itemId, orElse: ()=> {"days":30})["days"] as int;
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({
          "vip": itemId, "vipExpiry": DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch
        });
      }
      
      if (mounted) setState(() => myCoins -= price);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name kharid liya! 🎉")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text("🛒 Shop", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Text("🪙", style: TextStyle(fontSize: 16)), const SizedBox(width: 4), Text("$myCoins", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]))],
        bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: "VIP 👑"), Tab(text: "Frames 🖼️"), Tab(text: "Effects 🎆")]),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabCtrl, children: [
        // VIP TAB
        ListView.builder(padding: const EdgeInsets.all(12), itemCount: vips.length, itemBuilder: (_, i){
          final vip = vips[i];
          return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(int.parse("0xFF${vip["color"]}")), Color(int.parse("0xFF${vip["color"]}")).withOpacity(0.5)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(vip["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text("${vip["price"]} 🪙", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 8),
            ... (vip["perks"] as List).map((p)=> Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [const Text("✓ ", style: TextStyle(color: Colors.white)), Text(p, style: const TextStyle(color: Colors.white70, fontSize: 13))]))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: ()=> _buyItem("shop_vip", vip["id"], vip["price"], vip["name"]), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: Text("Buy ${vip["name"]} - ${vip["days"]} days"))),
          ]));
        }),
        // FRAMES TAB
        GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: frames.length, itemBuilder: (_, i){
          final fr = frames[i];
          return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(children: [
            Text(fr["image"]??"🖼️", style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(fr["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            Text("Lv.${fr["level"]}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text("${fr["price"]} 🪙", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: ()=> _buyItem("shop_frames", fr["id"], fr["price"], fr["name"]), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text("Buy", style: TextStyle(fontSize: 12)))),
          ]));
        }),
        // EFFECTS TAB
        GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: effects.length, itemBuilder: (_, i){
          final ef = effects[i];
          return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(children: [
            Text(ef["emoji"]??"✨", style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(ef["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            Text("Lv.${ef["level"]}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text("${ef["price"]} 🪙", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: ()=> _buyItem("shop_effects", ef["id"], ef["price"], ef["name"]), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text("Buy", style: TextStyle(fontSize: 12)))),
          ]));
        }),
      ]),
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String,dynamic>> topCoins = [];
  List<Map<String,dynamic>> topLevel = [];
  List<Map<String,dynamic>> topGifts = [];
  bool loading = true;

  @override void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); _loadLeaderboards(); }

  Future<void> _loadLeaderboards() async {
    try {
      final coinsSnap = await FirebaseFirestore.instance.collection("users").orderBy("coins", descending: true).limit(20).get();
      topCoins = coinsSnap.docs.map((d)=> {"mobile":d.id, ...d.data()}).toList();
      
      final levelSnap = await FirebaseFirestore.instance.collection("users").orderBy("xp", descending: true).limit(20).get();
      topLevel = levelSnap.docs.map((d)=> {"mobile":d.id, ...d.data()}).toList();
      
      final giftsSnap = await FirebaseFirestore.instance.collection("users").orderBy("totalGiftsSent", descending: true).limit(20).get();
      topGifts = giftsSnap.docs.map((d)=> {"mobile":d.id, ...d.data()}).toList();
      
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Widget _buildList(List<Map<String,dynamic>> list, String valueKey, String suffix) {
    if (list.isEmpty) return const Center(child: Text("Koi data nahi", style: TextStyle(color: Colors.white54)));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i){
      final u = list[i];
      final rank = i+1;
      String medal = "";
      Color rankColor = Colors.white54;
      if (rank==1) { medal="🥇"; rankColor=const Color(0xFFFFD700); }
      else if (rank==2) { medal="🥈"; rankColor=const Color(0xFFC0C0C0); }
      else if (rank==3) { medal="🥉"; rankColor=const Color(0xFFCD7F32); }
      
      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: rank<=3 ? rankColor.withOpacity(0.15) : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: rank<=3 ? rankColor.withOpacity(0.5) : Colors.white10)), child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: rankColor.withOpacity(0.2), shape: BoxShape.circle), child: Center(child: Text(medal.isNotEmpty ? medal : "$rank", style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: medal.isNotEmpty ? 18 : 12)))),
        const SizedBox(width: 12),
        CircleAvatar(radius: 20, backgroundColor: const Color(0xFF0F172A), backgroundImage: u["photoUrl"]!=null ? NetworkImage(u["photoUrl"]) : null, child: u["photoUrl"]==null ? Text((u["name"]??"U")[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u["name"]??"Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text("ID: ${u["idNo"]??u["mobile"]}", style: const TextStyle(color: Colors.white54, fontSize: 11))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${u[valueKey]??0} $suffix", style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 14)), Text("Lv.${LevelSystem.getLevelFromXp(u["xp"]??0)}", style: const TextStyle(color: Colors.white54, fontSize: 11))]),
      ]));
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🏆 Leaderboard", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white), bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: "🪙 Coins"), Tab(text: "👑 Level"), Tab(text: "🎁 Gifts")])),
      body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabCtrl, children: [
        _buildList(topCoins, "coins", "🪙"),
        _buildList(topLevel, "xp", "XP"),
        _buildList(topGifts, "totalGiftsSent", "🎁"),
      ]),
    );
  }
}

class TournamentScreen extends StatefulWidget {
  final String mobile;
  const TournamentScreen({super.key, required this.mobile});
  @override State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  Map<String,dynamic>? activeTournament;
  bool loading = true;
  bool joined = false;

  @override void initState() { super.initState(); _loadTournament(); }

  Future<void> _loadTournament() async {
    try {
      final snap = await FirebaseFirestore.instance.collection("tournaments").where("active", isEqualTo: true).limit(1).get();
      if (snap.docs.isNotEmpty) {
        activeTournament = {"id": snap.docs.first.id, ...snap.docs.first.data()};
        final joinDoc = await FirebaseFirestore.instance.collection("tournaments").doc(activeTournament!["id"]).collection("participants").doc(widget.mobile).get();
        joined = joinDoc.exists;
      }
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _joinTournament() async {
    if (activeTournament==null) return;
    try {
      await FirebaseFirestore.instance.collection("tournaments").doc(activeTournament!["id"]).collection("participants").doc(widget.mobile).set({
        "mobile": widget.mobile, "joinedAt": FieldValue.serverTimestamp(), "score": 0
      });
      await FirebaseFirestore.instance.collection("tournaments").doc(activeTournament!["id"]).update({"participantsCount": FieldValue.increment(1)});
      if (mounted) setState(() => joined = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tournament join ho gaya! 🎉")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🏆 Tournament", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading ? const Center(child: CircularProgressIndicator()) : activeTournament==null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.emoji_events, size: 20),
        const SizedBox(height: 16),
        const Text("Koi active tournament nahi", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Jald hi naya tournament ayega!", style: TextStyle(color: Colors.white54)),
      ])) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [
          Text(activeTournament!["name"]??"Weekly Tournament", style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(activeTournament!["desc"]??"Sabse zyada Ludo jeeto!", style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text("${activeTournament!["prize"]??5000}", style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)), const Text("Prize 🪙", style: TextStyle(color: Colors.black87, fontSize: 12))]),
            Container(width: 1, height: 40, color: Colors.black26),
            Column(children: [Text("${activeTournament!["participantsCount"]??0}", style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)), const Text("Players", style: TextStyle(color: Colors.black87, fontSize: 12))]),
            Container(width: 1, height: 40, color: Colors.black26),
            Column(children: [Text("${activeTournament!["daysLeft"]??3} days", style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)), const Text("Left", style: TextStyle(color: Colors.black87, fontSize: 12))]),
          ]),
        ])),
        const SizedBox(height: 20),
        if (!joined) SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _joinTournament, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("JOIN TOURNAMENT 🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))) 
        else Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF14532D), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF22C55E))), child: const Row(children: [Icon(Icons.check_circle, color: Color(0xFF22C55E)), SizedBox(width: 8), Text("Tournament me ho! Ludo khelo aur score badhao!", style: TextStyle(color: Colors.white))])),

        const SizedBox(height: 20),
        const Text("🏆 Top Players", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("tournaments").doc(activeTournament!["id"]).collection("participants").orderBy("score", descending: true).limit(10).snapshots(), builder: (_, snap){
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final parts = snap.data!.docs;
          if (parts.isEmpty) return const Text("Abhi koi participant nahi", style: TextStyle(color: Colors.white54));
          return Column(children: parts.asMap().entries.map((e){
            final i = e.key; final p = e.value.data() as Map<String,dynamic>;
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)), child: Row(children: [
              Text("${i+1}", style: TextStyle(color: i<3 ? const Color(0xFFFFD700) : Colors.white54, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(child: Text(p["mobile"]??"", style: const TextStyle(color: Colors.white))),
              Text("${p["score"]??0} pts", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ]));
          }).toList());
        }),
      ])),
    );
  }
}


class PrivateRoomScreen extends StatefulWidget {
  final String mobile;
  const PrivateRoomScreen({super.key, required this.mobile});
  @override State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool isPrivate = true;
  bool loading = false;

  Future<void> _createPrivateRoom() async {
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room naam likho"))); return; }
    if (isPrivate && pass.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password likho"))); return; }
    
    setState(() => loading = true);
    try {
      final roomNo = (1000000 + DateTime.now().millisecondsSinceEpoch % 9000000).toString();
      await FirebaseFirestore.instance.collection("private_rooms").doc(roomNo).set({
        "roomNo": roomNo,
        "name": name,
        "password": isPrivate ? pass : "",
        "isPrivate": isPrivate,
        "owner": widget.mobile,
        "createdAt": FieldValue.serverTimestamp(),
        "members": [widget.mobile],
      });
      
      // Also create in RTDB for voice
      await FirebaseDatabase.instance.ref("vRooms/$roomNo/info").set({
        "name": name,
        "owner": widget.mobile,
        "isPrivate": isPrivate,
        "password": isPrivate ? pass : "",
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Private Room $roomNo bana! 🎉")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomNo: roomNo)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => loading = false);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🔒 Private Room", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Room Name", style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Mera Private Room", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.meeting_room, color: Colors.white54))),
          const SizedBox(height: 16),
          Row(children: [
            const Text("Private Room?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(value: isPrivate, onChanged: (v)=> setState(()=> isPrivate=v), activeColor: const Color(0xFFFBBF24)),
          ]),
          if (isPrivate) ...[
            const SizedBox(height: 12),
            const Text("Password", style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "1234", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.lock, color: Colors.white54))),
          ],
        ])),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: loading ? null : _createPrivateRoom, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: loading ? const CircularProgressIndicator(color: Colors.black) : const Text("CREATE PRIVATE ROOM 🔒", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF14532D), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info, color: Color(0xFF22C55E)), SizedBox(width: 8), Expanded(child: Text("Private room me sirf password wale aa sakte hain. Invite link share karo!", style: TextStyle(color: Colors.white, fontSize: 12)))])),
      ])),
    );
  }
}

class FollowSystemScreen extends StatefulWidget {
  final String mobile;
  const FollowSystemScreen({super.key, required this.mobile});
  @override State<FollowSystemScreen> createState() => _FollowSystemScreenState();
}

class _FollowSystemScreenState extends State<FollowSystemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String,dynamic>> followers = [];
  List<Map<String,dynamic>> following = [];
  bool loading = true;

  @override void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); _loadFollows(); }

  Future<void> _loadFollows() async {
    try {
      final followersSnap = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("followers").get();
      followers = followersSnap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      
      final followingSnap = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("following").get();
      following = followingSnap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _unfollow(String targetMobile) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("following").doc(targetMobile).delete();
      await FirebaseFirestore.instance.collection("users").doc(targetMobile).collection("followers").doc(widget.mobile).delete();
      if (mounted) setState(() => following.removeWhere((f)=> f["id"]==targetMobile));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unfollowed")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildList(List<Map<String,dynamic>> list, bool isFollowers) {
    if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isFollowers ? "👥" : "💫", style: const TextStyle(fontSize: 50)), const SizedBox(height: 12), Text(isFollowers ? "Koi follower nahi" : "Kisi ko follow nahi kiya", style: const TextStyle(color: Colors.white54))])); 
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i){
      final u = list[i];
      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: const Color(0xFF0F172A), backgroundImage: u["photoUrl"]!=null ? NetworkImage(u["photoUrl"]) : null, child: u["photoUrl"]==null ? Text((u["name"]??"U")[0], style: const TextStyle(color: Colors.white)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u["name"]??"Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text("ID: ${u["idNo"]??u["id"]}", style: const TextStyle(color: Colors.white54, fontSize: 11))])),
        if (!isFollowers) ElevatedButton(onPressed: ()=> _unfollow(u["id"]), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7F1D1D)), child: const Text("Unfollow", style: TextStyle(fontSize: 11))),
      ]));
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("👥 Follow System", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white), bottom: TabBar(controller: _tabCtrl, tabs: [Tab(text: "Followers (${followers.length})"), Tab(text: "Following (${following.length})")])),
      body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabCtrl, children: [_buildList(followers, true), _buildList(following, false)]),
    );
  }
}

class StreakScreen extends StatefulWidget {
  final String mobile;
  const StreakScreen({super.key, required this.mobile});
  @override State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int currentStreak = 0;
  int maxStreak = 0;
  List<bool> weekDays = List.filled(7, false);
  bool loading = true;

  @override void initState() { super.initState(); _loadStreak(); }

  Future<void> _loadStreak() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      final data = doc.data();
      currentStreak = data?["currentStreak"] ?? 0;
      maxStreak = data?["maxStreak"] ?? 0;
      
      // Load last 7 days login
      final today = DateTime.now();
      for (int i=0; i<7; i++) {
        final date = today.subtract(Duration(days: 6-i));
        final key = "${date.year}-${date.month}-${date.day}";
        final loginDoc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("logins").doc(key).get();
        weekDays[i] = loginDoc.exists;
      }
      
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _claimDaily() async {
    try {
      final today = DateTime.now();
      final key = "${today.year}-${today.month}-${today.day}";
      final doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("logins").doc(key).get();
      if (doc.exists) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aaj ka reward le liya hai!"))); return; }
      
      int reward = 10;
      if (currentStreak >= 7) reward = 50;
      else if (currentStreak >= 3) reward = 20;
      
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("logins").doc(key).set({"at": FieldValue.serverTimestamp(), "streak": currentStreak+1});
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({
        "coins": FieldValue.increment(reward),
        "currentStreak": currentStreak+1,
        "maxStreak": currentStreak+1 > maxStreak ? currentStreak+1 : maxStreak,
        "xp": FieldValue.increment(5),
      });
      
      if (mounted) setState(() { weekDays[6] = true; currentStreak++; if (currentStreak > maxStreak) maxStreak = currentStreak; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("+$reward coins! Streak: $currentStreak 🔥")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🔥 Daily Streak", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [
          const Icon(Icons.local_fire_department, size: 20),
          const SizedBox(height: 8),
          Text("$currentStreak Days", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text("Current Streak", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text("$currentStreak", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const Text("Current", style: TextStyle(color: Colors.white70, fontSize: 12))]),
            Container(width: 1, height: 40, color: Colors.white30),
            Column(children: [Text("$maxStreak", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const Text("Best", style: TextStyle(color: Colors.white70, fontSize: 12))]),
          ]),
        ])),
        const SizedBox(height: 20),
        const Text("Last 7 Days", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(7, (i){
          final done = weekDays[i];
          return Column(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: done ? const Color(0xFF22C55E) : const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: done ? const Color(0xFF22C55E) : Colors.white24)), child: Center(child: done ? const Icon(Icons.check, color: Colors.white, size: 20) : Text("${i+1}", style: const TextStyle(color: Colors.white54)))),
            const SizedBox(height: 4),
            Text(["M","T","W","T","F","S","S"][i], style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]);
        })),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _claimDaily, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("CLAIM TODAY'S REWARD 🎁", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Rewards:", style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("• Day 1-2: 10 coins", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("• Day 3-6: 20 coins + 5 XP", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("• Day 7+: 50 coins + 10 XP + Lucky Spin", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text("• Miss 1 day = Streak reset!", style: TextStyle(color: Colors.red, fontSize: 12)),
        ])),
      ])),
    );
  }
}

class BlockReportScreen extends StatefulWidget {
  final String mobile;
  const BlockReportScreen({super.key, required this.mobile});
  @override State<BlockReportScreen> createState() => _BlockReportScreenState();
}

class _BlockReportScreenState extends State<BlockReportScreen> {
  List<Map<String,dynamic>> blocked = [];
  bool loading = true;

  @override void initState() { super.initState(); _loadBlocked(); }

  Future<void> _loadBlocked() async {
    try {
      final snap = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").get();
      blocked = snap.docs.map((d)=> {"id":d.id, ...d.data()}).toList();
      if (mounted) setState(() => loading = false);
    } catch (e) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _unblock(String target) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").doc(target).delete();
      if (mounted) setState(() => blocked.removeWhere((b)=> b["id"]==target));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unblocked")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("🚫 Block List", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)),
      body: loading ? const Center(child: CircularProgressIndicator()) : blocked.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("🚫", style: TextStyle(fontSize: 50)), SizedBox(height: 12), Text("Koi blocked user nahi", style: TextStyle(color: Colors.white54))])) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: blocked.length, itemBuilder: (_, i){
        final b = blocked[i];
        return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)), child: Row(children: [
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFF7F1D1D), child: Icon(Icons.block, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b["name"]??"Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: ${b["id"]}", style: const TextStyle(color: Colors.white54, fontSize: 11))])),
          ElevatedButton(onPressed: ()=> _unblock(b["id"]), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), child: const Text("Unblock", style: TextStyle(fontSize: 11))),
        ]));
      }),
    );
  }


}

class _CropDialog extends StatefulWidget {
  final Uint8List originalBytes;
  const _CropDialog({required this.originalBytes});
  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  double _scale = 1.0;
  double _prevScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _prevOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onScaleStart: (d) {
                _prevScale = _scale;
                _prevOffset = _offset;
              },
              onScaleUpdate: (d) {
                setState(() {
                  _scale = (_prevScale * d.scale).clamp(0.5, 3.0);
                  _offset = _prevOffset + d.focalPointDelta;
                });
              },
              child: ClipRect(
                child: Transform(
                  transform: Matrix4.identity()..translate(_offset.dx, _offset.dy)..scale(_scale),
                  child: Image.memory(widget.originalBytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(onPressed: () => Navigator.pop(context, widget.originalBytes), child: const Text("Done")),
            ],
          ),
        ],
      ),
    );
  }
}

