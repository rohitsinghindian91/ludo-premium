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
      TextField(controller:referCtrl, style:const TextStyle(color:Colors.white), decoration:InputDecoration(labelText:"Referral Code (Optional)", hintText:"Kisi ka mobile", filled:true, fillColor:Colors.white10, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
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
  void buy() async { await FirebaseFirestore.instance.collection("users").doc(widget.mobile).update({"isPremium":true, "premiumExpiry":Timestamp.fromDate(DateTime.now().add(const Duration(days:30)))}); load(); }
  void logout() async { var sp=await SharedPreferences.getInstance(); await sp.clear(); if(!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>const LoginPage()), (r)=>false); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar:AppBar(backgroundColor:Colors.amber, title:Text("${widget.mobile} | ₹$wallet", style:const TextStyle(color:Colors.black, fontSize