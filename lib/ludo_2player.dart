import 'package:flutter/material.dart';
import 'dart:math';

class Ludo2Player extends StatefulWidget {
  const Ludo2Player({super.key});
  @override State<Ludo2Player> createState() => _Ludo2PlayerState();
}

class _Ludo2PlayerState extends State<Ludo2Player> {
  int dice = 1;
  bool isGreenTurn = true;
  // 4 goti each player, -1 = ghar me
  List<int> green = [-1,-1,-1,-1];
  List<int> yellow = [-1,-1,-1,-1];
  Random r = Random();

  void roll(){
    setState(() {
      dice = r.nextInt(6)+1;
      // simple auto move logic
      List<int> current = isGreenTurn? green : yellow;
      int movableIndex = current.indexWhere((p) => p >= 0 || dice == 6);
      if(movableIndex!= -1){
        if(current[movableIndex] == -1 && dice == 6) current[movableIndex] = 0;
        else if(current[movableIndex] >= 0){
          current[movableIndex] += dice;
          if(current[movableIndex] > 57) current[movableIndex] = 57;
        }
      }
      // 6 aaya to same player ka turn, warna change
      if(dice!= 6) isGreenTurn =!isGreenTurn;
    });
  }

  Widget buildGoti(Color color, int pos){
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: pos==0?Colors.white:color, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
      child: pos>=0? Center(child: Text("${pos}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))) : Icon(Icons.home, size: 14),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(title: Text(isGreenTurn? "GREEN TURN 💚" : "YELLOW TURN 💛"), backgroundColor: isGreenTurn? Colors.green : Colors.amber, centerTitle: true),
      body: Column(
        children: [
          // Board
          Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber, width: 5)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Column(children: [Text("GREEN", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: green.map((p)=> Padding(padding: EdgeInsets.all(2), child: buildGoti(Colors.green, p))).toList())]),
                  Column(children: [Text("YELLOW", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: yellow.map((p)=> Padding(padding: EdgeInsets.all(2), child: buildGoti(Colors.amber, p))).toList())]),
                ]),
                SizedBox(height: 10),
                Container(height: 300, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10), border: Border.all()),
                  child: Center(child: Text("🎲 LUDO PATH \n Green: ${green} \n Yellow: ${yellow}", textAlign: TextAlign.center)),
                ),
              ],
            ),
          ),
          Spacer(),
          Text("$dice", style: TextStyle(fontSize: 70, color: Colors.white, fontWeight: FontWeight.bold)),
          ElevatedButton(onPressed: roll, style: ElevatedButton.styleFrom(backgroundColor: isGreenTurn?Colors.green:Colors.amber, minimumSize: Size(200, 55), shape: StadiumBorder()),
            child: Text("ROLL DICE", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}