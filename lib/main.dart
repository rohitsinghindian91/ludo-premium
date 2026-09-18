import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SplashCheck()));
}

class SplashCheck extends StatefulWidget { const SplashCheck({super.key}); @override State<SplashCheck> createState() => _SplashCheckState(); }
class _SplashCheckState extends State<SplashCheck> {
  @override void initState(){ super.initState(); check(); }
  check() async {
    final sp = await SharedPreferences.getInstance();
    String? m = sp.getString("mobile");
    await Future.delayed(const Duration(seconds: 1));
    if(!mounted) return;
    if(m != null){ Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: m))); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LoginPage())); }
  }
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final mobile = TextEditingController(); final password = TextEditingController(); final referral = TextEditingController(); bool loading = false;
  Future<void> doLogin() async {
    String m = mobile.text.trim(); String p = password.text.trim();
    if(m.length!=10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    if(p.length<4){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("4 digit password"))); return; }
    setState(()=>loading=true);
    try{
      var doc = await FirebaseFirestore.instance.collection("users").doc(m).get();
      if(doc.exists){
        if(doc.data()!["password"]==p){
          final sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m);
          if(!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: m)));
        } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat password"))); }
      } else {
        await FirebaseFirestore.instance.collection("users").doc(m).set({"mobile":m,"password":p,"referral":referral.text.trim(),"wallet":0,"upi":"","isPremium":false,"createdAt":FieldValue.serverTimestamp()});
        final sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m);
        if(!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: m)));
      }
    } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
    setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      const Icon(Icons.casino,size:80,color:Colors.amber), const Text("Ludo Premium",style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)), const SizedBox(height:30),
      TextField(controller: mobile, keyboardType: TextInputType.phone, maxLength:10, style:const TextStyle(color:Colors.white), decoration: const InputDecoration(labelText:"Mobile", filled:true, fillColor: Colors.white10, border: OutlineInputBorder())),
      const SizedBox(height:10), TextField(controller: password, obscureText:true, style:const TextStyle(color:Colors.white), decoration: const InputDecoration(labelText:"Password", filled:true, fillColor: Colors.white10, border: OutlineInputBorder())),
      const SizedBox(height:10), TextField(controller: referral, style:const TextStyle(color:Colors.white), decoration: const InputDecoration(labelText:"Referral (Optional)", filled:true, fillColor: Colors.white10, border: OutlineInputBorder())),
      const SizedBox(height:20), loading? const CircularProgressIndicator(): SizedBox(width:double.infinity, child: ElevatedButton(onPressed: doLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("LOGIN / REGISTER",style:TextStyle(color:Colors.black,fontWeight:FontWeight.bold)))),
    ]))));
  }
}

class HomePage extends StatefulWidget { final String mobile; const HomePage({super.key, required this.mobile}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  bool isPremium=false; String expiry=""; int wallet=0;
  @override void initState(){ super.initState(); loadData(); }
  loadData() async { var d=await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ setState(()=>wallet=d.data()!["wallet"]??0); if(d.data()!["isPremium"]==true){ DateTime exp=(d.data()!["premiumExpiry"] as Timestamp).toDate(); if(exp.isAfter(DateTime.now())){ setState(()=>{isPremium=true, expiry="${exp.day}/${exp.month}/${exp.year}"}); } } } }
  buyPremium() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":true,"premiumExpiry":Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)))}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premium 500 - 1 Month Active ✅"))); loadData(); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(title: Text("Hi ${widget.mobile} | ₹$wallet"), backgroundColor: Colors.amber), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if(isPremium) Container(padding: const EdgeInsets.all(10), color: Colors.amber, child: Text("PREMIUM till $expiry",style: const TextStyle(fontWeight: FontWeight.bold))) else Container(padding: const EdgeInsets.all(10), color: Colors.red, child: const Text("FREE USER",style: TextStyle(color:Colors.white))),
      const SizedBox(height:20), ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> const LudoGameScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal:60,vertical:15)), child: const Text("PLAY LUDO",style:TextStyle(fontSize:20))),
      const SizedBox(height:15), if(!isPremium) ElevatedButton(onPressed: buyPremium, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text("BUY PREMIUM ₹500 - 1 MONTH",style:TextStyle(color:Colors.white))),
      const SizedBox(height:15), ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> WalletScreen(mobile: widget.mobile))); }, child: const Text("WALLET / UPI")),
    ])));
  }
}

class LudoGameScreen extends StatefulWidget { const LudoGameScreen({super.key}); @override State<LudoGameScreen> createState() => _LudoGameScreenState(); }
class _LudoGameScreenState extends State<LudoGameScreen> { int dice=1; @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: const Text("Ludo Game")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Dice: $dice",style: const TextStyle(fontSize:60,fontWeight:FontWeight.bold)), const SizedBox(height:20), ElevatedButton(onPressed: ()=>setState(()=>dice=Random().nextInt(6)+1), child: const Text("ROLL DICE"))]))); } }

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState() => _WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> { final upi=TextEditingController(); int wallet=0; @override void initState(){ super.initState(); load(); } load() async { var d=await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ setState(()=>{wallet=d.data()!["wallet"]??0, upi.text=d.data()!["upi"]??""}); } } save() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi":upi.text.trim()}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Saved Same ✅"))); } @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: const Text("Wallet")), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text("Wallet: ₹$wallet",style: const TextStyle(fontSize:24)), TextField(controller: upi, decoration: const InputDecoration(labelText:"UPI ID")), ElevatedButton(onPressed: save, child: const Text("SAVE UPI"))]))); } }