import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'ludo_2player.dart'; // naya 2 player ludo

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(LudoPremiumApp());
}

class LudoPremiumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Premium',
      theme: ThemeData(primarySwatch: Colors.amber, scaffoldBackgroundColor: Color(0xFF121B2F)),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF121B2F), Color(0xFF1E2A4A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino, size: 100, color: Colors.amber),
            SizedBox(height: 20),
            Text("LUDO PREMIUM", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            Text("2 Player Edition", style: TextStyle(color: Colors.white70)),
            SizedBox(height: 50),
            ElevatedButton(
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => Ludo2Player()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: Size(250, 60), shape: StadiumBorder()),
              child: Text("PLAY LUDO 🎲", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: (){},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, minimumSize: Size(250, 50), shape: StadiumBorder()),
              child: Text("PREMIUM UNLOCKED 👑", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}