import 'package:flutter/material.dart';
import 'dart:math';

class Ludo2Player extends StatefulWidget {
  const Ludo2Player({super.key});
  @override
  State<Ludo2Player> createState() => _Ludo2PlayerState();
}

class _Ludo2PlayerState extends State<Ludo2Player> {
  int dice1 = 1, dice2 = 5;
  bool showTurn = true;
  final rnd = Random();

  void roll() {
    setState(() {
      dice1 = rnd.nextInt(6) + 1;
      dice2 = rnd.nextInt(6) + 1;
      showTurn = false;
      Future.delayed(Duration(milliseconds: 800), () {
        setState(() => showTurn = true);
      });
    });
  }

  Widget buildToken(Color c) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Icon(Icons.flight, size: 18, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7AB8FF), Color(0xFF4A3CFF)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar like screenshot
              Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
                CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.close, color: Colors.white)),
                SizedBox(width: 12),
                CircleAvatar(backgroundColor: Colors.white24, child: Text("?", style: TextStyle(color: Colors.white))),
                Spacer(),
                Image.asset('assets/ludo_logo.png', errorBuilder: (c,e,s)=> Text("LUDO", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellow))),
              ])),
              
              SizedBox(height: 10),
              // Board
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Color(0xFFE6E9F0), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white38, width: 4)),
                      child: GridView.count(
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 15,
                        children: List.generate(225, (i) {
                          Color bg = Colors.white;
                          if (i < 45 && i % 15 < 6) bg = Colors.red.shade400;
                          if (i < 45 && i % 15 >= 9) bg = Colors.green.shade400;
                          if (i >= 180 && i % 15 < 6) bg = Colors.blue.shade400;
                          if (i >= 180 && i % 15 >= 9) bg = Colors.yellow.shade600;
                          return Container(margin: EdgeInsets.all(1), color: bg);
                        }),
                      ),
                    ),
                    // Your Turn Popup - exactly like your screenshot 1
                    if (showTurn)
                      Center(
                        child: Container(
                          width: 280, height: 320,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black26)]),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(blurRadius: 5)]), child: Center(child: CircleAvatar(radius: 10, backgroundColor: Colors.red))),
                              SizedBox(width: 20),
                              Transform.rotate(angle: 0.3, child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Color(0xFFE0E8FF), borderRadius: BorderRadius.circular(12)), child: Center(child: Text("$dice2", style: TextStyle(fontSize: 30))))),
                            ]),
                            SizedBox(height: 40),
                            Text("Your turn", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              // Bottom dice like screenshot 1
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Center(child: CircleAvatar(radius: 6, backgroundColor: Colors.red))),
                    SizedBox(width: 8),
                    GestureDetector(onTap: roll, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Color(0xFFD0D9FF), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.casino))),
                  ]),
                  Icon(Icons.volume_up, color: Colors.white70),
                ]),
              )
            ],
          ),
        ),
      ),
      // Lobby screen like screenshot 2 - show before start
    );
  }
}

// Lobby widget like your 2nd screenshot
class LudoLobby extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7AB8FF), Color(0xFF4A3CFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(children: [
        SizedBox(height: 60),
        Text("LUDO", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.yellow)),
        SizedBox(height: 30),
        Container(margin: EdgeInsets.all(20), padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            CircleAvatar(radius: 35, backgroundImage: NetworkImage("https://i.pravatar.cc/150")),
            SizedBox(width: 20),
            Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.white38, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: Icon(Icons.add, size: 40, color: Colors.white)),
          ]),
        ),
        Container(margin: EdgeInsets.symmetric(horizontal: 20), padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)), child: Row(children: [Text("Fast", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), SizedBox(width: 10), Icon(Icons.casino, color: Colors.white)])),
        Spacer(),
        Row(children: [
          Expanded(child: Padding(padding: EdgeInsets.all(12), child: ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> Ludo2Player())); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE8A87C), minimumSize: Size(0,55), shape: StadiumBorder()), child: Text("Start", style: TextStyle(color: Colors.brown, fontSize: 22, fontWeight: FontWeight.bold))))),
          Expanded(child: Padding(padding: EdgeInsets.all(12), child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7AA8FF), minimumSize: Size(0,55), shape: StadiumBorder()), child: Text("Gathering", style: TextStyle(fontSize: 20))))),
        ]),
        SizedBox(height: 30),
      ]),
    );
  }
}