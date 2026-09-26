import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rtdb.dart';

const String agoraAppId = "68178816ba6d47c6864cc5d584f3e2b8";
const String agoraToken = "";
late SharedPreferences ludoPrefs;
bool isPrefsReady = false;
Future<void> ensurePrefs() async {
  if (!isPrefsReady) {
    ludoPrefs = await SharedPreferences.getInstance();
    isPrefsReady = true;
    if (ludoPrefs.getString("name") == null) await ludoPrefs.setString("name", "Player${Random().nextInt(9000)}");
    if (ludoPrefs.getString("mobile") == null) await ludoPrefs.setString("mobile", "guest_${Random().nextInt(999999)}");
  }
}
enum GameMode { online, offline, bot }

class LobbyScreen extends StatefulWidget { @override State<LobbyScreen> createState() => _LobbyScreenState(); }
class _LobbyScreenState extends State<LobbyScreen> {
  final codeCtrl = TextEditingController();
  String genCode() => (Random().nextInt(9000) + 1000).toString();
  @override void initState() { super.initState(); ensurePrefs(); getRtdb().goOnline(); }
  void _createRoomWithCodeDialog() async {
    await ensurePrefs(); getRtdb().goOnline();
    String c = genCode();
    try {
      await getRtdb().ref("$c/game").set({"pos": [[-1,-1,-1,-1], [-1,-1,-1,-1]], "turn": 0, "diceGreen": 1, "diceRed": 1, "canMove": false, "gameOver": false, "createdAt": ServerValue.timestamp, "roomId": c});
      String? mobile = ludoPrefs.getString("mobile"); String? myName = ludoPrefs.getString("name");
      await getRtdb().ref("$c/players/p0").set({"mobile": mobile??"guest", "name": myName??"Player", "player": 0, "joinedAt": ServerValue.timestamp});
      Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
    } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error $e"))); }
  }
  void joinRoom() async {
    await ensurePrefs(); getRtdb().goOnline();
    String code = codeCtrl.text.trim();
    if(code.length!=4){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("4 digit code dalo"))); return; }
    var snap = await getRtdb().ref("$code/game").get();
    if(!snap.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room nahi mila"))); return; }
    String? mobile = ludoPrefs.getString("mobile"); String? myName = ludoPrefs.getString("name");
    await getRtdb().ref("$code/players/p1").set({"mobile": mobile??"guest", "name": myName??"Player", "player": 1, "joinedAt": ServerValue.timestamp});
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber), Text("LUDO PREMIUM - PLAN G DEBUG", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amber)), SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(Icons.people), label: Text("OFFLINE - 1 PHONE 2 PLAYER"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(Icons.smart_toy), label: Text("DOST KE SATH KHELO (BOT)"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickMatchScreen())))),
      SizedBox(height: 20), Divider(color: Colors.white24), SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _createRoomWithCodeDialog, child: Text("CREATE ROOM - ONLINE"))),
      SizedBox(height: 10),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), decoration: InputDecoration(counterText: "", hintText: "CODE", filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: joinRoom, child: Text("JOIN ROOM - ONLINE"))),
    ]))));
  }
}

class QuickMatchScreen extends StatefulWidget { @override State<QuickMatchScreen> createState() => _QuickMatchScreenState(); }
class _QuickMatchScreenState extends State<QuickMatchScreen> {
  int countdown = 10; bool botLaunched = false; Timer? _timer;
  @override void initState() { super.initState(); startQuickMatch(); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  void launchBot() { if(botLaunched) return; botLaunched = true; _timer?.cancel(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot))); }
  Future<void> startQuickMatch() async { _timer = Timer.periodic(Duration(seconds: 1), (t){ if(countdown>0) setState(()=> countdown--); else launchBot(); }); }
  @override Widget build(BuildContext context){ return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.orange), Text("$countdown", style: TextStyle(color: Colors.amber, fontSize: 72, fontWeight: FontWeight.w900))]))); }
}

class LudoGame extends StatefulWidget {
  final String roomId; final int myPlayer; final GameMode mode;
  const LudoGame({super.key, required this.roomId, required this.myPlayer, required this.mode});
  @override State<LudoGame> createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> with SingleTickerProviderStateMixin {
  final _rng = Random(); int diceGreen = 1, diceRed = 1, turn = 0, consecutiveSixes = 0; bool canMove = false, gameOver = false, isRolling = false, showChat = false; bool isMicOn = true, isSpeakerOn = true; bool isAgoraJoined = false; RtcEngine? agoraEngine;
  List<List<int>> pos = [[-1,-1,-1,-1], [-1,-1,-1,-1]]; List<Map<String, dynamic>> chatMessages = []; TextEditingController chatCtrl = TextEditingController();
  late AnimationController _diceController; final safe = [0, 10, 20, 30]; final startPos = [0, 20]; final homeEntry = [39, 19];
  DatabaseReference? roomRef; DatabaseReference? chatRef;
  String? myMobile; String myName = "You"; String opponentName = "Opponent"; String opponentMobile = "";
  final List<String> botNames = ["Jyoti","Simran","Kajal","Pinki","Sonia","Ritika","Anjali","Sweety","Pooja","Deepika"]; String selectedBotName = "Jyoti";
  @override void initState() { selectedBotName = botNames[_rng.nextInt(botNames.length)]; _diceController = AnimationController(vsync: this, duration: Duration(milliseconds: 800)); initAgoraAndRoom(); if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 800), () => botTurn()); }

  Future<void> initAgoraAndRoom() async {
    await ensurePrefs(); myMobile = ludoPrefs.getString("mobile"); myName = ludoPrefs.getString("name")?? "You";
    if(widget.mode == GameMode.online){
      getRtdb().goOnline(); await [Permission.microphone].request();
      agoraEngine = createAgoraRtcEngine(); await agoraEngine!.initialize(RtcEngineContext(appId: agoraAppId)); await agoraEngine!.enableAudio(); await agoraEngine!.setEnableSpeakerphone(true);
      agoraEngine!.registerEventHandler(RtcEngineEventHandler(onJoinChannelSuccess: (c,e){ setState(()=> isAgoraJoined = true); }));
      try { await agoraEngine!.joinChannel(token: agoraToken, channelId: widget.roomId, uid: widget.myPlayer==0?1:2, options: ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication, autoSubscribeAudio: true, publishMicrophoneTrack: true)); } catch(_){}
      roomRef = getRtdb().ref("${widget.roomId}/game"); chatRef = getRtdb().ref("${widget.roomId}/chats");
      roomRef!.keepSynced(true);
      getRtdb().ref("${widget.roomId}/players").keepSynced(true);

      Future<void> loadOpponent() async {
        try{
          var allSnap = await getRtdb().ref("${widget.roomId}/players").get();
          if(allSnap.exists && allSnap.value!= null){
            var map = allSnap.value as Map;
            map.forEach((k,v){
              if(v is Map){
                String name = v["name"]?.toString()?? "";
                if(name.isNotEmpty && k.toString()!= "p${widget.myPlayer}"){
                  if(mounted){
                    setState((){
                      opponentName = name;
                      opponentMobile = v["mobile"]?.toString()?? "";
                    });
                  }
                }
              }
            });
          }
        }catch(e){ debugPrint("loadOpp $e"); }
      }

      await loadOpponent();

      getRtdb().ref("${widget.roomId}/players").onValue.listen((e){
        if(e.snapshot.value == null) return;
        var map = e.snapshot.value as Map;
        map.forEach((k,v){
          if(v is Map){
            String name = v["name"]?.toString()?? "";
            if(name.isNotEmpty && k.toString()!= "p${widget.myPlayer}"){
              if(mounted){
                setState((){
                  opponentName = name;
                  opponentMobile = v["mobile"]?.toString()?? "";
                });
              }
            }
          }
        });
      });

      roomRef!.onValue.listen((event){
        if(event.snapshot.value!=null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          setState((){
            if(data['pos']!=null){ try { var raw = data['pos'] as List; pos = List<List<int>>.from(raw.map((e)=> List<int>.from((e as List).map((x)=> x as int)))); } catch(_){} }
            if(data['turn']!=null) turn = int.tryParse(data['turn'].toString())?? 0;
            if(data['diceGreen']!=null) diceGreen = int.tryParse(data['diceGreen'].toString())?? 1;
            if(data['diceRed']!=null) diceRed = int.tryParse(data['diceRed'].toString())?? 1;
            if(data['canMove']!=null){
              if(data['canMove'] is bool) canMove = data['canMove'] as bool;
              else canMove = data['canMove'].toString() == "true";
            }
            if(data['gameOver']!=null){
              if(data['gameOver'] is bool) gameOver = data['gameOver'] as bool;
              else gameOver = data['gameOver'].toString() == "true";
            }
          });
        }
      });
      chatRef!.onChildAdded.listen((event){
        if(event.snapshot.value!=null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          setState(()=> chatMessages.add({"player": data['player'], "msg": data['msg']}));
        }
      });
    } else { setState(()=> opponentName = selectedBotName); }
  }

  @override void dispose() { _diceController.dispose(); chatCtrl.dispose(); if(isAgoraJoined && agoraEngine!=null){ agoraEngine!.leaveChannel(); agoraEngine!.release(); } super.dispose(); }
  int get dice => turn == 0? diceGreen : diceRed;
  bool get isMyTurn { if (widget.mode == GameMode.offline) return true; if (widget.mode == GameMode.bot) return turn == 0; return turn == widget.myPlayer; }
  bool isValidMove(int p, int idx, int d) { int cur = pos[p][idx]; if (cur == 45) return false; if (cur == -1) return d == 6; if (cur >= 40) return cur + d <= 45; int dist = (homeEntry[p] - cur + 40) % 40; if (d == dist + 1) return true; if (d > dist + 1) return false; return true; }
  void sendMessage() async { if (chatCtrl.text.trim().isEmpty) return; String t = chatCtrl.text.trim(); chatCtrl.clear(); if(widget.mode == GameMode.online && chatRef!= null){ getRtdb().goOnline(); await chatRef!.push().set({"player": myName, "msg": t, "time": ServerValue.timestamp}); } else { setState(()=> chatMessages.add({"player": myName, "msg": t})); } }
  void toggleMic() async { setState(() => isMicOn =!isMicOn); if(agoraEngine!=null) await agoraEngine!.muteLocalAudioStream(!isMicOn); }
  void toggleSpeaker() async { setState(() => isSpeakerOn =!isSpeakerOn); if(agoraEngine!=null){ await agoraEngine!.setEnableSpeakerphone(isSpeakerOn); } }
  void syncRoom(){ if(widget.mode == GameMode.online && roomRef!= null){ getRtdb().goOnline(); roomRef!.update({"pos": pos, "turn": turn, "diceGreen": diceGreen, "diceRed": diceRed, "canMove": canMove, "gameOver": gameOver}); } }
  void roll() {
    if (gameOver || isRolling) return; if (widget.mode == GameMode.online &&!isMyTurn) return; if (canMove) return;
    setState(() => isRolling = true); _diceController.forward(from: 0);
    Future.delayed(Duration(milliseconds: 800), () {
      if (!mounted) return; int d = _rng.nextInt(6) + 1;
      if (d == 6) { consecutiveSixes++; if (consecutiveSixes == 3) { setState(() { if (turn == 0) diceGreen = d; else diceRed = d; turn = 1 - turn; canMove = false; consecutiveSixes = 0; isRolling = false; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); return; } } else consecutiveSixes = 0;
      setState(() { if (turn == 0) diceGreen = d; else diceRed = d; canMove = true; isRolling = false; }); syncRoom();
      bool any = false; for (int i = 0; i < 4; i++) if (isValidMove(turn, i, d)) { any = true; break; }
      if (!any) { Future.delayed(Duration(milliseconds: 800), () { if (!mounted || gameOver) return; setState(() { turn = 1 - turn; canMove = false; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); }); }
    });
  }
  void botTurn() { if (gameOver ||!mounted) return; if (turn!=1) return; rollBot(); }
  void rollBot() { setState(() => isRolling = true); _diceController.forward(from: 0); Future.delayed(Duration(milliseconds: 800), () { if (!mounted) return; int d = _rng.nextInt(6) + 1; setState(() { diceRed = d; canMove = true; isRolling = false; }); bool any = false; for (int i = 0; i < 4; i++) if (isValidMove(1, i, d)) { any = true; break; } if (!any) { Future.delayed(Duration(milliseconds: 500), () { setState(() { turn = 0; canMove = false; }); }); } else Future.delayed(Duration(milliseconds: 500), () => botMove()); }); }
  void botMove() { if (!canMove || gameOver) return; int bestIdx = -1; for (int i = 0; i < 4; i++) if (isValidMove(1, i, diceRed)) { bestIdx = i; break; } if (bestIdx!= -1) moveGoti(bestIdx); }
  void moveGoti(int idx) { if (!canMove || gameOver) return; if (widget.mode == GameMode.online &&!isMyTurn) return; if (!isValidMove(turn, idx, dice)) return; setState(() { int cur = pos[turn][idx]; int opp = 1 - turn; if (cur == -1) pos[turn][idx] = startPos[turn]; else if (cur < 40) { int dist = (homeEntry[turn] - cur + 40) % 40; if (dice == dist + 1) pos[turn][idx] = 40; else { int next = (cur + dice) % 40; if (!safe.contains(next)) { for (int k = 0; k < 4; k++) if (pos[opp][k] == next) pos[opp][k] = -1; } pos[turn][idx] = next; } } else pos[turn][idx] = cur + dice; if (pos[turn].every((v) => v == 45)) { gameOver = true; canMove = false; } else { if (dice!=6) turn = 1 - turn; canMove = false; } }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 600), () => botTurn()); }
  Offset getHomePathPos(int p, int step, double s) { double r = s * 0.25, cx = s / 2, cy = s / 2; int entry = homeEntry[p]; double ang = (entry / 40) * 2 * pi - pi / 2; double ex = cx + r * cos(ang), ey = cy + r * sin(ang); double t = (step + 1) / 6.0; return Offset(ex + (cx - ex) * t, ey + (cy - ey) * t); }
  Widget dot() => Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle));
  Widget emptyDot() => SizedBox(width: 10, height: 10);
  Widget buildDiceFace(int v) { Widget d = dot(), e = emptyDot(); List<Widget> r1 = [e, e, e], r2 = [e, e, e], r3 = [e, e, e]; if (v == 1) r2 = [e, d, e]; else if (v == 2) { r1 = [d, e, e]; r3 = [e, e, d]; } else if (v == 3) { r1 = [d, e, e]; r2 = [e, d, e]; r3 = [e, e, d]; } else if (v == 4) { r1 = [d, e, d]; r3 = [d, e, d]; } else if (v == 5) { r1 = [d, e, d]; r2 = [e, d, e]; r3 = [d, e, d]; } else if (v == 6) { r1 = [d, e, d]; r2 = [d, e, d]; r3 = [d, e, d]; } return Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Padding(padding: EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r1), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r2), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r3)]))); }
  Widget diceNearHome(int p, int val) { bool isTurn = turn == p &&!canMove &&!gameOver; bool canTap = isTurn &&!isRolling && isMyTurn; Color col = p == 0? Colors.green : Colors.red; bool rolling = isRolling && turn == p; return GestureDetector(onTap: canTap? roll : null, child: AnimatedBuilder(animation: _diceController, builder: (c, child) { double a = rolling? _diceController.value * 4 * pi : 0; return Transform.rotate(angle: a, child: child); }, child: Container(width: 85, height: 85, decoration: BoxDecoration(color: isTurn? col.withOpacity(0.20) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isTurn? col : Colors.black12, width: isTurn? 3 : 1.5)), child: Center(child: rolling? buildDiceFace(_rng.nextInt(6) + 1) : buildDiceFace(val))))); }
  Widget goti(int p, int t, double s) { int v = pos[p][t]; double boxSize = s * 0.14, pad = s * 0.02; Offset o; if (v == -1) { if (p == 0) { double bx = 10 + pad, by = 10 + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } else { double bx = s - 10 - boxSize + pad, by = s - 10 - boxSize + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } } else if (v == 45) { o = Offset(s / 2 + (t % 2 == 0? -8 : 8), s / 2 + (t < 2? -8 : 8)); } else if (v >= 40) { o = getHomePathPos(p, v - 40, s); } else { double r = s * 0.25, ang = (v / 40) * 2 * pi - pi / 2; o = Offset(s / 2 + r * cos(ang), s / 2 + r * sin(ang)); } bool act = p == turn && canMove && isValidMove(p, t, dice) &&!gameOver && isMyTurn; return Positioned(left: o.dx - 11, top: o.dy - 11, child: GestureDetector(onTap: act? () => moveGoti(t) : null, child: Container(width: act? 28 : 20, height: act? 28 : 20, decoration: BoxDecoration(color: p == 0? Colors.green : Colors.red, shape: BoxShape.circle, border: Border.all(color: act? Colors.yellow : Colors.white, width: act? 2.5 : 1.5))))); }
  @override Widget build(BuildContext context) {
    double s = (MediaQuery.of(context).size.width < 400? MediaQuery.of(context).size.width : 400) - 20; double box = s * 0.14;
    String turnName = (widget.mode == GameMode.online)? (turn == widget.myPlayer? myName : opponentName) : (turn == 0? myName : opponentName);
    return Scaffold(backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Color(0xFF151A2B), title: Text("R${widget.roomId} M${widget.myPlayer} T$turn - $myName vs $opponentName [${isMyTurn? "ME":"OPP"}]", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), actions: [IconButton(icon: Icon(Icons.person_add_alt_1, color: Colors.greenAccent), onPressed: () async { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$opponentName : $opponentMobile"))); }), IconButton(icon: Icon(showChat? Icons.close : Icons.chat, color: Colors.amber), onPressed: () => setState(() => showChat =!showChat))]),
      body: Column(children: [
        Container(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Turn: $turnName (T:$turn M:${widget.myPlayer})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)), Text(isMyTurn? "YOUR TURN" : "WAIT - $opponentName", style: TextStyle(fontSize: 11, color: isMyTurn? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold))])),
        Expanded(child: Stack(children: [
          Center(child: Container(width: s, height: s, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFF9C4), Color(0xFFE1F5FE), Color(0xFFFCE4EC)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amber, width: 4)), child: Stack(clipBehavior: Clip.none, children: [
            Positioned(left: s*0.23, top: s*0.23, width: s*0.54, height: s*0.54, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]), border: Border.all(color: Colors.white, width: 2)))),
            Positioned(left: 10, top: 10, width: box, height: box, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC8E6C9), Color(0xFFE8F5E9)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 3)))),
            Positioned(right: 10, bottom: 10, width: box, height: box, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFCDD2), Color(0xFFFFEBEE)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 3)))),
            Positioned(left: 8, top: box + 8, child: diceNearHome(0, diceGreen)),
            Positioned(right: 8, bottom: box + 8, child: diceNearHome(1, diceRed)),
            for (int i = 0; i < 40; i++) Positioned(left: s / 2 + s * 0.25 * cos((i / 40) * 2 * pi - pi / 2) - 7, top: s / 2 + s * 0.25 * sin((i / 40) * 2 * pi - pi / 2) - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: safe.contains(i)? Color(0xFFFFD700) : Colors.white, shape: BoxShape.circle, border: Border.all(color: safe.contains(i)? Colors.orange : Colors.black26)))),
            for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(0, j, s).dx - 8, top: getHomePathPos(0, j, s).dy - 8, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(1, j, s).dx - 8, top: getHomePathPos(1, j, s).dy - 8, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            goti(0, 0, s), goti(0, 1, s), goti(0, 2, s), goti(0, 3, s), goti(1, 0, s), goti(1, 1, s), goti(1, 2, s), goti(1, 3, s)
          ]))),
          Positioned(top: 15, left: 0, right: 0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(onTap: toggleMic, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: isMicOn? Colors.green : Colors.red, shape: BoxShape.circle), child: Icon(isMicOn? Icons.mic : Icons.mic_off, color: Colors.white, size: 18))),
            SizedBox(width: 10),
            GestureDetector(onTap: toggleSpeaker, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: isSpeakerOn? Colors.green : Colors.red, shape: BoxShape.circle), child: Icon(isSpeakerOn? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 18))),
          ])))),
          if (showChat) Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 380, decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)), border: Border.all(color: Colors.amber.withOpacity(0.5))), child: Column(children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("CHAT - $myName vs $opponentName", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)), GestureDetector(onTap: ()=> setState(()=> showChat=false), child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: Icon(Icons.close, color: Colors.white, size: 16)))])),
            Expanded(child: ListView.builder(padding: EdgeInsets.all(10), itemCount: chatMessages.length, itemBuilder: (c, i) { var m = chatMessages[i]; bool isMe = m['player'] == myName; return Align(alignment: isMe? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical: 4), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isMe? Colors.green : Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text("${m['player']}: ${m['msg']}", style: TextStyle(fontSize: 13, color: Colors.white)))); })),
            Container(padding: EdgeInsets.fromLTRB(10, 8, 10, MediaQuery.of(context).viewInsets.bottom + 10), color: Color(0xFF0A0E1A), child: Row(children: [
              Expanded(child: TextField(controller: chatCtrl, onSubmitted: (_) => sendMessage(), style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type message...", filled: true, fillColor: Color(0xFF2A2A3E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14)))),
              SizedBox(width: 10), GestureDetector(onTap: sendMessage, child: Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: Icon(Icons.send, color: Colors.black, size: 22))),
            ])),
          ])))
        ])),
        Container(margin: EdgeInsets.fromLTRB(10, 5, 10, 10), padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(20), border: Border.all(color: turn==widget.myPlayer? Colors.green : Colors.red, width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.casino, color: turn==widget.myPlayer? Colors.green : Colors.red, size: 16), SizedBox(width: 6), Text("${turnName} KI BAARI ${isMyTurn? "(TAP DICE)" : ""}", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])),
      ]),
      floatingActionButton: showChat? null : FloatingActionButton.small(backgroundColor: Colors.amber, onPressed: () => setState(() => showChat =!showChat), child: Icon(Icons.chat, color: Colors.black)),
    );
  }
}