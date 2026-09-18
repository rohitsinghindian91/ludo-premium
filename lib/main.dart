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

class SplashCheck extends StatefulWidget {
  const SplashCheck({super.key});
  @override State<SplashCheck> createState() => _SplashCheckState();
}
class _SplashCheckState extends State<SplashCheck> {
  @override
  void initState() { super.initState(); check(); }
  check() async {
    final sp = await SharedPreferences.getInstance();
    String? m = sp.getString("mobile");
    await Future.delayed(const Duration(seconds: 1));
    if(!mounted) return;
    if(m != null){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: m)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LoginPage()));
    }
  }
  @override Widget build(BuildContext context) { return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber))); }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final mobile = TextEditingController();
  final password = TextEditingController();
  final referral = TextEditingController();
  bool loading = false;

  Future<void> doLogin() async {
    String m = mobile.text.trim();
    String p = password.text.trim();
    if (m.length != 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    if (p.length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 4 digit ka rakho"))); return; }
    setState(() => loading = true);
    try {
      var doc = await FirebaseFirestore.instance.collection("users").doc(m).get();
      if (doc.exists) {
        if (doc.data()!["password"] == p) {
          final sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m);
          if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(mobile: m)));
        } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Galat password"))); }
      } else {
        await FirebaseFirestore.instance.collection("users").doc(m).set({"mobile": m, "password": p, "referral": referral.text.trim(), "wallet": 0, "upi": "", "isPremium": false, "createdAt": FieldValue.serverTimestamp()});
        final sp = await SharedPreferences.getInstance(); await sp.setString("mobile", m);
        if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(mobile: m)));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    setState(() => loading = false);
  }

  InputDecoration _dec(String h) => InputDecoration(labelText: h, labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: "");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.casino, size: 80, color: Colors.amber),
            const Text("Ludo Premium", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(controller: mobile, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: _dec("Mobile Number")),
            const SizedBox(height: 10),
            TextField(controller: password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _dec("Password (4 digit)")),
            const SizedBox(height: 10),
            TextField(controller: referral, style: const TextStyle(color: Colors.white), decoration: _dec("Referral Code (Optional)")),
            const SizedBox(height: 20),
            loading ? const CircularProgressIndicator(color: Colors.amber) : SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.all(15)), onPressed: doLogin, child: const Text("LOGIN / REGISTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
          ]),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String mobile;
  const HomePage({super.key, required this.mobile});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  bool isPremium = false; String expiry = ""; int wallet = 0;
  @override void initState(){ super.initState(); loadData(); }
  loadData() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if(d.exists){
      setState((){ wallet = d.data()!["wallet"] ?? 0; });
      if(d.data()!["isPremium"] == true){
        DateTime exp = (d.data()!["premiumExpiry"] as Timestamp).toDate();
        if(exp.isAfter(DateTime.now())){ setState((){ isPremium = true; expiry = "${exp.day}/${exp.month}/${exp.year}"; }); }
      }
    }
  }
  buyPremium() async {
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium": true, "premiumExpiry": Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))), "premiumPlan": "500_1_MONTH"});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premium Active 1 Month ✅"))); loadData();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: Text("Hi ${widget.mobile} | ₹$wallet"), backgroundColor: Colors.amber, foregroundColor: Colors.black, actions: [IconButton(onPressed: () async { final sp = await SharedPreferences.getInstance(); await sp.clear(); if(context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LoginPage())); }, icon: const Icon(Icons.logout))]),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if(isPremium) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)), child: Text("PREMIUM ACTIVE till $expiry", style: const TextStyle(fontWeight: FontWeight.bold)))
        else Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(10)), child: const Text("FREE USER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 30),
        ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> const LudoGameScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15)), child: const Text("PLAY LUDO", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 15),
        if(!isPremium) ElevatedButton(onPressed: buyPremium, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)), child: const Text("BUY PREMIUM ₹500 - 1 MONTH", style: TextStyle(color: Colors.white))),
        const SizedBox(height: 15),
        ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> WalletScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text("WALLET / WITHDRAW / UPI")),
      ])),
    );
  }
}

class LudoGameScreen extends StatefulWidget { const LudoGameScreen({super.key}); @override State<LudoGameScreen> createState() => _LudoGameScreenState(); }
class _LudoGameScreenState extends State<LudoGameScreen> {
  int dice = 1;
  void roll(){ setState(() { dice = Random().nextInt(6)+1; }); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Ludo Premium - Game")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Dice: $dice", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold)), const SizedBox(height: 20), ElevatedButton(onPressed: roll, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)), child: const Text("ROLL DICE", style: TextStyle(fontSize: 18))), const SizedBox(height: 30), const Text("Yaha tera full Ludo board ayega")])) );
  }
}

class WalletScreen extends StatefulWidget {
  final String mobile; const WalletScreen({super.key, required this.mobile});
  @override State<WalletScreen> createState() => _WalletScreenState();
}
class _WalletScreenState extends State<WalletScreen> {
  final upi = TextEditingController(); int wallet = 0;
  @override void initState(){ super.initState(); load(); }
  load() async { var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ setState(() { wallet = d.data()!["wallet"] ?? 0; upi.text = d.data()!["upi"] ?? ""; }); } }
  saveUpi() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": upi.text.trim()}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Saved - Same Hai ✅"))); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Wallet & Withdraw")), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text("Wallet: ₹$wallet", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: upi, decoration: const InputDecoration(labelText: "UPI ID (Same Rahegi)", border: OutlineInputBorder())), const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: saveUpi, child: const Text("SAVE UPI"))), const SizedBox(height: 20), const Text("Withdraw isi UPI pe ayega, ID same hai.")])) );
  }
}