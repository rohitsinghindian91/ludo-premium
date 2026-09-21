import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: LudoGame()));
}

enum GameMode { vsFriend, vsLaddi }

class LudoGame extends StatefulWidget {
  const LudoGame({super.key});
  @override
  State<LudoGame> createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> with SingleTickerProviderStateMixin {
  final _rng = Random();
  int diceGreen = 1;
  int diceRed = 1;
  int turn = 0;
  bool canMove = false;
  bool gameOver = false;
  List<List<int>> pos = [[-1,-1,-1,-1],[-1,-1,-1,-1]];
  int consecutiveSixes = 0;
  GameMode mode = GameMode.vsFriend;
  late AnimationController _diceController;
  bool isRolling = false;

  final safe = [0, 10, 20, 30];
  final startPos = [0, 20];
  final homeEntry = [39, 19];

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  int get dice => turn == 0? diceGreen : diceRed;
  bool get isLaddiTurn => mode == GameMode.vsLaddi && turn == 1 &&!gameOver;

  bool get isGameStarted {
    for (int p = 0; p < 2; p++) {
      for (int i = 0; i < 4; i++) {
        if (pos[p][i]!= -1) return true;
      }
    }
    return false;
  }

  bool isValidMove(int player, int idx, int d) {
    int cur = pos[player][idx];
    if (cur == 45) return false;
    if (cur == -1) return d == 6;
    if (cur >= 40) return cur + d <= 45;
    int distToHome = (homeEntry[player] - cur + 40) % 40;
    if (d == distToHome + 1) return true;
    if (d > distToHome + 1) return false;
    return true;
  }

  void _doChangeMode(GameMode newMode) {
    setState(() {
      mode = newMode;
      pos = List.generate(2, (_) => List.filled(4, -1));
      turn = 0;
      canMove = false;
      gameOver = false;
      diceGreen = 1;
      diceRed = 1;
      consecutiveSixes = 0;
    });
  }

  void changeMode(GameMode newMode) {
    if (mode == newMode) return;
    if (isGameStarted &&!gameOver) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text("Mode Change?", style: TextStyle(color: Colors.white)),
          content: const Text("Game chal raha hai. Mode badalne se pura game reset ho jayega. Pakka change karna hai?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Nahi")),
            TextButton(onPressed: () { Navigator.pop(context); _doChangeMode(newMode); }, child: Text("Haan Change Karo", style: TextStyle(color: newMode == GameMode.vsLaddi? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    } else {
      _doChangeMode(newMode);
    }
  }

  void roll() {
    if (canMove || gameOver || isRolling) return;
    if (isLaddiTurn) return;
    setState(() => isRolling = true);
    _diceController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      int d = _rng.nextInt(6) + 1;
      if (d == 6) {
        consecutiveSixes++;
        if (consecutiveSixes == 3) {
          setState(() {
            if (turn == 0) diceGreen = d; else diceRed = d;
            turn = 1 - turn;
            canMove = false;
            consecutiveSixes = 0;
            isRolling = false;
          });
          _checkLaddiTurn();
          return;
        }
      } else {
        consecutiveSixes = 0;
      }
      setState(() {
        if (turn == 0) diceGreen = d; else diceRed = d;
        canMove = true;
        isRolling = false;
      });
      bool any = false;
      for (int i = 0; i < 4; i++) {
        if (isValidMove(turn, i, d)) { any = true; break; }
      }
      if (!any) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted || gameOver) return;
          setState(() {
            turn = 1 - turn;
            canMove = false;
            if (d!= 6) consecutiveSixes = 0;
          });
          _checkLaddiTurn();
        });
      }
    });
  }

  void _checkLaddiTurn() {
    if (isLaddiTurn &&!canMove &&!gameOver) {
      setState(() => isRolling = true);
      _diceController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        int d = _rng.nextInt(6) + 1;
        if (d == 6) {
          consecutiveSixes++;
          if (consecutiveSixes == 3) {
            setState(() { diceRed = d; turn = 0; canMove = false; consecutiveSixes = 0; isRolling = false; });
            return;
          }
        } else consecutiveSixes = 0;
        setState(() { diceRed = d; canMove = true; isRolling = false; });
        bool any = false;
        for (int i = 0; i < 4; i++) if (isValidMove(turn, i, d)) any = true;
        if (!any) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            setState(() { turn = 0; canMove = false; });
          });
        } else {
          Future.delayed(const Duration(milliseconds: 500), () => laddiMove());
        }
      });
    }
  }

  void laddiMove() {
    if (!canMove ||!isLaddiTurn) return;
    int d = dice;
    List<int> valid = [];
    for (int i = 0; i < 4; i++) if (isValidMove(turn, i, d)) valid.add(i);
    if (valid.isEmpty) return;
    int bestIdx = valid[0];
    int bestScore = -100;
    for (int idx in valid) {
      int score = 0;
      int cur = pos[turn][idx];
      if (cur == -1) score = 90;
      else if (cur < 40) {
        int next = (cur + d) % 40;
        for (int k = 0; k < 4; k++) {
          if (pos[0][k] == next &&!safe.contains(next)) score = 100;
        }
        int distToHome = (homeEntry[turn] - cur + 40) % 40;
        if (d == distToHome + 1) score = 95;
        else score = cur;
      } else score = 80 + cur;
      if (score > bestScore) { bestScore = score; bestIdx = idx; }
    }
    moveGoti(bestIdx);
  }

  void moveGoti(int idx) {
    if (!canMove || gameOver) return;
    if (!isValidMove(turn, idx, dice)) return;
    bool gotCut = false;
    bool isWin = false;
    setState(() {
      int cur = pos[turn][idx];
      int opp = 1 - turn;
      if (cur == -1) pos[turn][idx] = startPos[turn];
      else if (cur < 40) {
        int distToHome = (homeEntry[turn] - cur + 40) % 40;
        if (dice == distToHome + 1) pos[turn][idx] = 40;
        else {
          int next = (cur + dice) % 40;
          if (!safe.contains(next)) {
            for (int k = 0; k < 4; k++) if (pos[opp][k] == next) { pos[opp][k] = -1; gotCut = true; }
          }
          pos[turn][idx] = next;
        }
      } else pos[turn][idx] = cur + dice;
      if (pos[turn].every((v) => v == 45)) {
        isWin = true; gameOver = true; canMove = false;
      } else {
        if (dice!= 6 &&!gotCut) { turn = 1 - turn; consecutiveSixes = 0; }
        canMove = false;
      }
    });
    if (isWin) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
          title: Text("${turn == 0? "GREEN" : 'laddi'} JEET GAYI! 🥳"),
          actions: [TextButton(onPressed: () { Navigator.pop(context); restartGame(); }, child: const Text("Restart"))]
        ));
      });
    } else {
      Future.delayed(const Duration(milliseconds: 400), () => _checkLaddiTurn());
    }
  }

  void restartGame() {
    setState(() {
      pos = List.generate(2, (_) => List.filled(4, -1));
      turn = 0; canMove = false; gameOver = false; diceGreen = 1; diceRed = 1; consecutiveSixes = 0;
    });
    _checkLaddiTurn();
  }

  Offset getHomePathPos(int player, int step, double s) {
    double r = s * 0.30; double cx = s / 2, cy = s / 2;
    int entry = homeEntry[player];
    double ang = (entry / 40) * 2 * pi - pi / 2;
    double ex = cx + r * cos(ang); double ey = cy + r * sin(ang);
    double t = (step + 1) / 6.0;
    return Offset(ex + (cx - ex) * t, ey + (cy - ey) * t);
  }

  Widget dot() => Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle));
  Widget emptyDot() => const SizedBox(width: 4, height: 4);
  Widget buildDiceFace(int value) {
    List<Widget> dots = []; Widget d = dot(); Widget e = emptyDot();
    if (value == 1) dots = [e,e,e, e,d,e, e,e,e];
    if (value == 2) dots = [d,e,e, e,e,e, e,e,d];
    if (value == 3) dots = [d,e,e, e,d,e, e,e,d];
    if (value == 4) dots = [d,e,d, e,e,e, d,e,d];
    if (value == 5) dots = [d,e,d, e,d,e, d,e,d];
    if (value == 6) dots = [d,e,d, d,e,d, d,e,d];
    return Container(width: 24, height: 24, decoration: BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(6),boxShadow:[const BoxShadow(color:Colors.black26,blurRadius:2)]), child: Padding(padding:const EdgeInsets.all(3.0),child:GridView.count(crossAxisCount:3, physics: const NeverScrollableScrollPhysics(), children:dots)));
  }

  Widget diceNearHome(int player,int value){
    bool isTurn = turn==player &&!canMove &&!gameOver;
    bool canTap = isTurn &&!isRolling && (mode==GameMode.vsFriend || (mode==GameMode.vsLaddi && player==0));
    Color col = player==0?Colors.green:Colors.red;
    bool thisDiceRolling = isRolling && turn == player;
    return GestureDetector(
      onTap: canTap? roll : null,
      child: AnimatedBuilder(
        animation: _diceController,
        builder: (context, child) {
          double angle = thisDiceRolling? _diceController.value * 4 * pi : 0;
          return Transform.rotate(angle: angle, child: child);
        },
        child: AnimatedContainer(duration: const Duration(milliseconds:200), width: 32, height: 32, decoration:BoxDecoration(color: isTurn?col.withOpacity(0.15):Colors.white, borderRadius:BorderRadius.circular(8), border:Border.all(color: isTurn?col:Colors.black12,width: isTurn?2:1)), child: Center(child: thisDiceRolling? buildDiceFace(_rng.nextInt(6)+1) : buildDiceFace(value))),
      )
    );
  }

  Widget goti(int p,int t,double s){
    int v=pos[p][t]; double boxSize=s*0.20; double pad=s*0.03; Offset o;
    if(v==-1){
      if(p==0){ double bx=10+pad; double by=10+pad; o=Offset(bx+(t%2)*(boxSize/2.5), by+(t~/2)*(boxSize/2.5)); }
      else{ double bx=s-10-boxSize+pad; double by=s-10-boxSize+pad; o=Offset(bx+(t%2)*(boxSize/2.5), by+(t~/2)*(boxSize/2.5)); }
    }else if(v==45){
      double offsetX = (t%2==0? -8 : 8).toDouble(); double offsetY = (t<2? -8 : 8).toDouble();
      o=Offset(s/2 + offsetX, s/2 + offsetY);
    } else if(v>=40){ o=getHomePathPos(p, v-40, s); }
    else{ double r=s*0.30; double ang=(v/40)*2*pi-pi/2; o=Offset(s/2+r*cos(ang), s/2+r*sin(ang)); }
    int samePosCount = 0;
    for(int k=0; k<t; k++){ if(pos[p][k] == v) samePosCount++; }
    if(v!= -1 && samePosCount > 0){ o = Offset(o.dx + (samePosCount * 6), o.dy + (samePosCount * 6)); }
    bool act=p==turn && canMove && isValidMove(p, t, dice) &&!gameOver;
    if(mode==GameMode.vsLaddi && p==1) act=false;
    return Positioned(left:o.dx-11,top:o.dy-11,child:GestureDetector(onTap: act? ()=>moveGoti(t) : null,child:Container(width: act?30:22,height: act?30:22,decoration:BoxDecoration(color: p==0?Colors.green:Colors.red,shape:BoxShape.circle,border:Border.all(color: act?Colors.yellow:Colors.white,width:2),boxShadow: act? [const BoxShadow(color:Colors.yellow,blurRadius:8)]:[]))));
  }

  @override
  Widget build(BuildContext context){
    double s=min(MediaQuery.of(context).size.width,380)-20;
    double box=s*0.20;
    return Scaffold(
      backgroundColor:const Color(0xFF0A0A0A),
      body:Column(children:[
        const SizedBox(height: 45),
        Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)), child: Row(children: [
          Expanded(child: GestureDetector(onTap: () => changeMode(GameMode.vsFriend), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: mode==GameMode.vsFriend?Colors.green:Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("1 VS 1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), if(mode==GameMode.vsFriend) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: Colors.white)),])))),
          const SizedBox(width: 4),
          Expanded(child: GestureDetector(onTap: () => changeMode(GameMode.vsLaddi), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: mode==GameMode.vsLaddi?Colors.red:Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Flexible(child: Text('VS laddi', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))), if(mode==GameMode.vsLaddi) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: Colors.white)),])))),
        ])),
        const SizedBox(height: 10),
        Expanded(child:Center(child:Container(width:s,height:s,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.amber,width:4)),child:Stack(children:[
          Positioned(left:10,top:10,width:box,height:box,child:Container(decoration:BoxDecoration(color:const Color(0xFFE8F5E9),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.green,width:2)))),
          Positioned(right:10,bottom:10,width:box,height:box,child:Container(decoration:BoxDecoration(color:const Color(0xFFFFEBEE),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.red,width:2)))),
          Positioned(left:10+box+12, top:10+box/2-30, child: diceNearHome(0,diceGreen)),
          Positioned(left:s-10-box-12-60, top:s-10-box/2-30, child: diceNearHome(1,diceRed)),
          for(int i=0;i<40;i++) Positioned(left:(s/2+s*0.30*cos((i/40)*2*pi-pi/2))-6, top:(s/2+s*0.30*sin((i/40)*2*pi-pi/2))-6, child:Container(width:12,height:12,decoration:BoxDecoration(color:safe.contains(i)?Colors.amber:Colors.white,shape:BoxShape.circle,border:Border.all(color:Colors.black12)))),
          for(int j=0;j<5;j++) Positioned(left: getHomePathPos(0, j, s).dx - 7, top: getHomePathPos(0, j, s).dy - 7, child: Container(width:14,height:14,decoration:BoxDecoration(color: Colors.green.shade200, shape:BoxShape.circle, border:Border.all(color:Colors.green, width:1.5)))),
          for(int j=0;j<5;j++) Positioned(left: getHomePathPos(1, j, s).dx - 7, top: getHomePathPos(1, j, s).dy - 7, child: Container(width:14,height:14,decoration:BoxDecoration(color: Colors.red.shade200, shape:BoxShape.circle, border:Border.all(color:Colors.red, width:1.5)))),
          Positioned(left:s/2-16, top:s/2-16, child: Container(width:32,height:32,decoration:BoxDecoration(color:Colors.amber, shape:BoxShape.circle, border:Border.all(color:Colors.black,width:2)), child:const Icon(Icons.star, size:16))),
          goti(0,0,s),goti(0,1,s),goti(0,2,s),goti(0,3,s),
          goti(1,0,s),goti(1,1,s),goti(1,2,s),goti(1,3,s),
        ])))),
        Container(margin:const EdgeInsets.all(14),padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),decoration:BoxDecoration(color:const Color(0xFF1E1E2E),borderRadius:BorderRadius.circular(16)),child:Text("${turn==0?"GREEN":'laddi'} KI BAARI - ${gameOver?"GAME OVER": isRolling? "GHUM RAHA HAI..." : canMove?"GOTI CHUNO":"PASSA FEKO"}",style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.bold))),
      ]),
    );
  }
}