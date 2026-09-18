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
      builder: (c, s) {
        if (s.hasData) {
          return const MainLudo();
        } else {
          return const LoginPage();
        }
      },
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

  void sendOTP() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: "+91${ph.text}",
      verificationCompleted: (a) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Failed")));
      },
      codeSent: (id, t) {
        setState(() {
          vid = id;
          sent = true;
        });
      },
      codeAutoRetrievalTimeout: (id) {
        vid = id;
      },
    );
  }

  void verifyOTP() async {
    try {
      var cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: otp.text);
      var result = await FirebaseAuth.instance.signInWithCredential(cred);
      String myCode = "LUDO${Random().nextInt(9000) + 1000}";
      await FirebaseFirestore.instance.collection("users").doc(result.user!.uid).set({
        "phone": ph.text,
        "myReferralCode": myCode,
        "usedReferral": ref.text,
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
            TextField(controller: ph, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mobile Number")),
            const SizedBox(height: 10),
            if (sent) TextField(controller: otp, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Enter OTP")),
            const SizedBox(height: 10),
            TextField(controller: ref, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Referral Code Optional")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: sent ? verifyOTP : sendOTP, child: Text(sent ? "VERIFY" : "SEND OTP"))
          ]),
        ),
      ),
    );
  }
}

class MainLudo extends StatelessWidget {
  const MainLudo({super.key});

  Future<void> payPremium(BuildContext context) async {
    final uri = Uri.parse("upi://pay?pa=Kumar131@fam&pn=Ludo&am=500&cu=INR");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    var uid = FirebaseAuth.instance.currentUser!.uid;
    DateTime expiry = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance.collection("users").doc(uid).set({
      "premium": true,
      "premiumExpiry": Timestamp.fromDate(expiry)
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Ludo Premium"), actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          Map<String, dynamic> data = {};
          if (snap.data!.data() != null) {
            data = Map<String, dynamic>.from(snap.data!.data() as Map);
          }
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Wallet: Rs ${data['wallet'] ?? 0}", style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 10),
              SelectableText("Your Code: ${data['myReferralCode'] ?? ''}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: () => payPremium(context), child: const Text("UNLOCK 30 DAYS - 500 Rs"))
            ]),
          );
        },
      ),
    );
  }
}