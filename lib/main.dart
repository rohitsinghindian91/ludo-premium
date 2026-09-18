import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: AuthGate()));
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (c, s) => s.hasData? MainLudo() : LoginPage());
  }
}

class LoginPage extends StatefulWidget { @override _LState createState() => _LState(); }
class _LState extends State<LoginPage> {
  final ph = TextEditingController(); final otp = TextEditingController(); final ref = TextEditingController();
  String vid=""; bool sent=false;
  send() async { await FirebaseAuth.instance.verifyPhoneNumber(phoneNumber: "+91${ph.text}", verificationCompleted: (a){}, verificationFailed: (e)=> ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message!))), codeSent: (id,t){ setState((){vid=id; sent=true;}); }, codeAutoRetrievalTimeout: (id)=>vid=id); }
  verify() async {
    try{
      var cr = PhoneAuthProvider.credential(verificationId: vid, smsCode: otp.text);
      var u = await FirebaseAuth.instance.signInWithCredential(cr);
      String myCode = "LUDO${Random().nextInt(9000)+1000}";
      await FirebaseFirestore.instance.collection("users").doc(u.user!.uid).set({"phone": ph.text, "myReferralCode": myCode, "usedReferral": ref.text, "premium": false, "wallet": ref.text.isNotEmpty? 100 : 0, "created": DateTime.now()}, SetOptions(merge: true));
      if(ref.text.isNotEmpty){
        var q = await FirebaseFirestore.instance.collection("users").where("myReferralCode", isEqualTo: ref.text).get();
        for(var d in q.docs){ await FirebaseFirestore.instance.collection("users").doc(d.id).update({"wallet": FieldValue.increment(100)}); }
      }
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Galat"))); }
  }
  @override Widget build(BuildContext context){ return Scaffold(backgroundColor: Color(0xFF0F5D32), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.casino, size: 80, color: Colors.white), Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 20),
    TextField(controller: ph, keyboardType: TextInputType.phone, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Mobile Number", labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)))),
    if(sent) Padding(padding: EdgeInsets.only(top: 10), child: TextField(controller: otp, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Enter OTP", labelStyle: TextStyle(color: Colors.white70)))),
    SizedBox(height: 10), TextField(controller: ref, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Referral Code (Optional) = ₹100 Bonus", labelStyle: TextStyle(color: Colors.yellow))),
    SizedBox(height: 20), ElevatedButton(onPressed: sent?verify:send, style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)), child: Text(sent?"VERIFY & LOGIN":"SEND OTP"))
  ]))));}
}

class MainLudo extends StatelessWidget {
  String upi = "Kumar131@fam";

  pay(BuildContext context) async {
    final uri = Uri.parse("upi://pay?pa=$upi&pn=Ludo Premium&am=500&cu=INR&tn=30 Days Premium");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    // 30 Din ka Premium Set
    var uid = FirebaseAuth.instance.currentUser!.uid;
    DateTime expiry = DateTime.now().add(Duration(days: 30));
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      "premium": true,
      "premiumStart": Timestamp.now(),
      "premiumExpiry": Timestamp.fromDate(expiry),
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Premium Activated for 30 Days!")));
  }

  @override Widget build(BuildContext context){
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(backgroundColor: Color(0xFF0F5D32), appBar: AppBar(title: Text("Ludo Premium - 30 Days"), backgroundColor: Colors.black, actions: [IconButton(onPressed: ()=> FirebaseAuth.instance.signOut(), icon: Icon(Icons.logout))]),
      body: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(), builder: (c,snap){
        if(!snap.hasData) return Center(child: CircularProgressIndicator());
        var data = snap.data!.data() as Map<String,dynamic>??? {};
        bool isPremium = false;
        String expiryText = "No Premium";
        if(data['premiumExpiry']!= null){
          DateTime exp = (data['premiumExpiry'] as Timestamp).toDate();
          if(DateTime.now().isBefore(exp)){
            isPremium = true;
            expiryText = "${exp.day}/${exp.month}/${exp.year} tak Valid";
          }
        }
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isPremium? Colors.green : Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(isPremium? "PREMIUM ACTIVE - 30 Days" : "FREE USER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          SizedBox(height: 10), Text(expiryText, style: TextStyle(color: Colors.white70)),
          SizedBox(height: 20),
          Text("Wallet: ₹${data['wallet']?? 0}", style: TextStyle(color: Colors.yellow, fontSize: 26, fontWeight: FontWeight.bold)),
          SizedBox(height: 10), Text("Tera Referral Code", style: TextStyle(color: Colors.white70)), SelectableText("${data['myReferralCode']?? '...'}", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text("Share kar, har dost pe ₹100", style: TextStyle(color: Colors.white54)), SizedBox(height: 40),
          if(!isPremium) ElevatedButton(onPressed: ()=> pay(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], minimumSize: Size(280, 65)), child: Text("UNLOCK 30 DAYS ₹500\n$upi", textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
          else ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: Size(280, 60)), child: Text("PLAY LUDO PREMIUM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))),
        ]));
      }),
    );
  }
}