import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage()));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final m = TextEditingController(); final p = TextEditingController();
  bool l = false;
  login() async {
    if(m.text.length!=10) return;
    setState(()=>l=true);
    var d = await FirebaseFirestore.instance.collection("users").doc(m.text).get();
    if(d.exists && d.data()!["password"]!=p.text){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat password"))); setState(()=>l=false); return;
    }
    if(!d.exists){
      await FirebaseFirestore.instance.collection("users").doc(m.text).set({"mobile":m.text,"password":p.text,"wallet":0,"upi":"","isPremium":false,"premiumExpiry":Timestamp.now()});
    }
    var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m.text);
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>HomePage(mobile: m.text)));
    setState(()=>l=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.casino,size:70,color:Colors.amber), const SizedBox(height:20),
      TextField(controller: m, keyboardType: TextInputType.phone, maxLength:10, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mobile", border: OutlineInputBorder())),
      const SizedBox(height:10), TextField(controller: p, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
      const SizedBox(height:20), l?const CircularProgressIndicator():ElevatedButton(onPressed: login, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("LOGIN",style: TextStyle(color: Colors.black))),
    ]))));
  }
}

class HomePage extends StatelessWidget {
  final String mobile; const HomePage({super.key, required this.mobile});
  buy(BuildContext c) async { await FirebaseFirestore.instance.collection("users").doc(mobile).update({"isPremium":true,"premiumExpiry":Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)))}); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text("Premium 500 Active 1 Month"))); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text(mobile), backgroundColor: Colors.amber), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=>const Game())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal:50,vertical:15)), child: const Text("PLAY LUDO",style: TextStyle(fontSize:20))),
      const SizedBox(height:20), ElevatedButton(onPressed: ()=>buy(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: const Text("BUY PREMIUM ₹500 - 1 MONTH",style: TextStyle(color: Colors.white))),
    ])));
  }
}

class Game extends StatefulWidget { const Game({super.key}); @override State<Game> createState() => _GameState(); }
class _GameState extends State<Game> { int d=1; @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: const Text("Ludo")), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text("$d",style: const TextStyle(fontSize:80,fontWeight: FontWeight.bold)), ElevatedButton(onPressed: ()=>setState(()=>d=Random().nextInt(6)+1), child: const Text("ROLL DICE"))]))); } }