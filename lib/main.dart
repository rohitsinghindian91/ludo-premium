import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beautiful_ludo.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LudoPremiumApp());
}

class LudoPremiumApp extends StatelessWidget {
  const LudoPremiumApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF0A0E1A)),
      home: const LoginScreen(),
    );
  }
}

// LOGIN SCREEN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final referralController = TextEditingController();
  String usedRefCode = "";

  Future<void> register() async {
    String phone = phoneController.text.trim();
    String refCode = referralController.text.trim();
    if (phone.isEmpty) return;

    var userDoc = FirebaseFirestore.instance.collection('users').doc(phone);
    var doc = await userDoc.get();

    if (!doc.exists) {
      // Naya user
      await userDoc.set({
        'phone': phone,
        'ownReferralCode': phone.substring(phone.length - 6), // apna code
        'usedReferralCode': refCode, // kis ka code use kiya
        'wallet': 0,
        'isPremium': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Agar referral code dala hai to commission check
      if (refCode.isNotEmpty) {
        usedRefCode = refCode;
        await distributeCommission(refCode);
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(phone: phone)));
  }

  Future<void> distributeCommission(String refCode) async {
    // Level 1 find karo jis ka ownReferralCode == refCode
    var level1Query = await FirebaseFirestore.instance.collection('users').where('ownReferralCode', isEqualTo: refCode).get();
    if (level1Query.docs.isEmpty) return;

    var l1Doc = level1Query.docs.first;
    await l1Doc.reference.update({'wallet': FieldValue.increment(100)});

    String l1UsedCode = l1Doc.data()['usedReferralCode']?? "";
    if (l1UsedCode.isNotEmpty) {
      var level2Query = await FirebaseFirestore.instance.collection('users').where('ownReferralCode', isEqualTo: l1UsedCode).get();
      if (level2Query.docs.isNotEmpty) {
        var l2Doc = level2Query.docs.first;
        await l2Doc.reference.update({'wallet': FieldValue.increment(50)});

        String l2UsedCode = l2Doc.data()['usedReferralCode']?? "";
        if (l2UsedCode.isNotEmpty) {
          var level3Query = await FirebaseFirestore.instance.collection('users').where('ownReferralCode', isEqualTo: l2UsedCode).get();
          if (level3Query.docs.isNotEmpty) {
            await level3Query.docs.first.reference.update({'wallet': FieldValue.increment(25)});
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Mobile Number", labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            TextField(controller: referralController, decoration: const InputDecoration(labelText: "Referral Code (Optional)", labelStyle: TextStyle(color: Colors.white)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("LOGIN / REGISTER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// HOMEPAGE - AB STREAM SE AUTO UPDATE HOGA
class HomePage extends StatelessWidget {
  final String phone;
  const HomePage({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(phone).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var data = snapshot.data!.data() as Map<String, dynamic>??? {};
        int wallet = data['wallet']?? 0;
        bool isPremium = data['isPremium']?? false;
        String ownCode = data['ownReferralCode']?? "";
        String usedCode = data['usedReferralCode']?? "No Code Used";

        return Scaffold(
          appBar: AppBar(backgroundColor: Colors.amber, title: Text("Wallet: ₹$wallet"), actions: [IconButton(onPressed: (){}, icon: const Icon(Icons.person))]),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your Referral Code: $ownCode", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text("Joined with Code: ", style: TextStyle(color: Colors.white54)),
                          Text(usedCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Text("(Ye change nahi ho sakta)", style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(isPremium? "PREMIUM ACTIVE" : "NOT PREMIUM", style: TextStyle(color: isPremium? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    // Premium lagao - ab turant wallet aur homepage update hoga bina logout ke
                    await FirebaseFirestore.instance.collection('users').doc(phone).update({'isPremium': true});
                  },
                  child: const Text("BUY PREMIUM ₹500"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(gameMode: GameMode.vsLaddi)));
                  },
                  child: const Text("PLAY LUDO"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ADMIN PANEL - NEW USER SABSE UPAR
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel - All Users")),
      body: StreamBuilder<QuerySnapshot>(
        // YE LINE SABSE IMPORTANT HAI - new user upar ayega
        stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              var d = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(d['phone']?? "", style: const TextStyle(color: Colors.white)),
                subtitle: Text("Used: ${d['usedReferralCode']} | Own: ${d['ownReferralCode']} | Wallet: ${d['wallet']}", style: const TextStyle(color: Colors.white54)),
                trailing: Text(d['isPremium'] == true? "PREMIUM" : "FREE", style: const TextStyle(color: Colors.amber)),
              );
            },
          );
        },
      ),
    );
  }
}