import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: AuthGate()));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, s) => s.hasData ? const MainLudo() : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ph = TextEditingController();
  final otp = TextEditingController();
  final ref = TextEditingController();
  String vid = "";
  bool sent = false;

  void send() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${ph.text}",
      verificationCompleted: (a) {},
      verificationFailed: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Failed"))),
      codeSent: (id, t) { setState(() { vid = id; sent = true; }); },
      codeAutoRetrievalTimeout: (id) => vid = id,
    );
  }

  void verify() async {
    try {
      var cr = PhoneAuthProvider.credential(verificationId: vid, smsCode: otp.text);
      var u = await FirebaseAuth.instance.signInWithCredential(cr);
      String myCode = "LUDO${Random().nextInt(9000) + 1000}";
      await FirebaseFirestore.instance.collection("users").doc(u.user!.uid).set({
        "phone": ph.text,
        "myReferralCode": myCode,
        "usedReferral": ref.text,
        "premium": false,
        "wallet": ref.text.isNotEmpty ? 100 : 0,
        "created": DateTime.now()
      }, SetOptions(merge: true));

      if (ref.text.isNotEmpty) {
        var q = await FirebaseFirestore.instance.collection("users").where("myReferralCode", isEqualTo: ref.text).get();
        for (var d in q.docs) {
          await FirebaseFirestore.instance.collection("users").doc(d.id).update({"wallet": FieldValue.increment(100)});
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Galat")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5D32),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.casino, size: 80, color: Colors.white),
            const Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: ph, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mobile Number", labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)))),
            if (sent) Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: otp, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Enter OTP", labelStyle: TextStyle(color: Colors.white70)))),
            const SizedBox(height: 10),
            TextField(controller: ref, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Referral Code (Optional) = 100rs Bonus", labelStyle: TextStyle(color: Colors.yellow))),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: sent ? verify : send, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: Text(sent ? "VERIFY & LOGIN" : "SEND OTP"))
          ]),
        ),
      ),
    );
  }
}

class MainLudo extends StatelessWidget {
  const MainLudo({super.key});

  void pay(BuildContext context) async {
    String upi = "Kumar131@fam";
    final uri = Uri.parse("upi://pay?pa=$upi&pn=Ludo Premium&am=500&cu=INR&tn=30 Days Premium");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    var uid = FirebaseAuth.instance.currentUser!.uid;
    DateTime expiry = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "premium": true,
      "premiumStart": Timestamp.now(),
      "premiumExpiry": Timestamp.fromDate(expiry),
    });
    ScaffoldMessenger.of(context