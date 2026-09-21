import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';
import 'referral_chart.dart';
import 'beautiful_ludo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Premium',
      home: Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    check();
  }
  check() async {
    var sp = await SharedPreferences.getInstance();
    var m = sp.getString("mobile");
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => m != null && m.isNotEmpty ? HomePage(mobile: m) : const LoginPage()),
    );
  }
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF0F172A),
    body: Center(child: CircularProgressIndicator(color: Colors.amber)),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final mobileCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("LUDO PREMIUM", style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: "Mobile", filled: true, fillColor: Colors.white)),
          const SizedBox(height: 10),
          TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(hintText: "Password", filled: true, fillColor: Colors.white)),
          const SizedBox(height: 10),
          TextField(controller: refCtrl, decoration: const InputDecoration(hintText: "Referral Code (Optional)", filled: true, fillColor: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (mobileCtrl.text.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile daalo")));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => OtpPage(mobile: mobileCtrl.text.trim(), password: passCtrl.text.trim(), referredBy: refCtrl.text.trim())));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 50)),
            child: const Text("GET OTP", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    ),
  );
}

class OtpPage extends StatefulWidget {
  final String mobile, password, referredBy;
  const OtpPage({super.key, required this.mobile, required this.password, required this.referredBy});
  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otpCtrl = TextEditingController();
  bool isPremiumActive(Map<String, dynamic> data) {
    if (data['isPremium'] != true) return false;
    var expiry = data['premiumExpiry'];
    if (expiry == null) return false;
    try {
      DateTime d = expiry is String ? DateTime.parse(expiry) : (expiry as Timestamp).toDate();
      return d.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }
  Future<void> distribute(String l1, String newUser) async {
    var users = FirebaseFirestore.instance.collection("users");
    try {
      var l1Doc = await users.doc(l1).get();
      if (!l1Doc.exists) return;
      var l1Data = l1Doc.data() as Map<String, dynamic>;
      if (isPremiumActive(l1Data)) {
        await users.doc(l1).update({"wallet": FieldValue.increment(100)});
      }
      String l2 = (l1Data['referredBy'] ?? "").toString();
      if (l2.isEmpty) return;
      var l2Doc = await users.doc(l2).get();
      if (!l2Doc.exists) return;
      var l2Data = l2Doc.data() as Map<String, dynamic>;
      if (isPremiumActive(l2Data)) {
        await users.doc(l2).update({"wallet": FieldValue.increment(50)});
      }
      String l3 = (l2Data['referredBy'] ?? "").toString();
      if (l3.isEmpty) return;
      var l3Doc = await users.doc(l3).get();
      if (!l3Doc.exists) return;
      var l3Data = l3Doc.data() as Map<String, dynamic>;
      if (isPremiumActive(l3Data)) {
        await users.doc(l3).update({"wallet": FieldValue.increment(25)});
      }
    } catch (e) {
      debugPrint("$e");
    }
  }
  verify() async {
    if (otpCtrl.text.trim() != "1234") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP 1234 daalo")));
      return;
    }
    var users = FirebaseFirestore.instance.collection("users");
    var doc = await users.doc(widget.mobile).get();
    if (!doc.exists) {
      await users.doc(widget.mobile).set({
        "mobile": widget.mobile,
        "password": widget.password,
        "referralCode": widget.mobile,
        "referredBy": widget.referredBy,
        "wallet": 0,
        "isPremium": false,
        "premiumExpiry": null,
        "upi": "",
        "createdAt": FieldValue.serverTimestamp()
      });
      if (widget.referredBy.isNotEmpty) {
        await distribute(widget.referredBy, widget.mobile);
      }
    }
    var sp = await SharedPreferences.getInstance();
    await sp.setString("mobile", widget.mobile);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomePage(mobile: widget.mobile)), (r) => false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("OTP = 1234", style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          TextField(controller: otpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Enter OTP", filled: true, fillColor: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: verify, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 50)), child: const Text("VERIFY", style: TextStyle(color: Colors.black))),
        ],
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  final String mobile;
  const HomePage({super.key, required this.mobile});
  bool isActive(Map<String, dynamic> d) {
    if (d['isPremium'] != true) return false;
    var e = d['premiumExpiry'];
    if (e == null) return false;
    try {
      DateTime dt = e is String ? DateTime.parse(e) : (e as Timestamp).toDate();
      return dt.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
  @override
  Widget build(BuildContext context) {
    var users = FirebaseFirestore.instance.collection("users");
    return StreamBuilder<DocumentSnapshot>(
      stream: users.doc(mobile).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var data = snap.data!.data() as Map<String, dynamic>? ?? {};
        int wallet = (data['wallet'] ?? 0) as int;
        bool active = isActive(data);
        String myCode = data['referralCode'] ?? mobile;
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: Text("Hi, $mobile"),
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                onPressed: () async {
                  var sp = await SharedPreferences.getInstance();
                  await sp.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
                  }
                },
                icon: const Icon(Icons.logout),
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Rs $wallet", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(child: Text("My Code: $myCode", style: const TextStyle(fontWeight: FontWeight.bold))),
                      IconButton(
                        onPressed: () async {
                          final uri = Uri.parse("https://wa.me/?text=Ludo Premium join karo, mera code: $myCode https://play.google.com/store/apps/details?id=com.ludo.premium.vludo_premium");
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => MyTeamScreen(mobile: mobile))); }, child: const Text("MY TEAM"))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(mobile: mobile))); }, child: const Text("WALLET"))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralChartScreen())); },
                    child: const Text("HOW 3 LEVEL PLAN WORKS?"),
                  ),
                ),
                const SizedBox(height: 20),
                if (active)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 60)),
                      onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const BeautifulLudo())); },
                      child: const Text("PLAY LUDO - PREMIUM ACTIVE", style: TextStyle(fontSize: 18)),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 60)),
                      onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumPayScreen(mobile: mobile))); },
                      child: const Text("BUY PREMIUM @ Rs 500", style: TextStyle(fontSize: 18)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WalletScreen extends StatefulWidget {
  final String mobile;
  const WalletScreen({super.key, required this.mobile});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl = TextEditingController();
  @override
  void initState() { super.initState(); load(); }
  load() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if (d.exists) upiCtrl.text = d.data()?['upi'] ?? "";
    setState(() {});
  }
  save() async {
    await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi": upiCtrl.text.trim()});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI Saved")));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Wallet")),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: upiCtrl, decoration: const InputDecoration(labelText: "Your UPI ID")),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: save, child: const Text("SAVE UPI")),
        ],
      ),
    ),
  );
}

class PremiumPayScreen extends StatelessWidget {
  final String mobile;
  const PremiumPayScreen({super.key, required this.mobile});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Buy Premium")),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Pay Rs 500 to UPI: kumar131@fam", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse("upi://pay?pa=kumar131@fam&pn=Kumar&am=500&cu=INR");
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text("PAY NOW"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse("https://wa.me/447397293594?text=Hi, I paid 500 for Ludo Premium, my mobile $mobile");
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text("SEND SCREENSHOT ON WHATSAPP"),
          ),
        ],
      ),
    ),
  );
}

class MyTeamScreen extends StatelessWidget {
  final String mobile;
  const MyTeamScreen({super.key, required this.mobile});
  @override
  Widget build(BuildContext context) {
    var users = FirebaseFirestore.instance.collection("users");
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text("My Team"), bottom: const TabBar(tabs: [Tab(text: "L1"), Tab(text: "EARNINGS")])),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: users.where("referredBy", isEqualTo: mobile).snapshots(),
              builder: (c, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(children: s.data!.docs.map((d) => ListTile(title: Text(d['mobile']))).toList());
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: users.doc(mobile).collection("earnings").orderBy("time", descending: true).snapshots(),
              builder: (c, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: s.data!.docs.map((d) {
                    var m = d.data() as Map;
                    return ListTile(title: Text("Rs ${m['amount']} from ${m['from']}"), subtitle: Text("Level ${m['level']}"));
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}