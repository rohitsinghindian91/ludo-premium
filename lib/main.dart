import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage()));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final mobile = TextEditingController();
  final password = TextEditingController();
  final referral = TextEditingController();
  bool loading = false;

  Future<void> doLogin() async {
    String m = mobile.text.trim();
    String p = password.text.trim();
    
    if(m.length != 10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    if(p.length < 4){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 4 digit ka dalo"))); return; }

    setState(()=> loading = true);
    try{
      var doc = await FirebaseFirestore.instance.collection('users').doc(m).get();
      if(doc.exists){
        if(doc['password'] == p){
          // Login Success
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> MainLudo(mobile: m)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat Password!")));
        }
      } else {
        // New User - Password hi uska account bana dega
        await FirebaseFirestore.instance.collection('users').doc(m).set({
          'mobile': m,
          'password': p, // Yahi password save ho gaya
          'referral': referral.text,
          'coins': 50,
          'createdAt': FieldValue.serverTimestamp(),
        });
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> MainLudo(mobile: m)));
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(()=> loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Text("LUDO PREMIUM", style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          TextField(controller: mobile, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Mobile Number", filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password (Naya bana lo)", filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: referral, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Referral Code (Optional)", filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          loading ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)), onPressed: doLogin, child: const Text("LOGIN / REGISTER", style: TextStyle(fontSize: 18, color: Colors.white))),
          const SizedBox(height: 10),
          const Text("Pehli baar jo password daloge wahi ban jayega", style: TextStyle(color: Colors.white54, fontSize: 12))
        ]),
      )),
    );
  }
}

class MainLudo extends StatelessWidget {
  final String mobile;
  const MainLudo({super.key, required this.mobile});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Welcome $mobile"), backgroundColor: Colors.amber),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("Game Start Hoga Yaha Se", style: TextStyle(fontSize: 20)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: (){}, child: const Text("PLAY LUDO"))
      ])),
    );
  }
}