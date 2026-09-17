import 'dart:math';
import 'package:flutter/material.dart';
void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, home: LudoOffline()));
class LudoOffline extends StatefulWidget {
  @override
  State<LudoOffline> createState() => _LudoOfflineState();
}
class _LudoOfflineState extends State<LudoOffline> {
  int dice = 1;
  int turn = 0;
  List<String> players = ["RED", "GREEN", "YELLOW", "BLUE"];
  List<Color> colors = [Colors.red, Colors.green, Colors.amber, Colors.blue];
  void roll() {
    setState(() {
      dice = Random().nextInt(6) + 1;
      turn = (turn + (dice == 6? 0 : 1)) % 4;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("LUDO PREMIUM 50", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber)),
            Text("Offline Mode - Working!", style: TextStyle(color: Colors.greenAccent)),
            SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(margin: EdgeInsets.all(6), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: turn==i? colors[i] : Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(players[i], style: TextStyle(fontWeight: FontWeight.bold, color: turn==i?Colors.black:Colors.white))))),
            SizedBox(height: 40),
            GestureDetector(onTap: roll, child: Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)), child: Center(child: Text("$dice", style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.black))))),
            SizedBox(height: 20),
            Text("Turn: ${players[turn]}", style: TextStyle(fontSize: 20, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}