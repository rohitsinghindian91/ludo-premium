import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Splash()));
}

// SPLASH
class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState()=>_SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState(){ super.initState(); check(); }
  check() async {
    var sp = await SharedPreferences.getInstance();
    String? m = sp.getString("mobile");
    await Future.delayed(const Duration(milliseconds: 700));
    if(!mounted) return;
    if(m!=null){ Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>HomePage(mobile: m))); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const LoginPage())); }
  }
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber)));
}

// LOGIN WITH REFERRAL + OTP DIRECT BUTTON
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final mobileCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final referCtrl = TextEditingController();

  void goToOtp() {
    if(mobileCtrl.text.trim().length!=10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    if(passCtrl.text.trim().length<4){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("4 digit password dalo"))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_)=>OtpDirectPage(mobile: mobileCtrl.text.trim(), password: passCtrl.text.trim(), referral: referCtrl.text.trim())));
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.casino_rounded, size: 70, color: Colors.amber),
      const SizedBox(height:10), const Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontSize:26, fontWeight: FontWeight.bold)),
      const SizedBox(height:25),
      TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Mobile Number", labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height:12),
      TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password", labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height:12),
      TextField(controller: referCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Referral Code (Optional)", hintText: "Kisi ka mobile number", hintStyle: const TextStyle(color: Colors.white24), labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height:20),
      SizedBox(width: double.infinity, height:50, child: ElevatedButton(onPressed: goToOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("GET OTP - DIRECT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
    ]))));
  }
}

// OTP DIRECT PAGE - 1234
class OtpDirectPage extends StatefulWidget {
  final String mobile, password, referral;
  const OtpDirectPage({super.key, required this.mobile, required this.password, required this.referral});
  @override State<OtpDirectPage> createState()=>_OtpDirectPageState();
}
class _OtpDirectPageState extends State<OtpDirectPage> {
  final otpCtrl = TextEditingController();
  bool loading = false;

  verifyOtp() async {
    if(otpCtrl.text.trim()!="1234"){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Direct OTP 1234 dalo"))); return; }
    setState((){ loading = true; });
    try{
      var doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      if(doc.exists){
        if(doc.data()!["password"]!=widget.password){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password galat"))); setState((){ loading=false; }); return; }
      } else {
        int bonus = 0;
        String referredBy = "";
        if(widget.referral.isNotEmpty){
          var q = await FirebaseFirestore.instance.collection("users").where("referralCode", isEqualTo: widget.referral).get();
          if(q.docs.isNotEmpty){
            referredBy = q.docs.first.id;
            bonus = 50;
            await FirebaseFirestore.instance.collection("users").doc(referredBy).update({"wallet": FieldValue.increment(50)});
          }
        }
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({
          "mobile": widget.mobile, "password": widget.password, "wallet": bonus, "upi": "", "isPremium": false,
          "referralCode": widget.mobile, "referredBy": referredBy, "premiumExpiry": Timestamp.now(), "createdAt": FieldValue.serverTimestamp()
        });
      }
      var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", widget.mobile);
      if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=>HomePage(mobile: widget.mobile)), (r)=>false);
    } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
    setState((){ loading = false; });
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(backgroundColor: Colors.amber, title: Text("OTP - ${widget.mobile}", style: const TextStyle(color: Colors.black, fontSize:16))),
      body: Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("OTP DIRECT VERIFICATION", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        const SizedBox(height:8), const Text("OTP is 1234 (Direct)", style: TextStyle(color: Colors.white38)),
        const SizedBox(height:25),
        TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize:32, letterSpacing: 10), decoration: InputDecoration(filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height:20),
        loading? const CircularProgressIndicator(color: Colors.amber) : SizedBox(width: double.infinity, height:50, child: ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("VERIFY 1234 & LOGIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

// HOME
class HomePage extends StatefulWidget { final String mobile; const HomePage({super.key, required this.mobile}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int wallet=0; String upi=""; bool isPrem=false; String expiry=""; String myCode="";
  @override void initState(){ super.initState(); loadData(); }
  loadData() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if(!d.exists) return;
    var data = d.data()!;
    setState((){
      wallet = data["wallet"]??0;
      upi = data["upi"]??"";
      myCode = data["referralCode"]??widget.mobile;
    });
    if(data["isPremium"]==true && data["premiumExpiry"]!=null){
      DateTime exp = (data["premiumExpiry"] as Timestamp).toDate();
      if(exp.isAfter(DateTime.now())){
        setState((){ isPrem=true; expiry="${exp.day}/${exp.month}/${exp.year}"; });
      } else {
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":false});
      }
    }
  }
  buyPremium() async {
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":true, "premiumExpiry": Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)))});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premium 500 Active 1 Month ✅")));
    loadData();
  }
  logout() async { var sp = await SharedPreferences.getInstance(); await sp.clear(); if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=>const LoginPage()), (r)=>false); }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(backgroundColor: Colors.amber, title: Text("${widget.mobile} | ₹$wallet", style: const TextStyle(color: Colors.black, fontSize:15, fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: logout, icon: const Icon(Icons.logout, color: Colors.black))]),
      body: Center(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isPrem?Colors.amber:Colors.white10, borderRadius: BorderRadius.circular(12)), child: Text(isPrem?"PREMIUM ACTIVE TILL $expiry":"FREE USER", textAlign: TextAlign.center, style: TextStyle(color: isPrem?Colors.black:Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height:10),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          Text("MY REFERRAL CODE: $myCode", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize:16)),
          const SizedBox(height:4), const Text("Share karo, har refer pe ₹50", style: TextStyle(color: Colors.white38, fontSize:12)),
          if(upi.isNotEmpty) Padding(padding: const EdgeInsets.only(top:8), child: Text("UPI: $upi", style: const TextStyle(color: Colors.white60))),
        ])),
        const SizedBox(height:25),
        SizedBox(width: double.infinity, height:60, child: ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>const LudoBoard())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("PLAY LUDO", style: TextStyle(fontSize:20, fontWeight: FontWeight.bold)))),
        const SizedBox(height:14),
        SizedBox(width: double.infinity, height:55, child: ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>WalletScreen(mobile: widget.mobile))).then((_){ loadData(); }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("WALLET / UPI SETTING", style: TextStyle(color: Colors.white)))),
        const SizedBox(height:14),
        if(!isPrem) SizedBox(width: double.infinity, height:55, child: ElevatedButton(onPressed: buyPremium, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("BUY PREMIUM ₹500 - 1 MONTH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState()=>_WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController(); int wallet=0; bool load=true;
  @override void initState(){ super.initState(); getData(); }
  getData() async { var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ setState((){ wallet=d.data()!["wallet"]??0; upiCtrl.text=d.data()!["upi"]??""; load=false; }); } else { setState((){ load=false; }); } }
  saveUpi() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": upiCtrl.text.trim()}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Save - Same Rahega ✅"))); Navigator.pop(context); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Wallet & UPI"), backgroundColor: Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body: load?const Center(child: CircularProgressIndicator()):Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Wallet Balance", style: TextStyle(color: Colors.white)), Text("₹$wallet", style: const TextStyle(color: Colors.amber, fontSize:22, fontWeight: FontWeight.bold))]))),
        const SizedBox(height:20),
        TextField(controller: upiCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"UPI ID", labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height:25), SizedBox(width: double.infinity, height:50, child: ElevatedButton(onPressed: saveUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SAVE UPI", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

class LudoBoard extends StatefulWidget { const LudoBoard({super.key}); @override State<LudoBoard> createState()=>_LudoBoardState(); }
class _LudoBoardState extends State<LudoBoard> {
  int dice=1; int pos=0; final rand=Random();
  rollDice(){ setState((){ dice=rand.nextInt(6)+1; pos=(pos+dice)%36; }); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Ludo Premium"), backgroundColor: Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body: Column(children: [
        const SizedBox(height:20),
        Center(child: Container(width: 330, height: 330, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, border: Border.all(width:4, color: Colors.amber), borderRadius: BorderRadius.circular(12)), child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6), itemCount: 36, itemBuilder: (c,i){ bool isHere = i==pos; return Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: isHere?Colors.green:Colors.grey[200], borderRadius: BorderRadius.circular(6)), child: Center(child: isHere?const Icon(Icons.person, color: Colors.white):null)); }))),
        const SizedBox(height:25), Text("$dice", style: const TextStyle(fontSize:80, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height:20), ElevatedButton(onPressed: rollDice, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal:50, vertical:14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("ROLL DICE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize:18))),
      ]),
    );
  }
}