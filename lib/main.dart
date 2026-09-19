import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'beautiful_ludo.dart';

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
    await Future.delayed(const Duration(milliseconds:500));
    if(!mounted) return;
    if(m!=null){ Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>HomePage(mobile:m))); }
    else { Navigator.pushReplacement(context, MaterialPageRoute(builder:(_)=>const LoginPage())); }
  }
  @override Widget build(BuildContext context)=> const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber)));
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final mobileCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final referCtrl = TextEditingController();
  void goOtp(){
    if(mobileCtrl.text.trim().length!=10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    Navigator.push(context, MaterialPageRoute(builder:(_)=>OtpPage(mobile:mobileCtrl.text.trim(), password:passCtrl.text.trim(), referral:referCtrl.text.trim())));
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children:[
      const Icon(Icons.casino_rounded, size:70, color:Colors.amber),
      const Text("LUDO PREMIUM", style:TextStyle(color:Colors.white, fontSize:26, fontWeight:FontWeight.bold)),
      const SizedBox(height:20),
      TextField(controller:mobileCtrl, keyboardType:TextInputType.phone, maxLength:10, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Mobile", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:10),
      TextField(controller:passCtrl, obscureText:true, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Password", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:10),
      TextField(controller:referCtrl, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Referral Code (Optional)", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:20),
      SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:goOtp, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("GET OTP DIRECT - 1234", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
    ]))));
  }
}

class OtpPage extends StatefulWidget { final String mobile,password,referral; const OtpPage({super.key, required this.mobile, required this.password, required this.referral}); @override State<OtpPage> createState()=>_OtpPageState(); }
class _OtpPageState extends State<OtpPage> {
  final otpCtrl = TextEditingController(); bool load=false;
  void verify() async {
    if(otpCtrl.text.trim()!="1234"){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP 1234 dalo"))); return; }
    setState((){ load=true; });
    try{
      var doc = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      if(!doc.exists){
        int bonus=0; String refBy="";
        if(widget.referral.isNotEmpty){
          var q = await FirebaseFirestore.instance.collection("users").where("referralCode", isEqualTo:widget.referral).get();
          if(q.docs.isNotEmpty){ refBy=q.docs.first.id; bonus=50; await FirebaseFirestore.instance.collection("users").doc(refBy).update({"wallet":FieldValue.increment(50)}); }
        }
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({"mobile":widget.mobile,"password":widget.password,"wallet":bonus,"upi":"","isPremium":false,"referralCode":widget.mobile,"referredBy":refBy,"premiumExpiry":Timestamp.now()});
      }
      var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", widget.mobile);
      if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>HomePage(mobile:widget.mobile)), (r)=>false);
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
    setState((){ load=false; });
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar:AppBar(title:Text("OTP ${widget.mobile}"), backgroundColor:Colors.amber),
      body:Center(child:Padding(padding:const EdgeInsets.all(20), child:Column(mainAxisSize:MainAxisSize.min, children:[
        const Text("Direct OTP = 1234", style:TextStyle(color:Colors.amber, fontWeight:FontWeight.bold)), const SizedBox(height:20),
        TextField(controller:otpCtrl, keyboardType:TextInputType.number, maxLength:4, textAlign:TextAlign.center, style:const TextStyle(color:Colors.white, fontSize:32, letterSpacing:8), decoration:InputDecoration(filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
        const SizedBox(height:20),
        load?const CircularProgressIndicator(color:Colors.amber):SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:verify, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber), child:const Text("VERIFY 1234", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
    ]))));
  }
}

class HomePage extends StatefulWidget { final String mobile; const HomePage({super.key, required this.mobile}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int wallet=0; String upi=""; String myCode=""; bool isPrem=false; String expiry="";
  @override void initState(){ super.initState(); load(); }
  void load() async {
    var d = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    if(!d.exists) return; var data=d.data()!;
    setState((){ wallet=data["wallet"]??0; upi=data["upi"]??""; myCode=data["referralCode"]??widget.mobile; });
    if(data["isPremium"]==true && data["premiumExpiry"]!=null){
      DateTime exp=(data["premiumExpiry"] as Timestamp).toDate();
      if(exp.isAfter(DateTime.now())){ setState((){ isPrem=true; expiry="${exp.day}/${exp.month}/${exp.year}"; }); }
    }
  }
  void buy() { Navigator.push(context, MaterialPageRoute(builder:(_)=>PremiumPayScreen(mobile:widget.mobile, onPaid: load))); }
  void logout() async { var sp=await SharedPreferences.getInstance(); await sp.clear(); if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>const LoginPage()), (r)=>false); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar:AppBar(backgroundColor:Colors.amber, title:Text("${widget.mobile} | ₹$wallet", style:const TextStyle(color:Colors.black, fontSize:14, fontWeight:FontWeight.bold)), actions:[IconButton(onPressed:logout, icon:const Icon(Icons.logout))]),
      body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(18), child:Column(children:[
        Container(width:double.infinity, padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:isPrem?Colors.amber:Colors.white10, borderRadius:BorderRadius.circular(12)), child:Text(isPrem?"PREMIUM TILL $expiry":"FREE USER - PREMIUM LO", textAlign:TextAlign.center, style:TextStyle(color:isPrem?Colors.black:Colors.white, fontWeight:FontWeight.bold))),
        const SizedBox(height:12),
        Container(width:double.infinity, padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:Colors.white10, borderRadius:BorderRadius.circular(12)), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text("MY REFERRAL: $myCode", style:const TextStyle(color:Colors.amber, fontWeight:FontWeight.bold)),
          const SizedBox(height:6),
          Text(upi.isEmpty ? "UPI: Not Set - Wallet me jao" : "UPI: $upi", style:TextStyle(color: upi.isEmpty ? Colors.redAccent : Colors.white60, fontSize:13)),
        ])),
        const SizedBox(height:25),
        // YAHAN FIX KIYA - FREE KO LUDO NAHI DIKHEGA
        isPrem 
        ? SizedBox(width:double.infinity, height:60, child:ElevatedButton(onPressed:(){ Navigator.push(context, MaterialPageRoute(builder:(_)=>const BeautifulLudoGame())); }, style:ElevatedButton.styleFrom(backgroundColor:Colors.green, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("PLAY LUDO 🎲", style:TextStyle(fontSize:20, fontWeight:FontWeight.bold, color:Colors.white))))
        : Container(width:double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)), child: const Column(children: [
            Icon(Icons.lock, color: Colors.redAccent, size: 40),
            SizedBox(height: 8),
            Text("LUDO LOCKED 🔒", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 4),
            Text("Khelne ke liye pehle Premium lo", style: TextStyle(color: Colors.white60, fontSize: 13)),
          ])),
        const SizedBox(height:15),
        SizedBox(width:double.infinity, height:55, child:ElevatedButton(onPressed:(){ Navigator.push(context, MaterialPageRoute(builder:(_)=>WalletScreen(mobile:widget.mobile))).then((_)=>load()); }, child:const Text("WALLET / UPI SETTING"))),
        const SizedBox(height:15),
        SizedBox(width:double.infinity, height:55, child:ElevatedButton(onPressed: isPrem ? null : buy, style:ElevatedButton.styleFrom(backgroundColor: isPrem ? Colors.grey : Colors.purple), child:Text(isPrem ? "PREMIUM ACTIVE ✅" : "BUY PREMIUM ₹500 - 1 MONTH", style:const TextStyle(color:Colors.white)))),
      ]))),
    );
  }
}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState()=>_WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl=TextEditingController(); int wallet=0; bool loading=true;
  @override void initState(){ super.initState(); get(); }
  void get() async { var d=await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ setState((){ wallet=d.data()!["wallet"]??0; upiCtrl.text=d.data()!["upi"]??""; loading=false; }); } else { setState((){ loading=false; }); } }
  void save() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi":upiCtrl.text.trim()}); if(!mounted) return; Navigator.pop(context); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text("Wallet"), backgroundColor:Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body:loading?const Center(child:CircularProgressIndicator()):Padding(padding:const EdgeInsets.all(20), child:Column(children:[
        Text("Wallet: ₹$wallet", style:const TextStyle(color:Colors.amber, fontSize:22)), const SizedBox(height:20),
        TextField(controller:upiCtrl, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"UPI ID", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
        const SizedBox(height:20), SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:save, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber), child:const Text("SAVE UPI - SAME RAHEGA", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
      ])),
    );
  }
}

class PremiumPayScreen extends StatelessWidget {
  final String mobile;
  final VoidCallback onPaid;
  const PremiumPayScreen({super.key, required this.mobile, required this.onPaid});
  final String myUpiId = "kumar131@fam";
  final String myName = "LUDO PREMIUM OWNER";

  Future<void> payViaUpi(BuildContext context) async {
    final String upiUrl = "upi://pay?pa=$myUpiId&pn=$myName&am=500&cu=INR&tn=Premium 1 Month for $mobile";
    final Uri uri = Uri.parse(upiUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("UPI App nahi khula, manually pay karo: $myUpiId pe ₹500")));
    }
  }

  Future<void> iHavePaid(BuildContext context) async {
    await FirebaseFirestore.instance.collection("premium_requests").doc(mobile).set({
      "mobile": mobile,
      "amount": 500,
      "payToUpi": myUpiId,
      "status": "pending",
      "time": Timestamp.now()
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Request bhej di ✅ Admin check karke Premium active karega")));
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("Buy Premium"), backgroundColor: Colors.amber),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
        const SizedBox(height: 20),
        const Text("Premium 1 Month - ₹500", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)), child: Column(children: [
          const Text("Is UPI pe ₹500 bhejo:", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          SelectableText(myUpiId, style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Amount: ₹500", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ])),
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => payViaUpi(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("PAY VIA GPAY / PHONEPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => iHavePaid(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("I HAVE PAID ₹500", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 20),
        const Text("Note: Pay karne ke baad 'I HAVE PAID' dabao. Firebase > premium_requests me request ayegi.", style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
      ])),
    );
  }
}

class LudoBoard extends StatefulWidget { const LudoBoard({super.key}); @override State<LudoBoard> createState()=>_LudoBoardState(); }
class _LudoBoardState extends State<LudoBoard> {
  int dice=1; int pos=0; final rand=Random();
  void roll(){ setState((){ dice=rand.nextInt(6)+1; pos=(pos+dice)%36; }); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text("LUDO PREMIUM"), backgroundColor:Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body:SingleChildScrollView(child: Column(children:[
        const SizedBox(height:15),
        Center(child: Container(width: 350, height: 350, padding: const EdgeInsets.all(5), decoration:BoxDecoration(color:Colors.white, border:Border.all(width:4, color:Colors.amber), borderRadius:BorderRadius.circular(15)), 
          child: GridView.builder(physics: const NeverScrollableScrollPhysics(), gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:6, crossAxisSpacing:3, mainAxisSpacing:3), itemCount:36, itemBuilder:(c,i){ bool here=i==pos; return Container(decoration:BoxDecoration(color:here?Colors.green: const Color(0xFFE0E0E0), borderRadius:BorderRadius.circular(8)), child: Center(child: here ? const Text("😎", style: TextStyle(fontSize:20)) : Text("$i", style:const TextStyle(fontSize:10)))); }))),
        const SizedBox(height:25), Text("$dice", style:const TextStyle(fontSize:60, color:Colors.white, fontWeight:FontWeight.bold)),
                      const SizedBox(height:15), 
                                          SizedBox(width:200, height:55, child: ElevatedButton(onPressed: roll, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("ROLL DICE 🎲", style: TextStyle(color:Colors.black, fontWeight:FontWeight.bold, fontSize:18)))),
              const SizedBox(height: 20),
              const Text("For any help contact - +447397293594 WHATSAPP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 5),
              const Text("NOTE: Payment Screenshot Whatsapp Per Bhejo Payment ke baad 10 min me ID unlock hogi", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
            ])),
      );
    );
  }
}