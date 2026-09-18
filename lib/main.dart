import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: LudoPremium()));
}

class LudoPremium extends StatefulWidget { @override _LudoState createState() => _LudoState(); }

class _LudoState extends State<LudoPremium> {
  String upi = "Kumar131@fam";
  bool isPremium = false;

  void pay() async {
    final uri = Uri.parse("upi://pay?pa=$upi&pn=Ludo Premium&am=500&cu=INR&tn=Premium");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    // Firebase me premium save
    await FirebaseFirestore.instance.collection("payments").add({
      "upi": upi,
      "amount": 500,
      "time": DateTime.now(),
      "status": "initiated"
    });
    setState(() => isPremium = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F5D32),
      appBar: AppBar(title: Text(isPremium ? "Premium Active" : "Ludo Premium Free"), backgroundColor: Colors.black),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.casino, size: 100, color: Colors.white),
          SizedBox(height: 20),
          Text(isPremium ? "Premium Unlocked!" : "500rs me Premium Lo", style: TextStyle(color: Colors.white, fontSize: 22)),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: pay,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], minimumSize: Size(250,60)),
            child: Text("PAY 500 - $upi", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if(isPremium) Padding(padding: EdgeInsets.all(20), child: Text("Firebase Connected: ludo-premium-50", style: TextStyle(color: Colors.white70))),
        ]),
      ),
    );
  }
}