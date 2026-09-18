import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(LudoPremiumApp());
}

class LudoPremiumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Ludo Premium', debugShowCheckedModeBanner: false, home: AuthGate());
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(stream: FirebaseAuth.instance.authStateChanges(), builder: (c, snap) {
      if (snap.hasData) return PremiumCheckScreen();
      return Scaffold(body: Center(child: ElevatedButton(onPressed: () => FirebaseAuth.instance.signInAnonymously(), child: Text("Start Ludo Premium"))));
    });
  }
}

class PremiumCheckScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder(stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(), builder: (c, snap) {
      if (!snap.hasData) return Scaffold(body: Center(child: CircularProgressIndicator()));
      var data = snap.data!.data();
      bool isPremium = data!= null && data['isPremium'] == true;
      if (isPremium) return LudoBoardScreen();
      return PayScreen();
    });
  }
}

class PayScreen extends StatefulWidget {
  @override
  _PayScreenState createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final referController = TextEditingController();
  final utrController = TextEditingController();
  String myUpiId = "ludopremium@okaxis"; // YAHAN APNI UPI ID DAALNA HAI

  void payWithUPI() async {
    String upiUrl = "upi://pay?pa=$myUpiId&pn=Ludo Premium&am=500&cu=INR&tn=Premium 30 Days";
    final uri = Uri.parse(upiUrl);
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
  }

  void submitPayment() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('payments').doc(uid).set({'uid': uid, 'utr': utrController.text, 'referCode': referController.text, 'amount': 500, 'status': 'pending', 'time': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'isPremium': false, 'wallet': 0, 'myReferCode': uid.substring(0, 6).toUpperCase(), 'usedReferCode': referController.text}, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Submitted - Admin Approve Karega")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Premium Lo - 500rs")), body: Padding(padding: EdgeInsets.all(20), child: Column(children: [
      TextField(controller: referController, decoration: InputDecoration(labelText: "Refer Code (Optional)", border: OutlineInputBorder())),
      SizedBox(height: 15),
      ElevatedButton(onPressed: payWithUPI, child: Text("Step 1: 500rs Pay Karo - UPI"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(double.infinity, 50))),
      SizedBox(height: 20),
      TextField(controller: utrController, decoration: InputDecoration(labelText: "Step 2: UTR ID Daalo", border: OutlineInputBorder())),
      SizedBox(height: 10),
      ElevatedButton(onPressed: submitPayment, child: Text("Step 3: Submit Karo"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50))),
    ])));
  }
}

class LudoBoardScreen extends StatefulWidget {
  @override
  _LudoBoardScreenState createState() => _LudoBoardScreenState();
}

class _LudoBoardScreenState extends State<LudoBoardScreen> {
  int dice = 1; int turn = 0;
  List<String> colors = ["RED", "GREEN", "YELLOW", "BLUE"];
  List<Color> colorCodes = [Colors.red, Colors.green, Colors.yellow.shade700, Colors.blue];
  void rollDice() { setState(() { dice = Random().nextInt(6) + 1; turn = (turn + 1) % 4; }); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("LUDO - ${colors[turn]} Turn"), backgroundColor: colorCodes[turn]), body: Column(children: [
      Container(height: 400, margin: EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(width: 3)), child: GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15), itemCount: 225, itemBuilder: (c, i) => Container(margin: EdgeInsets.all(0.5), color: Colors.grey[200]))),
      Text("Dice: $dice", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
      ElevatedButton(onPressed: rollDice, child: Text("ROLL DICE - ${colors[turn]}"), style: ElevatedButton.styleFrom(backgroundColor: colorCodes[turn], minimumSize: Size(200, 50))),
    ]));
  }
}