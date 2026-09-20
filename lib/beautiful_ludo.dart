import 'package:flutter/material.dart';
import 'dart:math';

class BeautifulLudoGame extends StatefulWidget {
  const BeautifulLudoGame({super.key});
  @override State<BeautifulLudoGame> createState() => _BeautifulLudoGameState();
}

class _BeautifulLudoGameState extends State<BeautifulLudoGame> {
  int dice = 1;
  int turn = 0;
  bool canMove = false;
  bool isBotMode = true;
  List<List<int>> pos = [[-1, -1, -1, -1], [-1, -1, -1, -1]];

  void roll() {
    if (canMove) return;
    if (isBotMode && turn == 1) return;
    int d = Random().nextInt(6) + 1;
    setState(() { dice = d; canMove = true; });
    checkAnyMove(d);
  }

  void checkAnyMove(int d) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      bool any = false;
      for (int i = 0; i < 4; i++) {
        int c = pos[turn][i];
        if (c == -1 && d == 6) any = true;
        if (c >= 0 && c < 40) any = true;
        if (c >= 40 && c < 45 && d <= (45 - c)) any = true;
      }
      if (!any) {
        setState(() { turn = 1 - turn; canMove = false; });
        triggerBot();
      } else if (isBotMode && turn == 1) botMove();
    });
  }

  void botRoll() {
    if (!isBotMode || turn!= 1) return;
    int d = Random().nextInt(6) + 1;
    setState(() { dice = d; canMove = true; });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      bool any = false;
      for (int i = 0; i < 4; i++) {
        int c = pos[1][i];
        if (c == -1 && d == 6) any = true;
        if (c >= 0 && c < 40) any = true;
        if (c >= 40 && c < 45 && d <= (45 - c)) any = true;
      }
      if (!any) setState(() { turn = 0; canMove = false; }); else botMove();
    });
  }

  void botMove() {
    int bestIdx = -1;
    for (int i = 0; i < 4; i++) { int c = pos[1][i]; if (c >= 40 && c < 45 && dice == (45 - c)) { bestIdx = i; break; } }
    if (bestIdx == -1) { for (int i = 0; i < 4; i++) { int c = pos[1][i]; if (c >= 0 && c < 40) { int next = c + dice; if (next < 40 && pos[0].contains(next)) { bestIdx = i; break; } } } }
    if (bestIdx == -1 && dice == 6) { for (int i = 0; i < 4; i++) if (pos[1][i] == -1) { bestIdx = i; break; } }
    if (bestIdx == -1) { int maxPos = -2; for (int i = 0; i < 4; i++) { int c = pos[1][i]; if (c >= 0 && c > maxPos && c < 45) { maxPos = c; bestIdx = i; } } }
    if (bestIdx == -1) bestIdx = 0;
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) move(bestIdx); });
  }

  void triggerBot() { if (isBotMode && turn == 1) Future.delayed(const Duration(milliseconds: 800), () { if (mounted) botRoll(); }); }

  void move(int idx) {
    if (!canMove) return;
    int curr = pos[turn][idx];
    if (curr == -1 && dice!= 6) return;
    if (curr >= 40 && curr < 45 && dice > (45 - curr)) { setState(() { turn = 1 - turn; canMove = false; }); triggerBot(); return; }
    setState(() {
      if (curr == -1) pos[turn][idx] = turn == 0? 0 : 20;
      else if (curr < 40) {
        int next = curr + dice;
        if (next < 40) {
          for (int p = 0; p < 2; p++) for (int k = 0; k < 4; k++) if (!(p == turn && k == idx) && pos[p][k] == next) pos[p][k] = -1;
          pos[turn][idx] = next;
        } else pos[turn][idx] = 40 + (next - 40);
      } else {
        if (dice == (45 - curr)) {
          pos[turn][idx] = 45;
          if (pos[turn].every((e) => e == 45)) {
            showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(title: Text("${turn == 0? (isBotMode? "YOU" : "GREEN") : (isBotMode? "BOT" : "RED")} JEET GAYA! 🎉"), actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() { pos = [[-1, -1, -1, -1], [-1, -1, -1, -1]]; turn = 0; canMove = false; dice = 1; }); }, child: const Text("FIR SE KHELO"))]));
          }
        } else pos[turn][idx] = curr + dice;
      }
      if (dice!= 6) turn = 1 - turn;
      canMove = false;
    });
    triggerBot();
  }

  @override Widget build(BuildContext context) {
    double size = min(MediaQuery.of(context).size.width, 380) - 20;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black, title: Text(isBotMode? "4 GOTI - BOT MODE" : "4 GOTI - 1 VS 1", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)), actions: [const Text("BOT", style: TextStyle(color: Colors.white, fontSize: 9)), Switch(value: isBotMode, activeColor: Colors.amber, onChanged: (v) { setState(() { isBotMode = v; pos = [[-1, -1, -1, -1], [-1, -1, -1, -1]]; turn = 0; canMove = false; dice = 1; }); }), const SizedBox(width: 8)]),
      body: Column(children: [
        Expanded(child: Center(child: Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFFD700), width: 4)), child: Stack(children: [
          Positioned(left: 10, top: 10, width: size*0.32, height: size*0.32, child: Container(decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green, width: 2)))),
          Positioned(right: 10, top: 10, width: size*0.32, height: size*0.32, child: Container(decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red, width: 2)))),
          Positioned(left: size/2-30, top: size/2-30, width: 60, height: 60, child: Container(decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: const Icon(Icons.home, color: Colors.white))),
         ...List.generate(40, (i){ double r=size*0.36; double ang=(i/40)*2*pi-pi/2; Offset o=Offset(size/2+r*cos(ang), size/2+r*sin(ang)); return Positioned(left: o.dx-7, top: o.dy-7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: (i==0||i==20)?Colors.amber:Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12))));}),
         ...List.generate(2, (p)=>List.generate(4,(t){ int v=pos[p][t]; Offset off; if(v==-1){ double bx=p==0?size*0.08:size*0.68; double by=size*0.08; double dx=(t%2)*size*0.12; double dy=(t~/2)*size*0.12; off=Offset(bx+dx, by+dy); } else if(v==45) off=Offset(size/2,size/2); else if(v>=40) off=Offset(size/2-20+(v-40)*10, size/2); else{ double r=size*0.36; double ang=(v/40)*2*pi-pi/2; off=Offset(size/2+r*cos(ang), size/2+r*sin(ang));} bool act=p==turn&&canMove&&v!=45; if(v==-1&&dice!=6) act=false; if(v>=40&&v<45&&dice>(45-v)) act=false; if(isBotMode && p==1) act=false; return Positioned(left: off.dx-11, top: off.dy-11, child: GestureDetector(onTap: act?()=>move(t):null, child: Container(width: act?30:22, height: act?30:22, decoration: BoxDecoration(color: p==0?Colors.green:Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))));})).expand((e)=>e),
        ])))),
        Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(16)), child: Row(children: [GestureDetector(onTap: roll, child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Center(child: Text("$dice", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: (canMove || (isBotMode && turn==1))?null:roll, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 48)), child: Text(canMove?"GOTI PE TAP KARO":"ROLL DICE 🎲", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))])),
      ]),
    );
  }
}