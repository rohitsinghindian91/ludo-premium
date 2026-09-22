import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String agoraAppId = "0772d1c90f7646a0a2d5649a41cf7632"; // Tera App ID

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: LobbyScreen()));
}
enum GameMode { online, offline, bot }

class LobbyScreen extends StatefulWidget {
  @override State<LobbyScreen> createState() => _LobbyScreenState();
}
class _LobbyScreenState extends State<LobbyScreen> {
  final codeCtrl = TextEditingController();
  String genCode() => (Random().nextInt(9000) + 1000).toString();
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0A0A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber),
      Text("LUDO PREMIUM", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amber)),
      Text("3 MODES - ONLINE | OFFLINE | NEW DOST", style: TextStyle(color: Colors.white54, fontSize: 10)),
      SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.people, color: Colors.white), label: Text("OFFLINE - 1 PHONE 2 PLAYER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.smart_toy, color: Colors.white), label: Text("NEW DOST KE SATH KHELO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot))))),
      SizedBox(height: 20), Divider(color: Colors.white24), SizedBox(height: 10),
      Text("ONLINE MODE", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)), SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { String c = genCode(); Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online))); }, child: Text("CREATE ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
      SizedBox(height: 10),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: "", hintText: "CODE", filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { if (codeCtrl.text.length == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: codeCtrl.text, myPlayer: 1, mode: GameMode.online))); }, child: Text("JOIN ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
    ]))));
  }
}

class LudoGame extends StatefulWidget {
  final String roomId; final int myPlayer; final GameMode mode;
  const LudoGame({super.key, required this.roomId, required this.myPlayer, required this.mode});
  @override State<LudoGame> createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> with SingleTickerProviderStateMixin {
  final _rng = Random();
  int diceGreen = 1, diceRed = 1, turn = 0, consecutiveSixes = 0;
  bool canMove = false, gameOver = false, isRolling = false, showChat = false;
  bool isMicOn = true, isSpeakerOn = true;
  bool isAgoraJoined = false;
  late RtcEngine agoraEngine;
  List<List<int>> pos = [[-1,-1,-1,-1], [-1,-1,-1,-1]];
  List<Map<String, String>> chatMessages = [];
  TextEditingController chatCtrl = TextEditingController();
  late AnimationController _diceController;
  final safe = [0, 10, 20, 30]; final startPos = [0, 20]; final homeEntry = [39, 19];
  DatabaseReference? roomRef;

  @override void initState() {
    super.initState();
    _diceController = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    initAgoraAndRoom();
    if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 800), () => botTurn());
  }

  Future<void> initAgoraAndRoom() async {
    if(widget.mode == GameMode.online){
      await [Permission.microphone].request();
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(RtcEngineContext(appId: agoraAppId));
      await agoraEngine.enableAudio();
      await agoraEngine.setEnableSpeakerphone(true);
      try {
        await agoraEngine.joinChannel(token: "", channelId: widget.roomId, uid: 0, options: ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication));
        setState(()=> isAgoraJoined = true);
      } catch(e){ debugPrint("Agora error $e"); }

      // Firebase sync for online
      roomRef = FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}");
      roomRef!.onValue.listen((event){
        if(event.snapshot.value!= null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          setState((){
            if(data['pos']!= null) pos = List<List<int>>.from((data['pos'] as List).map((e)=> List<int>.from(e)));
            if(data['turn']!= null) turn = data['turn'];
            if(data['diceGreen']!= null) diceGreen = data['diceGreen'];
            if(data['diceRed']!= null) diceRed = data['diceRed'];
          });
        }
      });
    }
  }

  @override void dispose() { _diceController.dispose(); chatCtrl.dispose(); if(isAgoraJoined){ agoraEngine.leaveChannel(); agoraEngine.release(); } super.dispose(); }
  int get dice => turn == 0? diceGreen : diceRed;
  bool get isMyTurn { if (widget.mode == GameMode.offline) return true; if (widget.mode == GameMode.bot) return turn == 0; return turn == widget.myPlayer; }
  bool isValidMove(int p, int idx, int d) { int cur = pos[p][idx]; if (cur == 45) return false; if (cur == -1) return d == 6; if (cur >= 40) return cur + d <= 45; int dist = (homeEntry[p] - cur + 40) % 40; if (d == dist + 1) return true; if (d > dist + 1) return false; return true; }
  void sendMessage() { if (chatCtrl.text.trim().isEmpty) return; String name = widget.mode == GameMode.online? (widget.myPlayer == 0? "GREEN" : "RED") : (turn == 0? "GREEN" : "RED"); setState(() { chatMessages.add({"player": name, "msg": chatCtrl.text.trim()}); }); chatCtrl.clear(); }

  void toggleMic() async {
    setState(() => isMicOn =!isMicOn);
    if(isAgoraJoined) await agoraEngine.muteLocalAudioStream(!isMicOn);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMicOn? "Mic On ✅" : "Mic Muted 🔇")));
  }
  void toggleSpeaker() async {
    setState(() => isSpeakerOn =!isSpeakerOn);
    if(isAgoraJoined) await agoraEngine.setEnableSpeakerphone(isSpeakerOn);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isSpeakerOn? "Speaker On 🔊" : "Speaker Off 🔈")));
  }

  void syncRoom(){ if(widget.mode == GameMode.online && roomRef!= null){ roomRef!.set({"pos": pos, "turn": turn, "diceGreen": diceGreen, "diceRed": diceRed}); } }

  void roll() {
    if (canMove || gameOver || isRolling ||!isMyTurn) return;
    if (widget.mode == GameMode.bot && turn == 1) return;
    setState(() => isRolling = true); _diceController.forward(from: 0);
    Future.delayed(Duration(milliseconds: 800), () {
      if (!mounted) return;
      int d = _rng.nextInt(6) + 1;
      if (d == 6) { consecutiveSixes++; if (consecutiveSixes == 3) { setState(() { if (turn == 0) diceGreen = d; else diceRed = d; turn = 1 - turn; canMove = false; consecutiveSixes = 0; isRolling = false; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); return; } } else consecutiveSixes = 0;
      setState(() { if (turn == 0) diceGreen = d; else diceRed = d; canMove = true; isRolling = false; });
      syncRoom();
      bool any = false; for (int i = 0; i < 4; i++) if (isValidMove(turn, i, d)) { any = true; break; }
      if (!any) { Future.delayed(Duration(milliseconds: 600), () { if (!mounted || gameOver) return; setState(() { turn = 1 - turn; canMove = false; if (d!= 6) consecutiveSixes = 0; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); }); }
    });
  }

  void botTurn() { if (gameOver ||!mounted) return; if (widget.mode!= GameMode.bot) return; if (turn!= 1) return; rollBot(); }
  void rollBot() {
    setState(() => isRolling = true); _diceController.forward(from: 0);
    Future.delayed(Duration(milliseconds: 800), () {
      if (!mounted) return; int d = _rng.nextInt(6) + 1;
      if (d == 6) { consecutiveSixes++; if (consecutiveSixes == 3) { setState(() { diceRed = d; turn = 0; canMove = false; consecutiveSixes = 0; isRolling = false; }); return; } } else consecutiveSixes = 0;
      setState(() { diceRed = d; canMove = true; isRolling = false; });
      bool any = false; for (int i = 0; i < 4; i++) if (isValidMove(1, i, d)) { any = true; break; }
      if (!any) { Future.delayed(Duration(milliseconds: 500), () { if (!mounted) return; setState(() { turn = 0; canMove = false; }); }); } else Future.delayed(Duration(milliseconds: 500), () => botMove());
    });
  }
  void botMove() {
    if (!canMove || gameOver) return; int bestIdx = -1;
    for (int i = 0; i < 4; i++) { if (!isValidMove(1, i, diceRed)) continue; int cur = pos[1][i]; if (cur == -1) { bestIdx = i; break; } if (cur < 40) { int next = (cur + diceRed) % 40; if (!safe.contains(next)) { for (int k = 0; k < 4; k++) if (pos[0][k] == next) { bestIdx = i; break; } } } if (bestIdx!= -1) break; }
    if (bestIdx == -1) { int maxPos = -2; for (int i = 0; i < 4; i++) { if (!isValidMove(1, i, diceRed)) continue; if (pos[1][i] > maxPos) { maxPos = pos[1][i]; bestIdx = i; } } }
    if (bestIdx!= -1) moveGoti(bestIdx);
  }

  void moveGoti(int idx) {
    if (!canMove || gameOver) return;
    if (widget.mode == GameMode.online &&!isMyTurn) return;
    if (!isValidMove(turn, idx, dice)) return;
    bool gotCut = false, isWin = false;
    setState(() {
      int cur = pos[turn][idx], opp = 1 - turn;
      if (cur == -1) pos[turn][idx] = startPos[turn];
      else if (cur < 40) { int dist = (homeEntry[turn] - cur + 40) % 40; if (dice == dist + 1) pos[turn][idx] = 40; else { int next = (cur + dice) % 40; if (!safe.contains(next)) { for (int k = 0; k < 4; k++) if (pos[opp][k] == next) { pos[opp][k] = -1; gotCut = true; } } pos[turn][idx] = next; } } else pos[turn][idx] = cur + dice;
      if (pos[turn].every((v) => v == 45)) { isWin = true; gameOver = true; canMove = false; } else { if (dice!= 6 &&!gotCut) { turn = 1 - turn; consecutiveSixes = 0; } canMove = false; }
    });
    syncRoom();
    if (isWin) { Future.delayed(Duration(milliseconds: 200), () { if (!mounted) return; showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(backgroundColor: Color(0xFF1E1E2E), title: Text("${turn == 0? "GREEN" : "RED"} JEET GAYA!", style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() { pos = List.generate(2, (_) => List.filled(4, -1)); turn = 0; canMove = false; gameOver = false; diceGreen = 1; diceRed = 1; consecutiveSixes = 0; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); }, child: Text("Restart"))])); }); } else { if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 600), () => botTurn()); }
  }

  Offset getHomePathPos(int p, int step, double s) { double r = s * 0.25, cx = s / 2, cy = s / 2; int entry = homeEntry[p]; double ang = (entry / 40) * 2 * pi - pi / 2; double ex = cx + r * cos(ang), ey = cy + r * sin(ang); double t = (step + 1) / 6.0; return Offset(ex + (cx - ex) * t, ey + (cy - ey) * t); }
  Widget dot() => Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle));
  Widget emptyDot() => SizedBox(width: 10, height: 10);
  Widget buildDiceFace(int v) { Widget d = dot(), e = emptyDot(); List<Widget> r1 = [e, e, e], r2 = [e, e, e], r3 = [e, e, e]; if (v == 1) r2 = [e, d, e]; else if (v == 2) { r1 = [d, e, e]; r3 = [e, e, d]; } else if (v == 3) { r1 = [d, e, e]; r2 = [e, d, e]; r3 = [e, e, d]; } else if (v == 4) { r1 = [d, e, d]; r3 = [d, e, d]; } else if (v == 5) { r1 = [d, e, d]; r2 = [e, d, e]; r3 = [d, e, d]; } else if (v == 6) { r1 = [d, e, d]; r2 = [d, e, d]; r3 = [d, e, d]; } return Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Padding(padding: EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r1), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r2), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r3)]))); }
  Widget diceNearHome(int p, int val) { bool isTurn = turn == p &&!canMove &&!gameOver; bool canTap = isTurn &&!isRolling && isMyTurn; if (widget.mode == GameMode.bot && p == 1) canTap = false; Color col = p == 0? Colors.green : Colors.red; bool rolling = isRolling && turn == p; return GestureDetector(onTap: canTap? roll : null, child: AnimatedBuilder(animation: _diceController, builder: (c, child) { double a = rolling? _diceController.value * 4 * pi : 0; return Transform.rotate(angle: a, child: child); }, child: AnimatedContainer(duration: Duration(milliseconds: 200), width: 85, height: 85, decoration: BoxDecoration(color: isTurn? col.withOpacity(0.20) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isTurn? col : Colors.black12, width: isTurn? 3 : 1.5)), child: Center(child: rolling? buildDiceFace(_rng.nextInt(6) + 1) : buildDiceFace(val))))); }
  Widget goti(int p, int t, double s) { int v = pos[p][t]; double boxSize = s * 0.14, pad = s * 0.02; Offset o; if (v == -1) { if (p == 0) { double bx = 10 + pad, by = 10 + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } else { double bx = s - 10 - boxSize + pad, by = s - 10 - boxSize + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } } else if (v == 45) { o = Offset(s / 2 + (t % 2 == 0? -8 : 8), s / 2 + (t < 2? -8 : 8)); } else if (v >= 40) { o = getHomePathPos(p, v - 40, s); } else { double r = s * 0.25, ang = (v / 40) * 2 * pi - pi / 2; o = Offset(s / 2 + r * cos(ang), s / 2 + r * sin(ang)); } bool act = p == turn && canMove && isValidMove(p, t, dice) &&!gameOver && isMyTurn; if (widget.mode == GameMode.offline) act = p == turn && canMove && isValidMove(p, t, dice) &&!gameOver; return Positioned(left: o.dx - 11, top: o.dy - 11, child: GestureDetector(onTap: act? () => moveGoti(t) : null, child: Container(width: act? 30 : 22, height: act? 30 : 22, decoration: BoxDecoration(color: p == 0? Colors.green : Colors.red, shape: BoxShape.circle, border: Border.all(color: act? Colors.yellow : Colors.white, width: 2))))); }
  String get modeText { if (widget.mode == GameMode.offline) return "OFFLINE"; if (widget.mode == GameMode.bot) return "ACTIVE USER"; return "ONLINE ${widget.roomId} ${isAgoraJoined? '🔊' : '🔇'}"; }

  @override Widget build(BuildContext context) {
    double s = (MediaQuery.of(context).size.width < 400? MediaQuery.of(context).size.width : 400) - 20; double box = s * 0.14;
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Color(0xFF1E1E2E), title: Text("$modeText", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), actions: [IconButton(icon: Icon(showChat? Icons.close : Icons.chat, color: Colors.amber, size: 18), onPressed: () => setState(() => showChat =!showChat))]),
      body: Column(children: [
        Container(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4), padding: EdgeInsets.all(6), decoration: BoxDecoration(color: Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Turn: ${turn == 0? 'GREEN' : 'RED'} ${widget.mode == GameMode.bot && turn == 1? "(ACTIVE USER)" : ""} ${widget.mode == GameMode.online && isAgoraJoined? "| VOICE ON" : ""}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(widget.mode == GameMode.offline? "TAP" : (isMyTurn? "YOUR TURN" : (widget.mode == GameMode.bot? "ACTIVE USER TURN" : "WAIT")), style: TextStyle(fontSize: 10))])),
        Expanded(child: Stack(children: [Center(child: Container(width: s, height: s, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amber, width: 4)), child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: s*0.23, top: s*0.23, width: s*0.54, height: s*0.54, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5F5F5), border: Border.all(color: Color(0xFFE0E0E0), width: 2)))),
          Positioned(left: s*0.27, top: s*0.27, width: s*0.46, height: s*0.46, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Color(0xFFEEEEEE), width: 1)))),
          Positioned(left: 10, top: 10, width: box, height: box, child: Container(decoration: BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green, width: 2)))),
          Positioned(right: 10, bottom: 10, width: box, height: box, child: Container(decoration: BoxDecoration(color: Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red, width: 2)))),
          Positioned(left: 8, top: box + 8, child: diceNearHome(0, diceGreen)),
          Positioned(right: 8, bottom: box + 8, child: diceNearHome(1, diceRed)),
          for (int i = 0; i < 40; i++) Positioned(left: s / 2 + s * 0.25 * cos((i / 40) * 2 * pi - pi / 2) - 7, top: s / 2 + s * 0.25 * sin((i / 40) * 2 * pi - pi / 2) - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: safe.contains(i)? Color(0xFFFFD700) : Colors.white, shape: BoxShape.circle, border: Border.all(color: safe.contains(i)? Colors.orange : Colors.black12, width: safe.contains(i)? 1.5 : 1)))),
          for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(0, j, s).dx - 7, top: getHomePathPos(0, j, s).dy - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green.shade200, shape: BoxShape.circle))),
          for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(1, j, s).dx - 7, top: getHomePathPos(1, j, s).dy - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.red.shade200, shape: BoxShape.circle))),
          Positioned(left: s / 2 - 16, top: s / 2 - 16, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: Icon(Icons.star, size: 16, color: Colors.black))),
          goti(0, 0, s), goti(0, 1, s), goti(0, 2, s), goti(0, 3, s), goti(1, 0, s), goti(1, 1, s), goti(1, 2, s), goti(1, 3, s)
        ]))), if (showChat) Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 160, color: Colors.black.withOpacity(0.9), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("CHAT - $modeText", style: TextStyle(color: Colors.amber, fontSize: 10)), IconButton(icon: Icon(Icons.close, size: 14), onPressed: () => setState(() => showChat = false))]), Expanded(child: ListView.builder(padding: EdgeInsets.all(6), itemCount: chatMessages.length, itemBuilder: (c, i) { var m = chatMessages[i]; return Container(margin: EdgeInsets.symmetric(vertical: 1), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: m['player'] == 'GREEN'? Colors.green : Colors.red, borderRadius: BorderRadius.circular(8)), child: Text("${m['player']}: ${m['msg']}", style: TextStyle(fontSize: 10, color: Colors.white))); })), Row(children: [Expanded(child: TextField(controller: chatCtrl, onSubmitted: (_) => sendMessage(), decoration: InputDecoration(hintText: "Type...", border: InputBorder.none))), IconButton(icon: Icon(Icons.send, color: Colors.amber), onPressed: sendMessage)])])))])),
        Container(margin: EdgeInsets.all(6), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(10)), child: Text("${turn == 0? "GREEN" : "RED"} KI BAARI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.mode!= GameMode.offline)
            FloatingActionButton.small(heroTag: "mic", backgroundColor: isMicOn? Colors.green : Colors.red, onPressed: toggleMic, child: Icon(isMicOn? Icons.mic : Icons.mic_off, color: Colors.white, size: 18)),
          SizedBox(height: 5),
          if (widget.mode!= GameMode.offline)
            FloatingActionButton.small(heroTag: "speaker", backgroundColor: isSpeakerOn? Colors.green : Colors.red, onPressed: toggleSpeaker, child: Icon(isSpeakerOn? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 18)),
          SizedBox(height: 5),
          FloatingActionButton.small(heroTag: "chat", backgroundColor: Colors.amber, onPressed: () => setState(() => showChat =!showChat), child: Icon(Icons.chat, color: Colors.black, size: 18)),
        ],
      ),
    );
  }
}