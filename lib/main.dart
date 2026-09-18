import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, home: LudoApp()));

class LudoApp extends StatefulWidget { @override _LudoAppState createState() => _LudoAppState(); }

class _LudoAppState extends State<LudoApp> {
  String upiId = "Kumar131@fam";
  bool isPremium = false;
  int dice = 1;
  int currentPlayer = 0;
  List<String> players = ["Red", "Green", "Yellow", "Blue"];
  List<Color> colors = [Colors.red, Colors.green, Colors.orange, Colors.blue];

  void rollDice() {
    setState(() {
      dice = Random().nextInt(6) + 1;
      currentPlayer = (currentPlayer + 1) % 4;
    });
  }

  void payForPremium() async {
    final uri = Uri.parse("upi://pay?pa=$upiId&pn=Ludo Premium&am=500&cu=INR&tn=Premium 30 Days");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => isPremium = true); // Payment ke baad unlock
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F5D32),
      appBar: AppBar(
        title: Text(isPremium? "Ludo Premium - Active" : "Ludo Premium - Free"),
        backgroundColor: Colors.black87,
        actions: [if(!isPremium) IconButton(onPressed: payForPremium, icon: Icon(Icons.lock, color: Colors.yellow))],
      ),
      body: Column(
        children: [
          if(!isPremium) Container(
            color: Colors.yellow[700], padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: Text("Premium lo: 500rs / 30 Din", style: TextStyle(fontWeight: FontWeight.bold))),
                ElevatedButton(onPressed: payForPremium, child: Text("PAY $upiId"), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white))
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4), color: Colors.white),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
                      itemCount: 225,
                      itemBuilder: (c,i) {
                        bool isCenter = (i>=96 && i<=128);
                        return Container(margin: EdgeInsets.all(0.5), color: isCenter? colors[currentPlayer] : Colors.grey[200]);
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Text("Player: ${players[currentPlayer]}", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: rollDice,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: colors[currentPlayer], width: 4)),
                      child: Center(child: Text("$dice", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Dice Tap Karo", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}