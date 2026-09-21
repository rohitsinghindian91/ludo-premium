import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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
    if(m!= null) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: m)));
    else Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> const LoginPage()));
  }
  @override Widget build(BuildContext context)=> const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.amber)));
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final mobileCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final referCtrl = TextEditingController();
  void goOtp() async {
    if(mobileCtrl.text.trim().length!=10){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("10 digit mobile dalo"))); return; }
    var doc = await FirebaseFirestore.instance.collection("users").doc(mobileCtrl.text.trim()).get();
    if(doc.exists){
      if(doc['password']!= passCtrl.text.trim()){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password galat hai"))); return; }
      var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", mobileCtrl.text.trim());
      if(!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: mobileCtrl.text.trim())));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_)=> OtpPage(mobile: mobileCtrl.text.trim(), password: passCtrl.text.trim(), referral: referCtrl.text.trim())));
    }
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children:[
      const Icon(Icons.casino_rounded, size:70, color:Colors.amber), const Text("LUDO PREMIUM", style:TextStyle(color:Colors.white, fontSize:26, fontWeight:FontWeight.bold)), const SizedBox(height:20),
      TextField(controller:mobileCtrl, keyboardType:TextInputType.phone, maxLength:10, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Mobile", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:10), TextField(controller:passCtrl, obscureText:true, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Password", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:10), TextField(controller:referCtrl, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Referral Code (Optional)", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:20), SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:goOtp, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("GET OTP DIRECT - 1234", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
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
        String refBy=""; if(widget.referral.isNotEmpty){ var q = await FirebaseFirestore.instance.collection("users").where("referralCode", isEqualTo:widget.referral).get(); if(q.docs.isNotEmpty) refBy=q.docs.first.id; }
        await FirebaseFirestore.instance.collection("users").doc(widget.mobile).set({"mobile":widget.mobile, "password":widget.password, "wallet":0, "upi":"", "isPremium":false, "referralCode":widget.mobile, "referredBy":refBy, "premiumExpiry":Timestamp.now(), "premiumDistributed": false});
      }
      var sp = await SharedPreferences.getInstance(); await sp.setString("mobile", widget.mobile);
      if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=> HomePage(mobile: widget.mobile)), (r)=>false);
    }catch(e){ if(mounted &&!kReleaseMode) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
    if(mounted) setState((){ load=false; });
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar:AppBar(title:Text("OTP ${widget.mobile}"), backgroundColor:Colors.amber),
    body:Center(child:Padding(padding:const EdgeInsets.all(20), child:Column(mainAxisSize:MainAxisSize.min, children:[
      const Text("Direct OTP = 1234", style:TextStyle(color:Colors.amber, fontWeight:FontWeight.bold)), const SizedBox(height:20),
      TextField(controller:otpCtrl, keyboardType:TextInputType.number, maxLength:4, textAlign:TextAlign.center, style:const TextStyle(color:Colors.white, fontSize:32, letterSpacing:8), decoration:InputDecoration(filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:20), load?const CircularProgressIndicator(color:Colors.amber):SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:verify, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber), child:const Text("VERIFY 1234", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
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
    if(!mounted) return;
    setState((){ wallet=data["wallet"]??0; upi=data["upi"]??""; myCode=data["referralCode"]??widget.mobile; });
    if(data["isPremium"]==true && data["premiumExpiry"]!=null){
      DateTime exp=(data["premiumExpiry"] as Timestamp).toDate();
      if(exp.isAfter(DateTime.now())){
        if(!mounted) return;
        setState((){ isPrem=true; expiry="${exp.day}/${exp.month}/${exp.year}"; });
        if(data["premiumDistributed"]==false){
          await distributePremiumCommission(widget.mobile);
          await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"premiumDistributed": true});
        }
      }
    }
  }
  Future<void> distributePremiumCommission(String buyerMobile) async {
    try{
      var buyerDoc = await FirebaseFirestore.instance.collection("users").doc(buyerMobile).get(); if(!buyerDoc.exists) return;
      String? currentRef = buyerDoc.data()?["referredBy"]; List<int> commissions = [100, 50, 25]; int levelIndex = 0;
      while(currentRef!= null && currentRef.isNotEmpty && levelIndex < 3){
        var refDoc = await FirebaseFirestore.instance.collection("users").doc(currentRef).get(); if(!refDoc.exists) break;
        var data = refDoc.data()!; bool isActive = false;
        if(data["isPremium"]==true && data["premiumExpiry"]!=null){
          DateTime exp = (data["premiumExpiry"] as Timestamp).toDate(); if(exp.isAfter(DateTime.now())) isActive = true;
        }
        if(isActive){
          await FirebaseFirestore.instance.collection("users").doc(currentRef).update({"wallet": FieldValue.increment(commissions[levelIndex])});
          await FirebaseFirestore.instance.collection("earnings").add({"to": currentRef, "from": buyerMobile, "type": "premium_level_${levelIndex+1}", "amount": commissions[levelIndex], "time": FieldValue.serverTimestamp()});
          levelIndex++;
        }
        currentRef = data["referredBy"] as String?;
      }
    }catch(e){ if(kDebugMode) debugPrint("Commission error"); }
  }
  void buy(){ Navigator.push(context, MaterialPageRoute(builder: (_)=> PremiumPayScreen(mobile: widget.mobile, onPaid: (){ load(); }))).then((_)=>load()); }
  void logout() async { var sp=await SharedPreferences.getInstance(); await sp.clear(); if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>const LoginPage()), (r)=>false); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar:AppBar(backgroundColor:Colors.amber, title:Text("${widget.mobile} | ₹$wallet", style:const TextStyle(color:Colors.black, fontSize:14, fontWeight:FontWeight.bold)), actions:[IconButton(onPressed:logout, icon:const Icon(Icons.logout))]),
    body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(18), child:Column(children:[
      Container(width:double.infinity, padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:isPrem?Colors.amber:Colors.white10, borderRadius:BorderRadius.circular(12)), child:Text(isPrem?"PREMIUM TILL $expiry":"FREE USER - PREMIUM LO", textAlign:TextAlign.center, style:TextStyle(color:isPrem?Colors.black:Colors.white, fontWeight:FontWeight.bold))),
      const SizedBox(height:12),
      Container(width:double.infinity, padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:Colors.white10, borderRadius:BorderRadius.circular(12)), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[ Text("MY REFERRAL: $myCode", style:const TextStyle(color:Colors.amber, fontWeight:FontWeight.bold)), const SizedBox(height:6), Text(upi.isEmpty? "UPI: Not Set - Wallet me jao" : "UPI: $upi", style:TextStyle(color: upi.isEmpty? Colors.redAccent : Colors.white60, fontSize:13)), ])),
      const SizedBox(height:12), Container(width:double.infinity, padding:const EdgeInsets.all(10), decoration:BoxDecoration(color:Colors.green.withOpacity(0.15), borderRadius:BorderRadius.circular(12), border: Border.all(color: Colors.green)), child: const Text("3 LEVEL PLAN: L1=₹100 | L2=₹50 | L3=₹25 (Only Active Premium ko)", textAlign:TextAlign.center, style:TextStyle(color:Colors.greenAccent, fontSize:12, fontWeight:FontWeight.bold))),
      const SizedBox(height:20),
      isPrem? SizedBox(width:double.infinity, height:60, child:ElevatedButton(onPressed:(){ Navigator.push(context, MaterialPageRoute(builder:(_)=>const BeautifulLudoGame())); }, style:ElevatedButton.styleFrom(backgroundColor:Colors.green, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("PLAY FINAL 4 GOTI LUDO 🎲", style:TextStyle(fontSize:18, fontWeight:FontWeight.bold, color:Colors.white))))
      : Container(width:double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)), child: const Column(children: [ Icon(Icons.lock, color: Colors.redAccent, size: 40), SizedBox(height: 8), Text("LUDO LOCKED 🔒", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4), Text("Khelne ke liye pehle Premium lo", style: TextStyle(color: Colors.white60, fontSize: 13), textAlign: TextAlign.center), ])),
      const SizedBox(height:15),
      Row(children:[
        Expanded(child: SizedBox(height:55, child:ElevatedButton(onPressed:(){ Navigator.push(context, MaterialPageRoute(builder:(_)=>WalletScreen(mobile:widget.mobile))).then((_)=>load()); }, child:const Text("WALLET")))),
        const SizedBox(width:10),
        Expanded(child: SizedBox(height:55, child:ElevatedButton(onPressed:(){ Navigator.push(context, MaterialPageRoute(builder:(_)=>MyTeamScreen(mobile:widget.mobile))); }, style:ElevatedButton.styleFrom(backgroundColor:Colors.blueAccent), child:const Text("MY TEAM", style:TextStyle(color:Colors.white))))),
      ]),
      const SizedBox(height:15),
      SizedBox(width:double.infinity, height:55, child:ElevatedButton(onPressed: isPrem? null : buy, style:ElevatedButton.styleFrom(backgroundColor: isPrem? Colors.grey : Colors.purple), child:Text(isPrem? "PREMIUM ACTIVE ✅" : "BUY PREMIUM ₹500 - 1 MONTH", style:const TextStyle(color:Colors.white)))),
      const SizedBox(height: 20), const Text("For help: +447397293594 WHATSAPP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    ]))),
    );
  }
}

class WalletScreen extends StatefulWidget { final String mobile; const WalletScreen({super.key, required this.mobile}); @override State<WalletScreen> createState()=>_WalletScreenState(); }
class _WalletScreenState extends State<WalletScreen> {
  final upiCtrl=TextEditingController(); int wallet=0; bool loading=true;
  @override void initState(){ super.initState(); get(); }
  void get() async { var d=await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get(); if(d.exists){ if(mounted) setState((){ wallet=d.data()!["wallet"]??0; upiCtrl.text=d.data()!["upi"]??""; loading=false; }); } else { if(mounted) setState((){ loading=false; }); } }
  void save() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"upi":upiCtrl.text.trim()}); if(!mounted) return; Navigator.pop(context); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text("Wallet"), backgroundColor:Colors.amber), backgroundColor: const Color(0xFF0F172A),
    body:loading?const Center(child:CircularProgressIndicator()):Padding(padding:const EdgeInsets.all(20), child:Column(children:[
      Text("Wallet: ₹$wallet", style:const TextStyle(color:Colors.amber, fontSize:22)), const SizedBox(height:20),
      TextField(controller:upiCtrl, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"UPI ID", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
      const SizedBox(height:20), SizedBox(width:double.infinity, height:50, child:ElevatedButton(onPressed:save, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber), child:const Text("SAVE UPI", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold)))),
    ])),
    );
  }
}

class PremiumPayScreen extends StatefulWidget {
  final String mobile; final VoidCallback onPaid;
  const PremiumPayScreen({super.key, required this.mobile, required this.onPaid});
  @override State<PremiumPayScreen> createState()=> _PremiumPayScreenState();
}
class _PremiumPayScreenState extends State<PremiumPayScreen> {
  final String myUpiId = "kumar131@fam";
  bool loading = false;
  Future<void> payViaUpi() async {
    final String upiUrl = "upi://pay?pa=$myUpiId&pn=LUDO OWNER&am=500&cu=INR&tn=Premium ${widget.mobile}";
    try { await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication); } catch(e){ if(kDebugMode) debugPrint("UPI Error"); }
  }
  Future<void> pickAndSendDirectWhatsapp() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if(image == null) return;
    if(!mounted) return;
    setState(()=> loading = true);
    try{
        await FirebaseFirestore.instance.collection("premium_requests").doc(widget.mobile).set({
      "mobile": widget.mobile,
      "amount": 500,
      "status": "CHECK PLEASE SS",
      "time": Timestamp.now(),
    });
  String myNumber = "447397293594";
  String msg = "CHECK PLEASE SS\nMobile: ${widget.mobile}\nAmount: ₹500";
  Uri waUrl = Uri.parse("https://wa.me/$myNumber?text=${Uri.encodeComponent(msg)}");
  if (await canLaunchUrl(waUrl)) {
    await launchUrl(waUrl, mode: LaunchMode.externalApplication);
  }
  await Share.shareXFiles([XFile(image.path)], text: msg);
    }catch(e){ if(mounted &&!kReleaseMode) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    if(mounted) setState(()=> loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(title: const Text("Buy Premium"), backgroundColor: Colors.amber),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.workspace_premium, size: 80, color: Colors.amber), const SizedBox(height: 20),
        const Text("Premium 1 Month - ₹500", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)), child: Column(children: [ const Text("Is UPI pe ₹500 bhejo:", style: TextStyle(color: Colors.white70)), const SizedBox(height: 10), SelectableText(myUpiId, style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)), ])),
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: payViaUpi, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("STEP 1: PAY ₹500 VIA UPI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 15),
        loading? const CircularProgressIndicator(color: Colors.amber) :
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: pickAndSendDirectWhatsapp, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), icon: const Icon(Icons.camera_alt, color: Colors.black), label: const Text("STEP 2: SCREENSHOT SIDHA WHATSAPP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))),
      ])),
    );
  }
}

class MyTeamScreen extends StatefulWidget { final String mobile; const MyTeamScreen({super.key, required this.mobile}); @override State<MyTeamScreen> createState()=>_MyTeamScreenState(); }
class _MyTeamScreenState extends State<MyTeamScreen> with SingleTickerProviderStateMixin {
  late TabController tabCtrl;
  List<DocumentSnapshot> level1=[], level2=[], level3=[];
  List<DocumentSnapshot> earnings=[];
  bool loading=true;
  @override void initState(){ super.initState(); tabCtrl=TabController(length: 4, vsync: this); fetchTeam(); }
  @override void dispose(){ tabCtrl.dispose(); super.dispose(); }
  Future<void> fetchTeam() async {
    if(!mounted) return; setState(()=>loading=true);
    try{
      var l1 = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: widget.mobile).get();
      level1 = l1.docs;
      List<DocumentSnapshot> l2temp=[]; for(var doc in l1.docs){ var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: doc.id).get(); l2temp.addAll(q.docs); }
      level2 = l2temp;
      List<DocumentSnapshot> l3temp=[]; for(var doc in l2temp){ var q = await FirebaseFirestore.instance.collection("users").where("referredBy", isEqualTo: doc.id).get(); l3temp.addAll(q.docs); }
      level3 = l3temp;
      var earn = await FirebaseFirestore.instance.collection("earnings").where("to", isEqualTo: widget.mobile).get();
      earnings = earn.docs;
    }catch(e){ if(kDebugMode) debugPrint("error"); }
    if(mounted) setState(()=>loading=false);
  }
  Widget userTile(DocumentSnapshot doc){
    var data = doc.data() as Map<String, dynamic>;
    bool active = false;
    if(data["isPremium"]==true && data["premiumExpiry"]!=null){
      DateTime exp=(data["premiumExpiry"] as Timestamp).toDate();
      if(exp.isAfter(DateTime.now())) active=true;
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active? Colors.green : Colors.red,
        child: Icon(active? Icons.check : Icons.close, color: Colors.white)
      ),
      title: Text(data["mobile"]??"", style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        active? "Premium Active" : "Free / Expired",
        style: TextStyle(color: active? Colors.greenAccent : Colors.redAccent, fontSize: 12)
      ),
      trailing: Text(
        "₹${active? (data["wallet"]??0) : 0}",
        style: const TextStyle(color: Colors.amber)
      )
    );
  }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(backgroundColor: Colors.amber, title: const Text("MY TEAM", style: TextStyle(color: Colors.black)), bottom: TabBar(controller: tabCtrl, labelColor: Colors.black, unselectedLabelColor: Colors.black54, tabs: const [ Tab(text: "L1 (100)"), Tab(text: "L2 (50)"), Tab(text: "L3 (25)"), Tab(text: "EARNINGS"), ])),
      body: loading? const Center(child:CircularProgressIndicator(color: Colors.amber)): TabBarView(controller: tabCtrl, children: [
        ListView(children: level1.isEmpty? [const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Koi nahi hai Level 1 me", style: TextStyle(color: Colors.white54))))] : level1.map((e)=>userTile(e)).toList()),
        ListView(children: level2.isEmpty? [const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Koi nahi hai Level 2 me", style: TextStyle(color: Colors.white54))))] : level2.map((e)=>userTile(e)).toList()),
        ListView(children: level3.isEmpty? [const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Koi nahi hai Level 3 me", style: TextStyle(color: Colors.white54))))] : level3.map((e)=>userTile(e)).toList()),
        ListView(children: earnings.isEmpty? [const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Abhi koi earning nahi", style: TextStyle(color: Colors.white54))))] : earnings.map((e){ var d=e.data() as Map; return ListTile(leading: const Icon(Icons.currency_rupee, color: Colors.green), title: Text("${d["type"]} - ₹${d["amount"]}", style: const TextStyle(color: Colors.white)), subtitle: Text("From: ${d["from"]}", style: const TextStyle(color: Colors.white54, fontSize: 12))); }).toList()),
      ]),
    );
  }
}