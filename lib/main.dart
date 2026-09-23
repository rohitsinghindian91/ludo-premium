import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'beautiful_ludo.dart';
import 'plan_screen.dart';
import 'friends_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Splash()));
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashState(); }
class _SplashState extends State<Splash> {
  @override void initState() { super.initState(); checkUser(); }
  Future<void> checkUser() async {
    var sp = await SharedPreferences.getInstance();
    var m = sp.getString("mobile");
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (m!= null && m.isNotEmpty) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(mobile: m))); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())); }
  }
  @override Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.casino_rounded, size: 80, color: Colors.amber), SizedBox(height: 16), CircularProgressIndicator(color: Colors.amber), SizedBox(height: 10), Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));
  }
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final nameCtrl = TextEditingController(); final mobileCtrl = TextEditingController(); final passCtrl = TextEditingController(); final referCtrl = TextEditingController();
  Future<void> goOtp() async {
    if (nameCtrl.text.trim().length < 2) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Naam dalo"))); return; }
    if (mobileCtrl.text.trim().length!= 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    if (passCtrl.text.trim().length < 4) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password 4 digit"))); return; }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => OtpPage(name: nameCtrl.text.trim(), mobile: mobileCtrl.text.trim(), password: passCtrl.text.trim(), referral: referCtrl.text.trim())));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange.shade700]), shape: BoxShape.circle), child: const Icon(Icons.casino_rounded, size: 50, color: Colors.black)),
      const SizedBox(height: 16), const Text("LUDO PREMIUM", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)), const SizedBox(height: 30),
      TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Apna Naam", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Mobile", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      TextField(controller: referCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Referral Code (Optional)", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: goOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("NEXT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
    ])))));
  }
}

class OtpPage extends StatefulWidget { final String name, mobile, password, referral; const OtpPage({super.key, required this.name, required this.mobile, required this.password, required this.referral}); @override State<OtpPage> createState() => _OtpPageState(); }
class _OtpPageState extends State<OtpPage> {
  final otpCtrl = TextEditingController(); bool load = false;
  Future<void> verifyOtp() async {
    if (otpCtrl.text.trim()!= "1234") { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP 1234 dalo"))); return; }
    setState(() => load = true);
    var doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if (!doc.exists) {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({"name": widget.name, "mobile": widget.mobile, "password": widget.password, "referralCode": widget.mobile, "referredBy": widget.referral, "wallet": 0, "upi": "", "isPremium": false, "premiumExpiry": null, "premiumDistributed": false, "createdAt": FieldValue.serverTimestamp()});
    }
    var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", widget.mobile);
    setState(() => load = false);
    if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomePage(mobile: widget.mobile)), (r) => false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(backgroundColor: const Color(0xFF0A0E1A), title: const Text("OTP Verify")), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Text("OTP 1234 hai", style: TextStyle(color: Colors.white54)), const SizedBox(height: 20),
      TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.bold), decoration: InputDecoration(filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
      const SizedBox(height: 20),
      load? const CircularProgressIndicator(color: Colors.amber) : SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("VERIFY 1234", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
    ])));
  }
}

class HomePage extends StatefulWidget { final String mobile; const HomePage({super.key, required this.mobile}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  int wallet = 0; String upi = ""; String myCode = ""; String referredBy = ""; bool isPrem = false; String expiry = ""; String myName = ""; String referredByName = "";
  @override void initState() { super.initState(); listenUser(); }
  void listenUser() {
    FirebaseFirestore.instance.collection("users").doc(widget.mobile).snapshots().listen((d) async {
      if (!d.exists) return; var data = d.data()!; if (!mounted) return;
      setState(() { wallet = data["wallet"]?? 0; upi = data["upi"]?? ""; myCode = data["referralCode"]?? widget.mobile; referredBy = data["referredBy"]?? ""; myName = data["name"]?? ""; });
      if (referredBy.isNotEmpty && referredByName.isEmpty) { var refDoc = await FirebaseFirestore.instance.collection("users").doc(referredBy).get(); if (refDoc.exists) { if (mounted) setState(() => referredByName = refDoc.data()?["name"]?? referredBy); } }
      if (data["isPremium"] == true) {
        if (data["premiumExpiry"]!= null) {
          DateTime exp = (data["premiumExpiry"] as Timestamp).toDate();
          if (exp.isAfter(DateTime.now())) { setState(() { isPrem = true; expiry = "${exp.day}/${exp.month}/${exp.year}"; }); if (data["premiumDistributed"] == false) { distributePremium(); } }
        }
      }
    });
  }
  Future<void> distributePremium() async {
    try {
      var me = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      if (!me.exists) return; var data = me.data()!; if (data["premiumDistributed"] == true) return;
      String l1 = data["referredBy"]?? "";
      if (l1.isNotEmpty) {
        var l1Doc = await FirebaseFirestore.instance.collection("users").doc(l1).get();
        if (l1Doc.exists) {
          await FirebaseFirestore.instance.collection("users").doc(l1).update({"wallet": FieldValue.increment(100)});
          await FirebaseFirestore.instance.collection("earnings").add({"to": l1, "from": widget.mobile, "amount": 100, "type": "L1 Premium", "time": FieldValue.serverTimestamp()});
          String l2 = l1Doc.data()?["referredBy"]?? "";
          if (l2.isNotEmpty) {
            var l2Doc = await FirebaseFirestore.instance.collection("users").doc(l2).get();
            if (l2Doc.exists) {
              await FirebaseFirestore.instance.collection("users").doc(l2).update({"wallet": FieldValue.increment(50)});
              await FirebaseFirestore.instance.collection("earnings").add({"to": l2, "from": widget.mobile, "amount": 50, "type": "L2 Premium", "time": FieldValue.serverTimestamp()});
              String l3 = l2Doc.data()?["referredBy"]?? "";
              if (l3.isNotEmpty) {
                var l3Doc = await FirebaseFirestore.instance.collection("users").doc(l3).get();
                if (l3Doc.exists) { await FirebaseFirestore.instance.collection("users").doc(l3).update({"wallet": FieldValue.increment(25)}); await FirebaseFirestore.instance.collection("earnings").add({"to": l3, "from": widget.mobile, "amount": 25, "type": "L3 Premium", "time": FieldValue.serverTimestamp()}); }
              }
            }
          }
        }
      }
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"premiumDistributed": true});
    } catch (e) { debugPrint("dist error $e"); }
  }
  void openPremium() { Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumPayScreen(mobile: widget.mobile, onPaid: () {}))); }
  void doLogout() async { var sp = await SharedPreferences.getInstance(); await sp.clear(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false); }
  void openHelp() async { String num = "447397293594"; String msg = "Help ${widget.mobile}"; Uri url = Uri.parse("https://wa.me/$num?text=${Uri.encodeComponent(msg)}"); await launchUrl(url, mode: LaunchMode.externalApplication); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [const Icon(Icons.casino, color: Colors.amber), const SizedBox(width: 8), Text(widget.mobile, style: const TextStyle(color: Colors.white)), const Spacer(), Text("Rs $wallet", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), const SizedBox(width: 8), InkWell(onTap: doLogout, child: const Icon(Icons.logout, color: Colors.white54))]),
      const SizedBox(height: 16),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: isPrem? [Colors.amber, Colors.orange] : [Color(0xFF1E293B), Color(0xFF151A2B)]), borderRadius: BorderRadius.circular(16)), child: Text(isPrem? "PREMIUM ACTIVE Till $expiry" : "FREE USER - Buy Premium", style: TextStyle(color: isPrem? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("My Refer Code (Locked): $myCode", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)), Text("Name Locked: $myName", style: const TextStyle(color: Colors.white54, fontSize: 10)), Text(referredBy.isEmpty? "Referred By: Direct (No Refer)" : "Referred By (Locked): ${referredByName.isEmpty? referredBy : referredByName} | Code: $referredBy | Last4: ****${referredBy.length >= 4? referredBy.substring(referredBy.length - 4) : referredBy}", style: const TextStyle(color: Colors.white54, fontSize: 10)) ])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () { if (!isPrem) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Premium Lo"))); openPremium(); return; } Navigator.push(context, MaterialPageRoute(builder: (_) => LobbyScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("PLAY LUDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00BCD4)), child: const Text("UPI SET KARE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => MyTeamScreen(mobile: widget.mobile))); }, child: const Text("MY TEAM")))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => PlanScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("PLAN CHART", style: TextStyle(color: Colors.black)))), const SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsScreen(mobile: widget.mobile))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text("FRIENDS", style: TextStyle(color: Colors.white))))]),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isPrem? null : openPremium, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text(isPrem? "PREMIUM ACTIVE" : "BUY PREMIUM Rs 500", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)))),
      const SizedBox(height: 12),
      TextButton(onPressed: openHelp, child: const Text("Help: +447397293594")),
    ])))));
  }
}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState() => _WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController(); int wallet = 0; bool loading = true; String existingUpi = ""; String myPassword = "";
  @override void initState() { super.initState(); loadWallet(); }
  Future<void> loadWallet() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if (d.exists) { setState(() { wallet = d.data()!["wallet"]?? 0; upiCtrl.text = d.data()!["upi"]?? ""; existingUpi = d.data()!["upi"]?? ""; myPassword = d.data()!["password"]?? ""; loading = false; }); }
  }
  Future<void> saveUpi() async {
    String newUpi = upiCtrl.text.trim(); if (newUpi.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI dalo"))); return; }
    if (existingUpi.isEmpty) { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": newUpi}); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Set Ho Gaya - Locked"))); Navigator.pop(context); return; }
    if (newUpi == existingUpi) { Navigator.pop(context); return; }
    TextEditingController passCtrl = TextEditingController();
    bool? ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: Color(0xFF1E1E2E), title: const Text("Password Daalo UPI Change Ke Liye", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), content: TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Login Password", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("Verify", style: TextStyle(color: Colors.black))) ]));
    if (ok!= true) return; if (passCtrl.text.trim()!= myPassword) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password galat hai"))); return; }
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": newUpi}); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Change Ho Gaya"))); Navigator.pop(context);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(title: const Text("Wallet"), backgroundColor: Colors.amber), body: loading? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text("Rs $wallet", style: const TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: upiCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "UPI ID", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saveUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SAVE", style: TextStyle(color: Colors.black)))) ])));
  }
}

class PremiumPayScreen extends StatefulWidget { final String mobile; final VoidCallback onPaid; const PremiumPayScreen({super.key, required this.mobile, required this.onPaid}); @override State<PremiumPayScreen> createState() => _PremiumPayScreenState(); }
class _PremiumPayScreenState extends State<PremiumPayScreen> {
  final String myUpiId = "kumar131@fam"; bool loading = false;
  Future<void> payUpi() async { String url = "upi://pay?pa=$myUpiId&pn=LUDO&am=500&cu=INR"; await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
  Future<void> sendSS() async {
    final picker = ImagePicker(); final XFile? img = await picker.pickImage(source: ImageSource.gallery); if (img == null) return;
    setState(() { loading = true; });
    await FirebaseFirestore.instance.collection("premium_requests").doc(widget.mobile).set({"mobile": widget.mobile, "amount": 500, "status": "CHECK", "time": Timestamp.now()});
    String num = "447397293594"; Uri wa = Uri.parse("https://wa.me/$num?text=Check ${widget.mobile}"); await launchUrl(wa, mode: LaunchMode.externalApplication); setState(() { loading = false; });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(title: const Text("Buy Premium"), backgroundColor: Colors.amber), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Text("Premium Rs 500", style: TextStyle(color: Colors.white, fontSize: 22)), const SizedBox(height: 20), SelectableText(myUpiId, style: const TextStyle(color: Colors.amber, fontSize: 20)), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: payUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("PAY Rs 500"))), const SizedBox(height: 12), loading? const CircularProgressIndicator() : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: sendSS, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("SEND SCREENSHOT", style: TextStyle(color: Colors.black)))) ])));
  }
}

class MyTeamScreen extends StatefulWidget { final String mobile; const MyTeamScreen({super.key, required this.mobile}); @override State<MyTeamScreen> createState() => _MyTeamScreenState(); }
class _MyTeamScreenState extends State<MyTeamScreen> with SingleTickerProviderStateMixin {
  late TabController tabCtrl; List<DocumentSnapshot> l1 = []; List<DocumentSnapshot> l2 = []; List<DocumentSnapshot> l3 = []; List<DocumentSnapshot> earn = []; bool loading = true;
  @override void initState() { super.initState(); tabCtrl = TabController(length: 4, vsync: this); fetchTeam(); }
  Future<void> fetchTeam() async {
    setState(() { loading = true; });
    var q1 = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: widget.mobile).get(); l1 = q1.docs;
    List<DocumentSnapshot> temp2 = []; for (var d in q1.docs) { var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: d.id).get(); temp2.addAll(q.docs); } l2 = temp2;
    List<DocumentSnapshot> temp3 = []; for (var d in temp2) { var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: d.id).get(); temp3.addAll(q.docs); } l3 = temp3;
    var e = await FirebaseFirestore.instance.collection("earnings").where("to", isEqualTo: widget.mobile).get(); earn = e.docs; setState(() { loading = false; });
  }
  Widget buildList(List<DocumentSnapshot> list, String emptyMsg) {
    if (list.isEmpty) { return Center(child: Text(emptyMsg, style: TextStyle(color: Colors.white54))); }
    return ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) {
      var data = list[i].data() as Map<String, dynamic>; String name = data["name"]?? "User"; String mob = data["mobile"]?? ""; String last4 = mob.length >= 4? mob.substring(mob.length - 4) : mob; String refCode = data["referralCode"]?? mob; String prem = data["isPremium"] == true? "PREMIUM" : "FREE";
      return Container(margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.amber, child: Text(name.isNotEmpty? name[0].toUpperCase() : "U", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), title: Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Code: $refCode | Last4: ****$last4", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)), Text("Status: $prem", style: TextStyle(color: Colors.white54, fontSize: 9))])));
    });
  }
  Widget buildEarnList() {
    if (earn.isEmpty) { return Center(child: Text("No earning", style: TextStyle(color: Colors.white54))); }
    return ListView.builder(itemCount: earn.length, itemBuilder: (ctx, i) {
      var d = earn[i].data() as Map; String fromMob = d["from"]?? ""; String last4 = fromMob.length >= 4? fromMob.substring(fromMob.length - 4) : fromMob;
      return Container(margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10)), child: ListTile(title: Text("${d["type"]} - Rs ${d["amount"]}", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text("From: ****$last4 | Code: $fromMob", style: TextStyle(color: Colors.white54, fontSize: 10))));
    });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0A0E1A), appBar: AppBar(backgroundColor: Colors.amber, title: const Text("MY TEAM"), bottom: TabBar(controller: tabCtrl, tabs: const [Tab(text: "L1"), Tab(text: "L2"), Tab(text: "L3"), Tab(text: "EARN")])), body: loading? const Center(child: CircularProgressIndicator()) : TabBarView(controller: tabCtrl, children: [buildList(l1, "Level 1 empty"), buildList(l2, "Level 2 empty"), buildList(l3, "Level 3 empty"), buildEarnList()]));
  }
}