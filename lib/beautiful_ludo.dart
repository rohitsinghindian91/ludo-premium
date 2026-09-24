import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

const String agoraAppId = "68178816ba6d47c6864cc5d584f3e2b8";
const String agoraToken = ""; // Token hata diya - bina token ke voice testing mode me chalega

const String rtdbUrl = "https://ludo-premium-50-e427e-default-rtdb.asia-southeast1.firebasedatabase.app";

FirebaseDatabase? _rtdbInstance;
FirebaseDatabase getRtdb() {
  _rtdbInstance??= FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: rtdbUrl,
  );
  _rtdbInstance!.goOnline();
  return _rtdbInstance!;
}

late SharedPreferences prefs;
bool isPrefsReady = false;
Future<void> ensurePrefs() async {
  if (!isPrefsReady) {
    prefs = await SharedPreferences.getInstance();
    isPrefsReady = true;
  }
}

enum GameMode { online, offline, bot }

class LobbyScreen extends StatefulWidget {
  @override State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final codeCtrl = TextEditingController();
  String genCode() => (Random().nextInt(9000) + 1000).toString();

  // ===== FINAL FIXED CREATE ROOM =====
  void _createRoomWithCodeDialog() async {
    String c = genCode();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room $c bana rahe hain...")));

    try {
      print("Creating room $c");
      await ensurePrefs();
      String? myName = prefs.getString("name");
      String? mobile = prefs.getString("mobile");
      await getRtdb().ref("$c/game").set({
        "pos": [[-1,-1,-1,-1], [-1,-1,-1,-1]],
        "turn": 0,
        "diceGreen": 1,
        "diceRed": 1,
        "canMove": false,
        "gameOver": false,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
        "roomId": c,
      }).timeout(Duration(seconds: 15));
      // FIX: players node banana zaroori hai - nahi to opponent kabhi connect nahi hoga
      await getRtdb().ref("$c/players/0").set({
        "name": myName?? "raju singh",
        "mobile": mobile?? "7831021211",
        "player": 0,
        "joinedAt": DateTime.now().millisecondsSinceEpoch,
      });

      print("Room $c created");

      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Room Ban Gaya!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Dost ko ye code bhejo:", style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 12),
          Container(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(c, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.black)),
              IconButton(icon: Icon(Icons.copy, color: Colors.black), onPressed: (){
                Clipboard.setData(ClipboardData(text: c));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Code copy: $c")));
              }),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: (){
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
          }, child: Text("GAME SHURU KARO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      ));
    } catch(e) {
      print("Set error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room nahi bana: $e"), duration: Duration(seconds: 5)));
    }
  }

  // ===== FINAL FIXED JOIN ROOM =====
  void joinRoom() async {
    String code = codeCtrl.text.trim();
    if(code.length!= 4){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("4 digit code dalo")));
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room $code dhoondh rahe hain...")));
      await ensurePrefs();
      var snap = await getRtdb().ref("$code/game").get().timeout(Duration(seconds: 15));
      if(!snap.exists){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room $code mila hi nahi")));
        return;
      }
      String? myName2 = prefs.getString("name");
      String? mobile2 = prefs.getString("mobile");
      await getRtdb().ref("$code/players/1").set({
        "name": myName2?? "janvi sharma",
        "mobile": mobile2?? "8930450501",
        "player": 1,
        "joinedAt": DateTime.now().millisecondsSinceEpoch,
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Join error: $e")));
      print("Join error full: $e");
      return;
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber),
      Text("LUDO PREMIUM", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amber)),
      SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.people), label: Text("OFFLINE - 1 PHONE 2 PLAYER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.smart_toy), label: Text("DOST KE SATH KHELO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickMatchScreen())))),
      SizedBox(height: 20), Divider(color: Colors.white24), SizedBox(height: 10),
      Text("ONLINE MODE", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)), SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _createRoomWithCodeDialog, child: Text("CREATE ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
      SizedBox(height: 10),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), decoration: InputDecoration(counterText: "", hintText: "CODE", hintStyle: TextStyle(color: Colors.white30), filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: joinRoom, child: Text("JOIN ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
    ]))));
  }
}

class QuickMatchScreen extends StatefulWidget {
  @override State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  int countdown = 10;
  String statusText = "Real user dhoondh rahe hain...";
  bool searching = true;
  bool botLaunched = false;
  DatabaseReference queueRef = getRtdb().ref("quick_match_queue");
  String myId = Random().nextInt(999999).toString();
  String? myRoomId;
  String? myQueueKey;
  Timer? _timer;

  @override void initState() { super.initState(); startQuickMatch(); }
  @override void dispose() { _timer?.cancel(); if(myQueueKey!= null) { try { queueRef.child(myQueueKey!).remove(); } catch(_){} } super.dispose(); }

  void launchBot() {
    if(botLaunched) return; botLaunched = true; _timer?.cancel(); searching = false;
    if(myQueueKey!= null) { try { queueRef.child(myQueueKey!).remove(); } catch(_){} }
    if(!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot)));
  }

  Future<void> startQuickMatch() async {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if(!mounted) { timer.cancel(); return; }
      if(countdown > 0) { setState((){ countdown--; }); } else { launchBot(); }
    });
    try {
      var snap = await queueRef.get();
      String? foundRoomId; String? foundKey;
      if(snap.exists){
        for(var child in snap.children){
          var data = Map<String,dynamic>.from(child.value as Map);
          if(data['status'] == 'waiting' && data['hostId']!= myId){
            int created = data['createdAt']?? 0;
            if(DateTime.now().millisecondsSinceEpoch - created < 30000){
              foundRoomId = data['roomId']; foundKey = child.key; break;
            }
          }
        }
      }
      if(foundRoomId!= null && foundKey!= null){
        if(!mounted || botLaunched) return;
        setState((){ statusText = "Real Dost mil gaya! Join ho rahe hain..."; });
        await queueRef.child(foundKey).update({"status": "matched", "guestId": myId});
        await Future.delayed(Duration(milliseconds: 500));
        if(!mounted || botLaunched) return;
        _timer?.cancel();
        botLaunched = true;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: foundRoomId!, myPlayer: 1, mode: GameMode.online)));
        return;
      }
      myRoomId = (Random().nextInt(9000)+1000).toString();
      myQueueKey = queueRef.push().key!;
      await queueRef.child(myQueueKey!).set({"roomId": myRoomId, "hostId": myId, "status": "waiting", "createdAt": DateTime.now().millisecondsSinceEpoch});
      queueRef.child(myQueueKey!).onValue.listen((event) async {
        if(event.snapshot.value!= null && mounted && searching &&!botLaunched){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          if(data['status'] == 'matched' && data['guestId']!= null){
            _timer?.cancel();
            botLaunched = true;
            setState((){ searching = false; statusText = "Real Dost mil gaya!"; });
            await Future.delayed(Duration(milliseconds: 500));
            if(!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: myRoomId!, myPlayer: 0, mode: GameMode.online)));
          }
        }
      });
    } catch(e){ debugPrint("Firebase slow: $e"); }
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Colors.orange, strokeWidth: 6),
      SizedBox(height: 30),
      Text(statusText, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
      SizedBox(height: 20),
      Text("$countdown", style: TextStyle(color: Colors.amber, fontSize: 72, fontWeight: FontWeight.w900)),
    ])));
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
  List<List<int>> pos = [[-1,-1,-1,-1], [-1,-1,-1,-1]];
  bool canMove = false, gameOver = false, isRolling = false, showChat = false, isMicOn = true, isSpeakerOn = true;
  List<Map> chatMessages = [];
  TextEditingController chatCtrl = TextEditingController();
  late AnimationController _diceController;
  String myName = "You", opponentName = "Opponent";
  RtcEngine? engine;
  DatabaseReference? gameRef, chatRef, playersRef;
  final safe = [0, 10, 20, 30];
  final startPos = [0, 20];

  bool get isMyTurn { if (widget.mode == GameMode.offline) return true; if (widget.mode == GameMode.bot) return turn == 0; return turn == widget.myPlayer; }

  @override void initState() {
    super.initState();
    _diceController = AnimationController(vsync: this, duration: Duration(milliseconds: 600));
    ensurePrefs().then((_) { setState(() { myName = prefs.getString("name")?? (widget.myPlayer==0?"raju singh":"janvi sharma"); }); });
    if (widget.mode == GameMode.online) initOnline();
  }

  Future<void> initOnline() async {
    await [Permission.microphone].request();
    try {
      engine = createAgoraRtcEngine();
      await engine!.initialize(RtcEngineContext(appId: agoraAppId));
      await engine!.enableAudio();
      await engine!.joinChannel(token: "", channelId: widget.roomId, uid: widget.myPlayer+1, options: ChannelMediaOptions(channelProfile: ChannelProfileType.channelProfileCommunication, clientRoleType: ClientRoleType.clientRoleBroadcaster));
    } catch(e){ debugPrint("Agora $e"); }

    gameRef = getRtdb().ref("${widget.roomId}/game");
    chatRef = getRtdb().ref("${widget.roomId}/chats");
    playersRef = getRtdb().ref("${widget.roomId}/players");

    gameRef!.onValue.listen((e) {
      if (e.snapshot.value==null ||!mounted) return;
      var d = Map<String,dynamic>.from(e.snapshot.value as Map);
      setState(() {
        turn = d['turn']??0;
        diceGreen = d['diceGreen']??1;
        diceRed = d['diceRed']??1;
        canMove = d['canMove']??false;
        gameOver = d['gameOver']??false;
        if (d['pos']!=null) {
          try {
            var raw = d['pos'] as List;
            pos = raw.map((e) => List<int>.from((e as List).map((x) => (x as int)))).toList() as List<List<int>>;
          } catch(_){}
        }
      });
    });

    playersRef!.onValue.listen((e) {
      if (e.snapshot.value!=null && mounted) {
        var all = Map<String,dynamic>.from(e.snapshot.value as Map);
        var other = all[(1-widget.myPlayer).toString()];
        if (other!=null) {
          var od = Map<String,dynamic>.from(other as Map);
          setState(() { opponentName = od['name']??"Opponent"; });
        }
      }
    });

    chatRef!.onChildAdded.listen((e) {
      if (e.snapshot.value!=null && mounted) {
        var d = Map<String,dynamic>.from(e.snapshot.value as Map);
        setState(() => chatMessages.add(d));
      }
    });
  }

  void sync() { if (widget.mode==GameMode.online) gameRef?.update({"pos": pos, "turn": turn, "diceGreen": diceGreen, "diceRed": diceRed, "canMove": canMove, "gameOver": gameOver}); }

  void rollDice() {
    if (!isMyTurn || canMove || gameOver || isRolling) return;
    setState(() => isRolling = true);
    _diceController.forward(from: 0);
    Future.delayed(Duration(milliseconds: 600), () {
      int d = _rng.nextInt(6)+1;
      setState(() {
        if (turn==0) diceGreen=d; else diceRed=d;
        canMove=true; isRolling=false;
        if (d==6) consecutiveSixes++; else consecutiveSixes=0;
      });
      if (consecutiveSixes>=3) { setState(() { canMove=false; turn=1-turn; consecutiveSixes=0; }); sync(); return; }
      bool anyMove=false;
      for(int i=0;i<4;i++){ if(pos[turn][i]==-1 && d==6) anyMove=true; if(pos[turn][i]>=0) anyMove=true; }
      if (!anyMove) { Future.delayed(Duration(milliseconds: 800), (){ setState((){ turn=1-turn; canMove=false; }); sync(); }); } else { sync(); }
    });
  }

  void moveGoti(int p, int idx) {
    if (!isMyTurn ||!canMove || p!=turn) return;
    if (pos[p][idx]==-1 && (p==0?diceGreen:diceRed)!=6) return;
    setState(() {
      if (pos[p][idx]==-1) pos[p][idx]=0; else pos[p][idx]+= (p==0?diceGreen:diceRed);
      // Cut logic
      for(int op=0;op<2;op++){ if(op==p) continue; for(int j=0;j<4;j++){ if(pos[op][j]>=0 && pos[op][j]==pos[p][idx] &&!safe.contains(pos[op][j]%40)) pos[op][j]=-1; } }
      if ((p==0?diceGreen:diceRed)!=6) { turn=1-turn; }
      canMove=false;
    });
    sync();
  }

  Future<void> sendMessage() async {
    if (chatCtrl.text.trim().isEmpty) return;
    String msg = chatCtrl.text.trim(); chatCtrl.clear();
    if (widget.mode==GameMode.online) {
      await chatRef!.push().set({"player": myName, "msg": msg, "time": DateTime.now().millisecondsSinceEpoch});
    } else {
      setState(() => chatMessages.add({"player": myName, "msg": msg}));
    }
  }

  void toggleMic() async { setState(()=> isMicOn=!isMicOn); await engine?.muteLocalAudioStream(!isMicOn); }
  void toggleSpeaker() async { setState(()=> isSpeakerOn=!isSpeakerOn); await engine?.setEnableSpeakerphone(isSpeakerOn); }

  Offset getBoardPos(int p, int idx, double s) {
    if (pos[p][idx]==-1) {
      double bx = p==0? 20 : s-60;
      double by = p==0? 20 : s-60;
      return Offset(bx + (idx%2)*30, by + (idx~/2)*30);
    }
    if (pos[p][idx]>=50) {
      return getHomePathPos(p, pos[p][idx]-50, s);
    }
    int step = pos[p][idx]%40;
    double angle = (step/40)*2*pi - pi/2;
    return Offset(s/2 + s*0.25*cos(angle) - 10, s/2 + s*0.25*sin(angle) - 10);
  }

  Offset getHomePathPos(int p, int j, double s) {
    double cx=s/2, cy=s/2;
    if(p==0) return Offset(cx-7, cy - 20 - j*16);
    return Offset(cx-7, cy + 10 + j*16);
  }

  Widget diceNearHome(int p, int val) {
    bool active = isMyTurn && turn==p &&!canMove &&!isRolling;
    return GestureDetector(
      onTap: active? rollDice : null,
      child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: active? Colors.yellow : (p==0? Colors.green : Colors.red), width: active? 3:2)), child: Center(child: Text("$val", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
    );
  }

  Widget goti(int p, int idx, double s) {
    Offset off = getBoardPos(p, idx, s);
    bool can = isMyTurn && canMove && p==turn && (pos[p][idx]==-1? (p==0?diceGreen:diceRed)==6 : true);
    return Positioned(left: off.dx, top: off.dy, child: GestureDetector(onTap: can? ()=> moveGoti(p, idx) : null, child: Container(width: can?28:20, height: can?28:20, decoration: BoxDecoration(color: p==0? Colors.green : Colors.red, shape: BoxShape.circle, border: Border.all(color: can? Colors.yellow : Colors.white, width: can?3:1.5)), child: Center(child: Text("${idx+1}", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))))));
  }

  @override void dispose() { _diceController.dispose(); engine?.leaveChannel(); engine?.release(); super.dispose(); }

  @override Widget build(BuildContext context) {
    double s = 360;
    double box = 80;
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Color(0xFF151A2B), title: Text("ROOM ${widget.roomId} - $myName vs $opponentName", style: TextStyle(fontSize: 11)), actions: [
        IconButton(icon: Icon(Icons.copy), onPressed: (){ Clipboard.setData(ClipboardData(text: widget.roomId)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Code ${widget.roomId} copy"))); }),
        IconButton(icon: Icon(showChat? Icons.close : Icons.chat), onPressed: ()=> setState(()=> showChat=!showChat)),
      ]),
      body: Column(children: [
        Container(margin: EdgeInsets.all(8), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: isMyTurn? Colors.green : Colors.white12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Turn: ${turn==0? (widget.myPlayer==0? myName : opponentName) : (widget.myPlayer==1? myName : opponentName)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(isMyTurn? "YOUR TURN - TAP DICE" : "WAIT - $opponentName", style: TextStyle(color: isMyTurn? Colors.greenAccent : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))
        ])),
        Expanded(child: Stack(children: [
          Center(child: Container(width: s, height: s, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber, width: 4)), child: Stack(children: [
            Positioned(left: s*0.23, top: s*0.23, width: s*0.54, height: s*0.54, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]), border: Border.all(color: Colors.white, width: 2)))),
            Positioned(left: 10, top: 10, width: box, height: box, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC8E6C9), Color(0xFFE8F5E9)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 3)))),
            Positioned(right: 10, bottom: 10, width: box, height: box, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFCDD2), Color(0xFFFFEBEE)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 3)))),
            Positioned(left: 8, top: box + 8, child: diceNearHome(0, diceGreen)),
            Positioned(right: 8, bottom: box + 8, child: diceNearHome(1, diceRed)),
            for (int i = 0; i < 40; i++) Positioned(left: s / 2 + s * 0.25 * cos((i / 40) * 2 * pi - pi / 2) - 7, top: s / 2 + s * 0.25 * sin((i / 40) * 2 * pi - pi / 2) - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: safe.contains(i)? Color(0xFFFFD700) : Colors.white, shape: BoxShape.circle, border: Border.all(color: safe.contains(i)? Colors.orange : Colors.black26, width: safe.contains(i)? 1.5 : 1)))),
            for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(0, j, s).dx - 7, top: getHomePathPos(0, j, s).dy - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green.shade200, shape: BoxShape.circle, border: Border.all(color: Colors.green.shade400)))),
            for (int j = 0; j < 5; j++) Positioned(left: getHomePathPos(1, j, s).dx - 7, top: getHomePathPos(1, j, s).dy - 7, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.red.shade200, shape: BoxShape.circle, border: Border.all(color: Colors.red.shade400)))),
            goti(0, 0, s), goti(0, 1, s), goti(0, 2, s), goti(0, 3, s), goti(1, 0, s), goti(1, 1, s), goti(1, 2, s), goti(1, 3, s)
          ]))),
          Positioned(top: 15, left: 0, right: 0, child: Center(child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(onTap: toggleMic, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: isMicOn? Colors.green : Colors.red, shape: BoxShape.circle), child: Icon(isMicOn? Icons.mic : Icons.mic_off, color: Colors.white, size: 18))),
            SizedBox(width: 10),
            GestureDetector(onTap: toggleSpeaker, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: isSpeakerOn? Colors.green : Colors.red, shape: BoxShape.circle), child: Icon(isSpeakerOn? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 18))),
            SizedBox(width: 10),
            Text(isMicOn? "Mic On" : "Mic Off", style: TextStyle(color: Colors.white, fontSize: 10)),
          ])))),
          if (showChat) Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 380, decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)), border: Border.all(color: Colors.amber.withOpacity(0.5))), child: Column(children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("CHAT - $myName vs $opponentName", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)), GestureDetector(onTap: ()=> setState(()=> showChat=false), child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: Icon(Icons.close, color: Colors.white, size: 16)))])),
            Expanded(child: ListView.builder(padding: EdgeInsets.all(10), itemCount: chatMessages.length, itemBuilder: (c, i) { var m = chatMessages[i]; bool isMe = m['player'] == myName; return Align(alignment: isMe? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical: 4), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7), decoration: BoxDecoration(color: isMe? Colors.green : Colors.white24, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: isMe? Radius.circular(12) : Radius.circular(0), bottomRight: isMe? Radius.circular(0) : Radius.circular(12))), child: Text("${m['player']}: ${m['msg']}", style: TextStyle(fontSize: 13, color: Colors.white)))); })),
            Divider(height: 1, color: Colors.white10),
            Container(padding: EdgeInsets.fromLTRB(10, 8, 10, MediaQuery.of(context).viewInsets.bottom + 10), color: Color(0xFF0A0E1A), child: Row(children: [
              Expanded(child: TextField(controller: chatCtrl, textInputAction: TextInputAction.send, onSubmitted: (_) => sendMessage(), style: TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: "Type message...", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF2A2A3E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14)))),
              SizedBox(width: 10),
              GestureDetector(onTap: sendMessage, child: Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: Icon(Icons.send, color: Colors.black, size: 22))),
            ])),
          ])))
        ])),
        Container(margin: EdgeInsets.fromLTRB(10, 5, 10, 10), padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(20), border: Border.all(color: turn==0? Colors.green : Colors.red, width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.casino, color: turn==0? Colors.green : Colors.red, size: 16), SizedBox(width: 6), Text("${turn == 0? myName : opponentName} KI BAARI ${isMyTurn? "(TAP DICE)" : ""}", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])),
      ]),
      floatingActionButton: showChat? null : FloatingActionButton.small(backgroundColor: Colors.amber, onPressed: () => setState(() => showChat =!showChat), child: Icon(Icons.chat, color: Colors.black, size: 20)),
    );
  }
}