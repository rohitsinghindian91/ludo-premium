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

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState()=>_SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState(){ super.initState(); check(); }
  check() async {
    var sp = await SharedPreferences.getInstance();
    var m = sp.getString("mobile");
    await Future.delayed(const Duration(milliseconds: 800));
    if(!mounted) return;
    if(m!=null){ Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>HomePage(mobile: m))); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const LoginPage())); }
  }
  @override Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber)));
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final mobileCtrl = TextEditingController(); final passCtrl = TextEditingController(); bool load=false;
  login() async {
    String m = mobileCtrl.text.trim(); String p = passCtrl.text.trim();
    if(m.length!=10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile daalo"))); return; }
    if(p.length<4){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("4 digit password daalo"))); return; }
    setState(()=>load=true);
    try{
      var doc = await FirebaseFirestore.instance.collection("users").doc(m).get();
      if(doc.exists){
        if(doc.data()!["password"]!=p){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password galat hai"))); setState(()=>load=false); return; }
      } else {
        await FirebaseFirestore.instance.collection("users").doc(m).set({"mobile":m,"password":p,"wallet":0,"upi":"","isPremium":false,"premiumExpiry":Timestamp.now(),"createdAt":FieldValue.serverTimestamp()});
      }
      var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m);
      if(!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>HomePage(mobile: m)));
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
    setState(()=>load=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const Icon(Icons.casino_rounded,size:80,color: Colors.amber), const SizedBox(height:10), const Text("LUDO PREMIUM",style: TextStyle(color: Colors.white,fontSize:28,fontWeight: FontWeight.bold)),
      const SizedBox(height:30),
      TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, maxLength:10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"Mobile Number",labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height:12), TextField(controller: passCtrl, obscureText:true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"Password",labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height:20), load?const CircularProgressIndicator(color: Colors.amber):SizedBox(width: double.infinity, height:50, child: ElevatedButton(onPressed: login, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("LOGIN / REGISTER",style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold)))),
    ]))));
  }
}

class HomePage extends StatefulWidget { final String mobile; const HomePage({super.key, required this.mobile}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int wallet=0; bool isPrem=false; String upi=""; String expiry="";
  @override void initState(){ super.initState(); load(); }
  load() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if(!d.exists) return;
    var data = d.data()!;
    setState(()=>{wallet=data["wallet"]??0, upi=data["upi"]??""});
    if(data["isPremium"]==true && data["premiumExpiry"]!=null){
      DateTime exp = (data["premiumExpiry"] as Timestamp).toDate();
      if(exp.isAfter(DateTime.now())){
        setState(()=>{isPrem=true, expiry="${exp.day}/${exp.month}/${exp.year}"});
      } else {
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":false});
      }
    }
  }
  buy() async {
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":true,"premiumExpiry":Timestamp.fromDate(DateTime.now().add(const Duration(days:30)))});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premium 500 Active 1 Month ✅")));
    load();
  }
  logout() async { var sp=await SharedPreferences.getInstance(); await sp.clear(); if(!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const LoginPage())); }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: Colors.amber, title: Text("${widget.mobile} | ₹$wallet",style: const TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize:16)), actions: [IconButton(onPressed: logout, icon: const Icon(Icons.logout,color: Colors.black))]),
      body: Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isPrem?Colors.amber:Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(isPrem?"PREMIUM ACTIVE TILL $expiry":"FREE USER - BUY PREMIUM",textAlign: TextAlign.center, style: TextStyle(color: isPrem?Colors.black:Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height:10), if(upi.isNotEmpty) Text("UPI: $upi",style: const TextStyle(color: Colors.white54)),
        const SizedBox(height:30),
        SizedBox(width: double.infinity, height:60, child: ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>const LudoBoardScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("PLAY LUDO",style: TextStyle(fontSize:20,fontWeight: FontWeight.bold)))),
        const SizedBox(height:16),
        SizedBox(width: double.infinity, height:55, child: ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>WalletScreen(mobile: widget.mobile))).then((_)=>load()); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("WALLET / UPI SETTING",style: TextStyle(color: Colors.white)))),
        const SizedBox(height:16),
        if(!isPrem) SizedBox(width: double.infinity, height:55, child: ElevatedButton(onPressed: buy, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("BUY PREMIUM ₹500 - 1 MONTH",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState()=>_WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController(); int wallet=0; bool load=true;
  @override void initState(){ super.initState(); get(); }
  get() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if(d.exists){ setState(()=>{wallet=d.data()!["wallet"]??0, upiCtrl.text=d.data()!["upi"]??"", load=false}); } else { setState(()=>load=false); }
  }
  save() async {
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi":upiCtrl.text.trim()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Save Ho Gaya - Same Rahega ✅")));
    Navigator.pop(context);
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text("Wallet & UPI"), backgroundColor: Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body: load?const Center(child: CircularProgressIndicator()):Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Wallet Balance",style: TextStyle(color: Colors.white)), Text("₹$wallet",style: const TextStyle(color: Colors.amber,fontSize:22,fontWeight: FontWeight.bold))]))),
        const SizedBox(height:20),
        TextField(controller: upiCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"UPI ID (e.g. 7027513091@paytm)",labelStyle: const TextStyle(color: Colors.white54), filled:true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height:10), const Text("Ek baar UPI daloge toh hamesha same rahega, logout karne par bhi",style: TextStyle(color: Colors.white38,fontSize:12)),
        const SizedBox(height:20), SizedBox(width: double.infinity, height:50, child: ElevatedButton(onPressed: save, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SAVE UPI",style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

class LudoBoardScreen extends StatefulWidget { const LudoBoardScreen({super.key}); @override State<LudoBoardScreen> createState()=>_LudoBoardScreenState(); }
class _LudoBoardScreenState extends State<LudoBoardScreen> {
  int dice=1; int pos=0; final rand=Random();
  final List<Color> trail = [Colors.white, Colors.white, Colors.green, Colors.white, Colors.white, Colors.white, Colors.white, Colors.red, Colors.white, Colors.white, Colors.white, Colors.white, Colors.yellow, Colors.white, Colors.white, Colors.white, Colors.white, Colors.blue];
  roll(){
    setState(()=>dice=rand.nextInt(6)+1);
    setState(()=>pos=(pos+dice)%52);
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("Ludo - Premium"), backgroundColor: Colors.amber),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(children: [
        const SizedBox(height:20),
        Center(child: Container(width: 320, height: 320, decoration: BoxDecoration(color: Colors.white, border: Border.all(width:4,color: Colors.amber), borderRadius: BorderRadius.circular(10)), child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6), itemCount: 36, itemBuilder: (c,i){
          bool isPlayer = i==pos%36;
          return Container(margin: const EdgeInsets.all(1), decoration: BoxDecoration(color: isPlayer?Colors.green: (i%2==0?Colors.white:Colors.grey[200]), borderRadius: BorderRadius.circular(4)), child: Center(child: isPlayer?const Icon(Icons.person_pin,color: Colors.white):null));
        }))),
        const SizedBox(height:30),
        Text("$dice",style: const TextStyle(fontSize:80,fontWeight: FontWeight.bold,color: Colors.white)),
        Text("Position: $pos",style: const TextStyle(color: Colors.white54)),
        const SizedBox(height:20),
        ElevatedButton(onPressed: roll, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal:50,vertical:15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("ROLL DICE",style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize:18))),
      ]),
    );
  }
}