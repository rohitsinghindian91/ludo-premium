import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

const String agoraAppId = "0772d1c90f7646a0a2d5649a41cf7632";

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

  void _createRoomWithCodeDialog() {
    String c = genCode();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text("Room Ban Gaya!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Dost ko ye code bhejo:", style: TextStyle(color: Colors.white70, fontSize: 13)),
        SizedBox(height: 12),
        Container(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(c, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 12, color: Colors.black)),
            IconButton(icon: Icon(Icons.copy, color: Colors.black), onPressed: (){
              Clipboard.setData(ClipboardData(text: c));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Code copy ho gaya: $c")));
            })
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: Text("Band karo")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: (){
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
        }, child: Text("GAME SHURU KARO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
      ],
    ));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber),
      Text("LUDO PREMIUM", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amber)),
      Text("OFFLINE | BOT | ONLINE VOICE + CHAT", style: TextStyle(color: Colors.white54, fontSize: 10)),
      SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.people), label: Text("OFFLINE - 1 PHONE 2 PLAYER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: Icon(Icons.smart_toy), label: Text("DOST KE SATH KHELO (10s me Real User)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickMatchScreen())))),
      SizedBox(height: 20), Divider(color: Colors.white24), SizedBox(height: 10),
      Text("ONLINE MODE", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)), SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _createRoomWithCodeDialog, child: Text("CREATE ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
      SizedBox(height: 10),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), decoration: InputDecoration(counterText: "", hintText: "CODE", hintStyle: TextStyle(color: Colors.white30), filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { if (codeCtrl.text.length == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: codeCtrl.text, myPlayer: 1, mode: GameMode.online))); }, child: Text("JOIN ROOM - ONLINE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
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
  DatabaseReference queueRef = FirebaseDatabase.instance.ref("quick_match_queue");
  String myId = Random().nextInt(999999).toString();
  String? myRoomId;
  String? myQueueKey;
  Timer? _timer;

  @override void initState() {
    super.initState();
    startQuickMatch();
  }

  @override void dispose() {
    _timer?.cancel();
    if(myQueueKey!= null) {
      try { queueRef.child(myQueueKey!).remove(); } catch(_){}
    }
    super.dispose();
  }

  void launchBot() {
    if(botLaunched) return;
    botLaunched = true;
    _timer?.cancel();
    searching = false;
    if(myQueueKey!= null) {
      try { queueRef.child(myQueueKey!).remove(); } catch(_){}
    }
    if(!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot)));
  }

  Future<void> startQuickMatch() async {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if(!mounted) { timer.cancel(); return; }
      if(countdown > 0) {
        setState((){ countdown--; });
      } else {
        launchBot();
      }
    });

    try {
      var snap = await queueRef.get().timeout(Duration(seconds: 3));
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
      await queueRef.child(myQueueKey!).set({
        "roomId": myRoomId,
        "hostId": myId,
        "status": "waiting",
        "createdAt": DateTime.now().millisecondsSinceEpoch
      }).timeout(Duration(seconds: 3));

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

    } catch(e){
      debugPrint("Firebase slow: $e");
    }
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
  bool canMove = false, gameOver = false, isRolling = false, showChat = false;
  bool isMicOn = true, isSpeakerOn = true;
  bool isAgoraJoined = false;
  RtcEngine? agoraEngine;
  List<List<int>> pos = [[-1,-1,-1,-1], [-1,-1,-1,-1]];
  List<Map<String, dynamic>> chatMessages = [];
  TextEditingController chatCtrl = TextEditingController();
  late AnimationController _diceController;
  final safe = [0, 10, 20, 30]; final startPos = [0, 20]; final homeEntry = [39, 19];
  DatabaseReference? roomRef; DatabaseReference? chatRef;
  String? myMobile; String myName = "You"; String opponentName = "Opponent"; String opponentMobile = "";
  final List<String> botNames = ["Jyoti", "Simran", "Kajal", "Saneha", "Aarzoo", "Pinki", "Shalu", "Rabina", "Payal", "Minaxi","Preet kaur", "Cutie", "Sonia", "Monika", "Ritika", "Suman", "Pooja", "Deepika", "Anjali", "Sweety"];
  String selectedBotName = "Jyoti";

  @override void initState() {
    super.initState();
    selectedBotName = botNames[_rng.nextInt(botNames.length)];
    _diceController = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    initAgoraAndRoom();
    if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 800), () => botTurn());
  }

  Future<void> initAgoraAndRoom() async {
    var sp = await SharedPreferences.getInstance();
    myMobile = sp.getString("mobile");
    if(myMobile!= null){
      try { var doc = await FirebaseFirestore.instance.collection("users").doc(myMobile).get(); myName = doc.data()?["name"]?? "You"; if(mounted) setState((){}); } catch(e){}
    }
    if(widget.mode == GameMode.online){
      await [Permission.microphone].request();
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine!.initialize(RtcEngineContext(appId: agoraAppId));
      await agoraEngine!.enableAudio();
      await agoraEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await agoraEngine!.setEnableSpeakerphone(true);
      int myUid = widget.myPlayer + 1;
      try {
        await agoraEngine!.joinChannel(token: "", channelId: widget.roomId, uid: myUid, options: ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication));
        setState(()=> isAgoraJoined = true);
      } catch(e){ debugPrint("Agora error $e"); }
      roomRef = FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}/game");
      chatRef = FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}/chats");
      var playersRef = FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}/players/${widget.myPlayer}");
      if(myMobile!= null) await playersRef.set({"mobile": myMobile, "name": myName, "player": widget.myPlayer, "joinedAt": DateTime.now().millisecondsSinceEpoch});
      else await playersRef.set({"mobile": "guest_${myId}", "name": myName, "player": widget.myPlayer, "joinedAt": DateTime.now().millisecondsSinceEpoch});
      FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}/players/${1 - widget.myPlayer}").onValue.listen((event) async {
        if(event.snapshot.value!= null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          String? oppMob = data["mobile"]?.toString();
          String? oppName = data["name"]?.toString();
          if(oppMob!= null) opponentMobile = oppMob;
          if(oppName!= null && oppName.isNotEmpty) setState(()=> opponentName = oppName);
          else if(oppMob!= null &&!oppMob.startsWith("guest")){ try { var uDoc = await FirebaseFirestore.instance.collection("users").doc(oppMob).get(); if(uDoc.exists && mounted) setState(()=> opponentName = uDoc.data()?["name"]?? "Real User"); } catch(e){} }
          else setState(()=> opponentName = "Real User");
        }
      });
      roomRef!.onValue.listen((event){
        if(event.snapshot.value!= null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          setState((){
            if(data['pos']!= null) { try { var raw = data['pos'] as List; pos = List<List<int>>.from(raw.map((e)=> List<int>.from((e as List).map((x)=> x as int)))); } catch(_){} }
            if(data['turn']!= null) turn = data['turn'] as int;
            if(data['diceGreen']!= null) diceGreen = data['diceGreen'] as int;
            if(data['diceRed']!= null) diceRed = data['diceRed'] as int;
            if(data['canMove']!= null) canMove = data['canMove'] as bool;
            if(data['gameOver']!= null) gameOver = data['gameOver'] as bool;
          });
        }
      });
      chatRef!.onChildAdded.listen((event){
        if(event.snapshot.value!= null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          String player = data['player']?? "UNK"; String msg = data['msg']?? "";
          setState((){ chatMessages.add({"player": player, "msg": msg, "time": data['time']}); });
        }
      });
      if(widget.myPlayer == 0) roomRef!.get().then((snap){ if(!snap.exists){ syncRoom(); } });
    } else { setState(()=> opponentName = selectedBotName); }
  }

  String get myId => Random().nextInt(999999).toString();
  Future<void> addFriendFromGame() async {
    if(widget.mode == GameMode.bot){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$selectedBotName BOT hai, add nahi hogi 😅"))); return; }
    if(widget.mode == GameMode.offline){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OFFLINE me add nahi hota"))); return; }
    if(opponentMobile.isEmpty || opponentMobile.startsWith("guest")){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opponent abhi connect nahi hua"))); return; }
    await sendFriendRequest(opponentMobile, opponentName);
  }
  Future<void> sendFriendRequest(String toMobile, String toName) async {
    if(myMobile==null){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login karo pehle"))); return; }
    var doc = await FirebaseFirestore.instance.collection("users").doc(toMobile).get();
    if(!doc.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$toName nahi mila"))); return; }
    var q = await FirebaseFirestore.instance.collection("friend_requests").where("from", isEqualTo: myMobile).where("to", isEqualTo: toMobile).where("status", isEqualTo: "pending").get();
    if(q.docs.isNotEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$toName ko pehle se bhej rakhi hai"))); return; }
    var fr = await FirebaseFirestore.instance.collection("users").doc(myMobile!).collection("friends").doc(toMobile).get();
    if(fr.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$toName pehle se friend hai"))); return; }
    await FirebaseFirestore.instance.collection("friend_requests").add({"from": myMobile, "to": toMobile, "fromName": myName, "toName": toName, "status": "pending", "time": FieldValue.serverTimestamp(), "fromGame": widget.roomId});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$toName ko friend request bhej di")));
  }

  @override void dispose() { _diceController.dispose(); chatCtrl.dispose(); if(isAgoraJoined && agoraEngine!=null){ agoraEngine!.leaveChannel(); agoraEngine!.release(); } super.dispose(); }
  int get dice => turn == 0? diceGreen : diceRed;
  bool get isMyTurn { if (widget.mode == GameMode.offline) return true; if (widget.mode == GameMode.bot) return turn == 0; return turn == widget.myPlayer; }
  bool isValidMove(int p, int idx, int d) { int cur = pos[p][idx]; if (cur == 45) return false; if (cur == -1) return d == 6; if (cur >= 40) return cur + d <= 45; int dist = (homeEntry[p] - cur + 40) % 40; if (d == dist + 1) return true; if (d > dist + 1) return false; return true; }

  void sendMessage() {
    if (chatCtrl.text.trim().isEmpty) return;
    String name = myName; String text = chatCtrl.text.trim(); chatCtrl.clear();
    if(widget.mode == GameMode.online && chatRef!= null) chatRef!.push().set({"player": name, "msg": text, "time": DateTime.now().millisecondsSinceEpoch});
    else setState(() { chatMessages.add({"player": name, "msg": text, "time": DateTime.now().millisecondsSinceEpoch}); });
  }
  void toggleMic() async { setState(() => isMicOn =!isMicOn); if(isAgoraJoined && agoraEngine!=null) await agoraEngine!.muteLocalAudioStream(!isMicOn); }
  void toggleSpeaker() async { setState(() => isSpeakerOn =!isSpeakerOn); if(isAgoraJoined && agoraEngine!=null) await agoraEngine!.setEnableSpeakerphone(isSpeakerOn); }
  void syncRoom(){ if(widget.mode == GameMode.online && roomRef!= null){ roomRef!.set({"pos": pos, "turn": turn, "diceGreen": diceGreen, "diceRed": diceRed, "canMove": canMove, "gameOver": gameOver}); } }

  void roll() {
    if (canMove || gameOver || isRolling ||!isMyTurn) return;
    if (widget.mode == GameMode.bot && turn == 1) return;
    setState(() => isRolling = true); _diceController.forward(from: 0);
    Future.delayed(Duration(milliseconds: 800), () {
      if (!mounted) return; int d = _rng.nextInt(6) + 1;
      if (d == 6) { consecutiveSixes++; if (consecutiveSixes == 3) { setState(() { if (turn == 0) diceGreen = d; else diceRed = d; turn = 1 - turn; canMove = false; consecutiveSixes = 0; isRolling = false; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); return; } } else consecutiveSixes = 0;
      setState(() { if (turn == 0) diceGreen = d; else diceRed = d; canMove = true; isRolling = false; }); syncRoom();
      bool any = false; for (int i = 0; i < 4; i++) if (isValidMove(turn, i, d)) { any = true; break; }
      if (!any) { Future.delayed(Duration(milliseconds: 800), () { if (!mounted || gameOver) return; setState(() { turn = 1 - turn; canMove = false; if (d!= 6) consecutiveSixes = 0; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); }); }
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
    if (!canMove || gameOver) return; if (widget.mode == GameMode.online &&!isMyTurn) return; if (!isValidMove(turn, idx, dice)) return;
    bool gotCut = false, isWin = false;
    setState(() {
      int cur = pos[turn][idx], opp = 1 - turn;
      if (cur == -1) pos[turn][idx] = startPos[turn];
      else if (cur < 40) { int dist = (homeEntry[turn] - cur + 40) % 40; if (dice == dist + 1) pos[turn][idx] = 40; else { int next = (cur + dice) % 40; if (!safe.contains(next)) { for (int k = 0; k < 4; k++) if (pos[opp][k] == next) { pos[opp][k] = -1; gotCut = true; } } pos[turn][idx] = next; } } else pos[turn][idx] = cur + dice;
      if (pos[turn].every((v) => v == 45)) { isWin = true; gameOver = true; canMove = false; } else { if (dice!= 6 &&!gotCut) { turn = 1 - turn; consecutiveSixes = 0; } canMove = false; }
    });
    syncRoom();
    if (isWin) { Future.delayed(Duration(milliseconds: 200), () { if (!mounted) return; showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(backgroundColor: Color(0xFF1E1E2E), title: Text("${turn == 0? myName : opponentName} JEET GAYA!", style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() { pos = List.generate(2, (_) => List.filled(4, -1)); turn = 0; canMove = false; gameOver = false; diceGreen = 1; diceRed = 1; consecutiveSixes = 0; selectedBotName = botNames[_rng.nextInt(botNames.length)]; if(widget.mode==GameMode.bot) opponentName = selectedBotName; }); syncRoom(); if (widget.mode == GameMode.bot && turn == 1) botTurn(); }, child: Text("Restart"))])); }); } else { if (widget.mode == GameMode.bot && turn == 1) Future.delayed(Duration(milliseconds: 600), () => botTurn()); }
  }

  Offset getHomePathPos(int p, int step, double s) { double r = s * 0.25, cx = s / 2, cy = s / 2; int entry = homeEntry[p]; double ang = (entry / 40) * 2 * pi - pi / 2; double ex = cx + r * cos(ang), ey = cy + r * sin(ang); double t = (step + 1) / 6.0; return Offset(ex + (cx - ex) * t, ey + (cy - ey) * t); }
  Widget dot() => Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle));
  Widget emptyDot() => SizedBox(width: 10, height: 10);
  Widget buildDiceFace(int v) { Widget d = dot(), e = emptyDot(); List<Widget> r1 = [e, e, e], r2 = [e, e, e], r3 = [e, e, e]; if (v == 1) r2 = [e, d, e]; else if (v == 2) { r1 = [d, e, e]; r3 = [e, e, d]; } else if (v == 3) { r1 = [d, e, e]; r2 = [e, d, e]; r3 = [e, e, d]; } else if (v == 4) { r1 = [d, e, d]; r3 = [d, e, d]; } else if (v == 5) { r1 = [d, e, d]; r2 = [e, d, e]; r3 = [d, e, d]; } else if (v == 6) { r1 = [d, e, d]; r2 = [d, e, d]; r3 = [d, e, d]; } return Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Padding(padding: EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r1), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r2), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r3)]))); }
  Widget diceNearHome(int p, int val) { bool isTurn = turn == p &&!canMove &&!gameOver; bool canTap = isTurn &&!isRolling && isMyTurn; if (widget.mode == GameMode.bot && p == 1) canTap = false; Color col = p == 0? Colors.green : Colors.red; bool rolling = isRolling && turn == p; return GestureDetector(onTap: canTap? roll : null, child: AnimatedBuilder(animation: _diceController, builder: (c, child) { double a = rolling? _diceController.value * 4 * pi : 0; return Transform.rotate(angle: a, child: child); }, child: AnimatedContainer(duration: Duration(milliseconds: 200), width: 85, height: 85, decoration: BoxDecoration(color: isTurn? col.withOpacity(0.20) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isTurn? col : Colors.black12, width: isTurn? 3 : 1.5)), child: Center(child: rolling? buildDiceFace(_rng.nextInt(6) + 1) : buildDiceFace(val))))); }
  Widget goti(int p, int t, double s) { int v = pos[p][t]; double boxSize = s * 0.14, pad = s * 0.02; Offset o; if (v == -1) { if (p == 0) { double bx = 10 + pad, by = 10 + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } else { double bx = s - 10 - boxSize + pad, by = s - 10 - boxSize + pad; o = Offset(bx + (t % 2) * (boxSize / 2.2), by + (t ~/ 2) * (boxSize / 2.2)); } } else if (v == 45) { o = Offset(s / 2 + (t % 2 == 0? -8 : 8), s / 2 + (t < 2? -8 : 8)); } else if (v >= 40) { o = getHomePathPos(p, v - 40, s); } else { double r = s * 0.25, ang = (v / 40) * 2 * pi - pi / 2; o = Offset(s / 2 + r * cos(ang), s / 2 + r * sin(ang)); } bool act = p == turn && canMove && isValidMove(p, t, dice) &&!gameOver && isMyTurn; if (widget.mode == GameMode.offline) act = p == turn && canMove && isValidMove(p, t, dice) &&!gameOver; return Positioned(left: o.dx - 11, top: o.dy - 11, child: GestureDetector(onTap: act? () => moveGoti(t) : null, child: Container(width: act? 28 : 20, height: act? 28 : 20, decoration: BoxDecoration(color: p == 0? Colors.green : Colors.red, shape: BoxShape.circle, border: Border.all(color: act? Colors.yellow : Colors.white, width: act? 2.5 : 1.5))))); }

  @override Widget build(BuildContext context) {
    double s = (MediaQuery.of(context).size.width < 400? MediaQuery.of(context).size.width : 400) - 20; double box = s * 0.14;
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Color(0xFF151A2B),
        title: Text(widget.mode == GameMode.offline? "OFFLINE - $myName" : widget.mode == GameMode.bot? "$myName vs $selectedBotName" : "ROOM ${widget.roomId} - $myName vs $opponentName", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if(widget.mode == GameMode.online) IconButton(icon: Icon(Icons.copy, color: Colors.white70, size: 18), onPressed: (){ Clipboard.setData(ClipboardData(text: widget.roomId)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room code copied: ${widget.roomId}"))); }),
          IconButton(icon: Icon(Icons.person_add_alt_1, color: Colors.greenAccent, size: 22), onPressed: addFriendFromGame),
          IconButton(icon: Icon(showChat? Icons.close : Icons.chat, color: Colors.amber, size: 22), onPressed: () => setState(() => showChat =!showChat))
        ]),
      body: Column(children: [
        Container(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Turn: ${turn == 0? myName : opponentName}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)), Text(isMyTurn? "YOUR TURN - TAP DICE" : "WAIT - $opponentName", style: TextStyle(fontSize: 11, color: isMyTurn? Colors.greenAccent : Colors.white54, fontWeight: FontWeight.bold))])),
        Expanded(child: Stack(children: [
          Center(child: Container(width: s, height: s, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFFF9C4), Color(0xFFE1F5FE), Color(0xFFFCE4EC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amber, width: 4)),
            child: Stack(clipBehavior: Clip.none, children: [
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