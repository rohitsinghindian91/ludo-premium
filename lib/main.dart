import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ludo_2player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MaterialApp(home: AuthCheck(), debugShowCheckedModeBanner: false));
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) => snap.hasData ? Home() : Login(),
    );
  }
}

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(child: ElevatedButton(
        onPressed: () => FirebaseAuth.instance.signInAnonymously(),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: Size(220,55), shape: StadiumBorder()),
        child: Text("PLAY AS GUEST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      )),
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.casino, size: 80, color: Colors.amber),
        SizedBox(height: 20),
        Text("LUDO CHROME", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => Ludo2Player())),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: Size(240,60), shape: StadiumBorder()),
          child: Text("PLAY 2 PLAYER", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ])),
    );
  }
}