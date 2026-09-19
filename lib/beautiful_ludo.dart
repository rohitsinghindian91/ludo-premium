import 'package:flutter/material.dart';
import 'dart:math';

class BeautifulLudoGame extends StatefulWidget {
  const BeautifulLudoGame({super.key});
  @override
  State<BeautifulLudoGame> createState() => _BeautifulLudoGameState();
}

class _BeautifulLudoGameState extends State<BeautifulLudoGame> {
  int dice = 1;
  int turn = 0;
  bool canMove = false;
  List<List<int>> pos = [[-1, -1], [-1, -1]];

  void roll() {
    if (canMove) return;
    int d = Random().nextInt(6) + 1;
    setState(() { dice = d; canMove = true; });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      bool any = false;
      for (int i = 0; i < 2; i++) {
        int c = pos[turn][i];
        if (c == -1 && d == 6) any = true;
        if (c >= 0 && c < 40) any = true;
        if (c >= 40 && c < 45 && d <= (45 - c)) any = true;
      }
      if (!any) {
        setState(() { turn = 1 - turn; canMove = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Move nahi, next turn"), backgroundColor: Colors.orange, duration: Duration(milliseconds: 700)));
      }
    });
  }

  void move(int idx) {
    if (!canMove) return;
    int curr = pos[turn][idx];
    if (curr == -1 && dice!= 6) return;
    if (curr >= 40 && curr < 45 && dice > (45 - curr)) {
      setState(() { turn = 1 - turn; canMove = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exact ${45 - curr} chahiye!"), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      if (curr == -1) pos[turn][idx] = turn == 0? 0 : 20;
      else if (curr < 40) {
        int next = curr + dice;
        if (next < 40) {
          for (int p = 0; p < 2; p++) for (int k = 0; k < 2; k++) if (!(p == turn && k == idx) && pos[p][k] == next) pos[p][k] = -1;
          pos[turn][idx] = next;
        } else pos[turn][idx] = 40 + (next - 40);
      } else {
        if (dice == (45 - curr)) {
          pos[turn][idx] = 45;
          if (pos[turn].every((e) => e == 45)) {
            showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: Text("${turn == 0? "YOU" : "RED"} JEET GAYA! 🎉", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() { pos = [[-1,-1],[-1,-1]]; turn=0; canMove=false; dice=1; }); }, child: const Text("FIR SE KHELO", style: TextStyle(color: Color(0xFFFFD700))))],
            ));
          }
        } else pos[turn][idx] = curr + dice;
      }
      if (dice!= 6) turn = 1 - turn;
      canMove = false;
    });
  }

  Widget _chip(String t, bool a, Color c) => AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: a? c : Colors.white12, borderRadius: BorderRadius.circular(20)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)));

  @override
  Widget build(BuildContext context) {
    double size = min(MediaQuery.of(context).size.width, 380) - 20;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), title: const Text("BEAUTIFUL LUDO - FINAL", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)), actions: [_chip("YOU", turn==0, Colors.green), const SizedBox(width: 6), _chip("RED", turn==1, Colors.red), const SizedBox(width: 10)]),
      body: Column(children: [
        Expanded(child: Center(child: Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFFD700), width: 4)), child: Stack(children: [
          Positioned(left: 10, top: 10, width: size*0.32, height: size*0.32, child: Container(decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green, width: 2)))),
          Positioned(right: 10, top: 10, width: size*0.32, height: size*0.32, child: Container(decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red, width: 2)))),
          Positioned(left: size/2-30, top: size/2-30, width: 60, height: 60, child: Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: const Icon(Icons.home, color: Colors.white))),
         ...List.generate(40, (i){ double r=size*0.36, ang=(i/40)*2*pi-pi/2; Offset o=Offset(size/2+r*cos(ang), size/2+r*sin(ang)); return Positioned(left: o.dx-7, top: o.dy-7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: (i==0||i==20)?Colors.amber:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12))));}),
         ...List.generate(2, (p)=>List.generate(2,(t){ int v=pos[p][t]; Offset off; if(v==-1) off=Offset(p==0?size*0.12:size*0.73, t==0?size*0.12:size*0.20); else if(v==45) off=Offset(size/2,size/2); else if(v>=40) off=Offset(size/2-15+(v-40)*8, size/2); else{ double r=size*0.36, ang=(v/40)*2*pi-pi/2; off=Offset(size/2+r*cos(ang), size/2+r*sin(ang));} bool act=p==turn&&canMove&&v!=45; if(v==-1&&dice!=6) act=false; if(v>=40&&v<45&&dice>(45-v)) act=false; return Positioned(left: off.dx-12, top: off.dy-12, child: GestureDetector(onTap: act?()=>move(t):null, child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: act?32:24, height: act?32:24, decoration: BoxDecoration(color: p==0?Colors.green:Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))));})).expand((e)=>e),
        ])))),
        Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(16)), child: Row(children: [GestureDetector(onTap: roll, child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Center(child: Text("$dice", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: canMove?null:roll, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 48)), child: Text(canMove?"GUTTI PE TAP KARO":"ROLL DICE 🎲", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))])),
      ]),
    );
  }
}