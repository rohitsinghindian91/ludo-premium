import 'package:flutter/material.dart';
import 'dart:math';

class Ludo2Player extends StatefulWidget {
  @override State<Ludo2Player> createState() => _S();
}

class _S extends State<Ludo2Player> {
  int dice=1, turn=0, p1=0, p2=0;
  var r = Random();
  void roll(){ setState((){
    dice = r.nextInt(6)+1;
    if(turn==0) p1=(p1+dice)%100; else p2=(p2+dice)%100;
    turn = turn==0?1:0;
  });}
  @override
  Widget build(BuildContext c){
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF334155)])),
        child: SafeArea(child: Column(children: [
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Text("YOU", style: TextStyle(color: turn==0?Colors.amber:Colors.white, fontWeight: FontWeight.bold)),
            Text("VS", style: TextStyle(color: Colors.white24)),
            Text("FRIEND", style: TextStyle(color: turn==1?Colors.amber:Colors.white, fontWeight: FontWeight.bold)),
          ]),
          Expanded(child: Container(margin: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: GridView.builder(physics: NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10), itemCount: 100, itemBuilder: (_,i){
            Color bg = Colors.white;
            if(i<30 && i%10<3) bg=Colors.red.shade300;
            if(i<30 && i%10>=7) bg=Colors.blue.shade300;
            Widget d=SizedBox();
            if(i==p1) d=CircleAvatar(backgroundColor: Colors.red, radius: 10);
            if(i==p2) d=CircleAvatar(backgroundColor: Colors.blue, radius: 10);
            return Container(color: bg, child: Center(child: d));
          }))),
          Padding(padding: EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(turn==0?"YOUR TURN":"FRIEND TURN", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            InkWell(onTap: roll, child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Center(child: Text("$dice", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))))),
          ])),
        ])),
      ),
    );
  }
}