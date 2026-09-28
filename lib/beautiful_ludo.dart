import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'rtdb.dart';

// LOCKED NAME HELPER - Firestore users/<mobile>/name se permanent naam lega
// (pehli registration wala naam, jo kabhi nahi badalta - jaise janvi sharma)
// FIX: pehle phone me saved naam check hota hai (turant, bina net wait),
// aur Firestore se zyada se zyada 4 sec wait - taaki opponent connection kabhi na ruke
Future<String> getLockedName() async {
  await ensurePrefs();
  String loginName = ludoPrefs.getString("name")?? "You";
  String? cached = ludoPrefs.getString("locked_name");
  if (cached!= null && cached.isNotEmpty) return cached; // turant mil gaya, net nahi chahiye
  String? mobile = ludoPrefs.getString("mobile");
  if (mobile == null || mobile.isEmpty) return loginName;
  try {
    var doc = await FirebaseFirestore.instance.collection("users").doc(mobile).get().timeout(const Duration(seconds: 4));
    if (doc.exists) {
      String locked = doc.data()?["name"]?.toString()?? "";
      if (locked.isNotEmpty && locked!= "WAITING" && locked!= "Opponent") {
        await ludoPrefs.setString("locked_name", locked); // agli baar ke liye save
        return locked;
      }
    }
  } catch (_) {}
  return loginName;
}

const String agoraAppId = "023565215b9e4722b8fff10c0340c699";
const String agoraTokenServer = "https://patient-wave-cb8c.rohitsinghindian91.workers.dev";

// ===== TOKEN FIX: Worker plain text de ya JSON {"token":"..."} de ya quotes me de - teeno format chalega =====
String cleanAgoraToken(String body) {
  var t = body.trim();
  if (t.isEmpty) return "";
  if (t.startsWith("{")) {
    try {
      final m = jsonDecode(t) as Map<String, dynamic>;
      for (final k in ["token", "rtcToken", "rtc_token", "agoraToken", "data"]) {
        final v = m[k]?.toString()?? "";
        if (v.isNotEmpty &&!v.startsWith("{")) { t = v; break; }
      }
    } catch (_) {}
  }
  t = t.trim();
  if (t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
    t = t.substring(1, t.length - 1).trim();
  }
  if (t.startsWith("<")) return ""; // HTML error page aaya to khali samjho
  return t;
}

// ===== TOKEN FIX: Cloudflare Worker se FRESH Agora token - 3 BAAR TRY karega =====
// (khali token "" se certificate wale project me voice NAHI judegi - isliye ye zaroori hai)
Future<String> fetchAgoraToken(String channel, int uid) async {
  for (int a = 0; a < 3; a++) {
    try {
      final res = await http
     .get(Uri.parse("$agoraTokenServer/?channel=$channel&uid=$uid"))
     .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final t = cleanAgoraToken(res.body);
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
  }
  throw Exception("Token server failed - Worker check karo");
}

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
      String? mobile = ludoPrefs.getString("mobile"); String? myName = await getLockedName(); // LOCKED naam
      await getRtdb().ref(c).set({
        "game": {"pos": {"0": {"0": -1, "1": -1, "2": -1, "3": -1}, "1": {"0": -1, "1": -1, "2": -1, "3": -1}}, "turn": 0, "diceGreen": 1, "diceRed": 1, "canMove": false, "gameOver": false, "createdAt": ServerValue.timestamp, "roomId": c},
        "players": {"p0": {"mobile": mobile??"guest", "name": myName??"Player", "player": 0, "online": true, "joinedAt": ServerValue.timestamp}, "p1": {"mobile": "", "name": "WAITING", "player": 1}},
        "chats": {"init": {"player": "System", "msg": "Room Created", "time": ServerValue.timestamp}}
      });
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room ready! Code: $c")));
      Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error $e"))); }
  }

  void joinRoom() async {
    await ensurePrefs(); getRtdb().goOnline();
    String code = codeCtrl.text.trim();
    if(code.length!=4){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("4 digit code dalo"))); return; }
    var snap = await getRtdb().ref(code).get();
    if(!snap.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room nahi mila"))); return; }
    String? mobile = ludoPrefs.getString("mobile"); String? myName = await getLockedName(); // LOCKED naam
    await getRtdb().ref("$code/players/p1").set({"mobile": mobile??"guest", "name": myName??"Player", "player": 1, "online": true, "joinedAt": ServerValue.timestamp});
    if(!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber), Text("LUDO PREMIUM", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.amber)), SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(Icons.people), label: Text("OFFLINE - 1 PHONE 2 PLAYER"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(Icons.smart_toy), label: Text("DOST KE SATH KHELO"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickMatchScreen())))),
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
  int countdown = 10; bool botLaunched = false; bool matched = false;
  Timer? _timer; DatabaseReference? _myEntry; StreamSubscription? _queueSub;
  String _status = "RANDOM PLAYER DHOONDH RAHE HAIN...";

  @override void initState() { super.initState(); startQuickMatch(); }

  @override void dispose() { _timer?.cancel(); _queueSub?.cancel(); try{ _myEntry?.remove(); }catch(_){} super.dispose(); }

  Future<void> startQuickMatch() async {
    await ensurePrefs();
    await [Permission.microphone].request(); // match hua to voice turant ready
    String? mobile = ludoPrefs.getString("mobile");
    String myName = await getLockedName();
    getRtdb().goOnline();
    _myEntry = getRtdb().ref("quick_queue").push();
    await _myEntry!.set({"mobile": mobile?? "guest", "name": myName, "time": ServerValue.timestamp});
    _myEntry!.onDisconnect().remove();

    _queueSub = getRtdb().ref("quick_queue").onValue.listen((ev) async {
      if (matched || botLaunched ||!mounted || _myEntry == null) return;
      if (ev.snapshot.value == null) return;
      try {
        var all = Map<String, dynamic>.from(ev.snapshot.value as Map);
        String myKey = _myEntry!.key!;
        int now = DateTime.now().millisecondsSinceEpoch;
        List<String> keys = [];
        all.forEach((k, v) {
          String ks = k.toString(); bool keep = true;
          if (ks!= myKey) {
            try {
              var m = Map<String, dynamic>.from(v as Map);
              if (m["room"]!= null) keep = false; // already matched - bahar
              else if (m["mobile"]?.toString() == mobile) keep = false; // khud se match nahi
              else {
                var tv = m["time"]; var nm = m["name"];
                if (tv == null || nm == null) keep = false;
                else { int t = int.tryParse(tv.toString())?? 0; if (t > 0 && now - t > 60000) keep = false; }
              }
            } catch (_) { keep = false; }
          }
          if (keep) keys.add(ks);
        });
        keys.sort();
        if (keys.length >= 2 && keys[0] == myKey) {
          // MAIN HOST HU - room banao, guest ko bhejo, khud khelo
          matched = true; _timer?.cancel(); await _queueSub?.cancel();
          String c = (Random().nextInt(9000) + 1000).toString();
          var other = Map<String, dynamic>.from(all[keys[1]] as Map);
          await getRtdb().ref(c).set({
            "game": {"pos": {"0": {"0": -1, "1": -1, "2": -1, "3": -1}, "1": {"0": -1, "1": -1, "2": -1, "3": -1}}, "turn": 0, "diceGreen": 1, "diceRed": 1, "canMove": false, "gameOver": false, "createdAt": ServerValue.timestamp, "roomId": c},
            "players": {
              "p0": {"mobile": mobile?? "guest", "name": myName, "player": 0, "online": true, "joinedAt": ServerValue.timestamp},
              "p1": {"mobile": other["mobile"]?.toString()?? "guest", "name": other["name"]?.toString()?? "Player", "player": 1, "online": true, "joinedAt": ServerValue.timestamp}
            },
            "chats": {"init": {"player": "System", "msg": "Quick Match", "time": ServerValue.timestamp}}
          });
          await getRtdb().ref("quick_queue/${keys[1]}").update({"room": c, "role": 1});
          try { await _myEntry!.remove(); } catch (_) {}
          if (!mounted) return;
          setState(() => _status = "PLAYER MIL GAYA!");
          await Future.delayed(Duration(milliseconds: 600));
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
          return;
        }
        var me = all[myKey];
        if (me is Map && me["room"]!= null) {
          // GUEST HU - host ne room bana diya
          matched = true; _timer?.cancel(); await _queueSub?.cancel();
          String c = me["room"].toString();
          int role = int.tryParse(me["role"].toString())?? 1;
          try { await _myEntry!.remove(); } catch (_) {}
          if (!mounted) return;
          setState(() => _status = "PLAYER MIL GAYA!");
          await Future.delayed(Duration(milliseconds: 600));
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: role, mode: GameMode.online)));
        }
      } catch (_) {}
    });

    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (matched || botLaunched) return;
      if (countdown > 0) { if (mounted) setState(() => countdown--); }
      else launchBot();
    });
  }

  void launchBot() async {
    if (botLaunched || matched) return;
    botLaunched = true;
    _timer?.cancel(); await _queueSub?.cancel();
    try { await _myEntry?.remove(); } catch (_) {}
    if (!mounted) return;
    setState(() => _status = "DHUNDH LIYA!"); // bot mila - random naam wala khelna shuru karega
    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot)));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: Colors.orange),
        SizedBox(height: 16),
        Text("$countdown", style: TextStyle(color: Colors.amber, fontSize: 72, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Padding(padding: EdgeInsets.symmetric(horizontal: 30), child: Text(_status, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold))),
      ])));
  }
}

class LudoGame extends StatefulWidget {
  final String roomId; final int myPlayer; final GameMode mode;
  LudoGame({required this.roomId, required this.myPlayer, required this.mode});
  @override State<LudoGame> createState() => _LudoGameState();
}
class _LudoGameState extends State<LudoGame> {
  late RtcEngine agoraEngine;
  bool engineReady = false; bool voiceOn = true; bool speakerOn = true;
  String vsay = "";
  int voiceKey = 0;
  Timer? botTimer;
  Set<String> lockedTokens = {};
  int captured = 0;
  late StreamSubscription<DatabaseEvent> _gameSub;
  DatabaseReference get gRef => getRtdb().ref(widget.roomId);
  List<List<int>> pos = [[-1,-1,-1,-1],[-1,-1,-1,-1]];
  int dice = 1; int turn = 0; bool canMove = false; bool gameOver = false;
  String oppName = "Opponent";
  bool oppInRoom = false;
  bool chatOpen = false;
  String? myName;
  Timer? _timer;
  final mainPath = [35,36,37,38,39,40,47,54,61,60,59,58,57,56,55,48,41,34,27,20,13,6,7,8,9,10,11,12,19,26,33,40+6,47+6,54+6,61+6,68,75,82,89,96,97,98,99,100,101,102,109,116,123,116+14,109+14,102+14,95+14,88+14,81+14,74+14,67+14];
  List<int> diceAnim = [];
  final msgCtrl = TextEditingController();
  final chatScrollCtrl = ScrollController();
  List<Map<String,dynamic>> chatList = [];
  bool isMoving = false;
  late StreamSubscription<DatabaseEvent> _chatSub;

  @override void initState() {
    super.initState();
    if(widget.mode == GameMode.offline){ if(mounted) setState((){ oppName = "Player 2"; oppInRoom = true; }); }
    else if(widget.mode == GameMode.bot){
      oppInRoom = true;
      if(mounted) setState(() => oppName = "Player 2");
      botLoop();
      botAutoDice();
    }
    else initAgoraAndRoom();
  }

  void botLoop(){ if(mounted && widget.mode == GameMode.bot &&!gameOver && turn == 1) botTimer = Timer(Duration(milliseconds: 900), () async {
    if(!mounted || widget.mode!= GameMode.bot || gameOver) return;
    bool botCanMove = await botCanMoveCheck();
    if(botCanMove &&!gameOver && turn == 1){
      int b = Random().nextInt(6) + 1;
      if(mounted) setState((){ dice = b; });
      int totalTokens = 0, finished = 0, inHome = 0;
      for(int i=0;i<4;i++){ if(pos[1][i] >= 0) totalTokens++; if(pos[1][i] == 57) finished++; if(pos[1][i] == -1) inHome++; }
      int movableCount = 0;
      for(int i=0;i<4;i++){ if(pos[1][i] >= 0 && pos[1][i] < 57) movableCount++; }
      if(b == 6 && inHome > 0 && movableCount == 0){
        for(int i=0;i<4;i++){ if(pos[1][i] == -1){ if(mounted) setState(() => pos[1][i] = 0); break; } }
      } else if(movableCount > 0){
        int bestIdx = -1, bestScore = -999;
        for(int i=0;i<4;i++){
          int p = pos[1][i];
          if(p < 0 || p >= 57) continue;
          int np = p + b; if(np > 57) continue;
          int score = 0; bool willFinish = (np == 57);
          bool willCapture = false, willDanger = false, willLeaveBase = (p == 0);
          bool willSafe = [0,8,13,21,26,34,39,47].contains(np);
          bool willHome = (np >= 51);
          for(int j=0;j<4;j++){
            if(pos[0][j] < 0 || pos[0][j] >= 51 || pos[0][j] >= 57) continue;
            int rel = (pos[0][j] + 26) % 52;
            if(rel == np &&![0,8,13,21,26,34,39,47].contains(np)) willCapture = true;
          }
          for(int j=0;j<4;j++){
            if(pos[0][j] < 0 || pos[0][j] >= 51 || pos[0][j] >= 57) continue;
            int rel = (pos[0][j] + 26) % 52;
            int dist = (np - rel + 52) % 52;
            if(dist >= 1 && dist <= 6 &&![0,8,13,21,26,34,39,47].contains(np)) willDanger = true;
          }
          if(willFinish) score += 100;
          if(willCapture) score += 60;
          if(willSafe) score += 25;
          if(willLeaveBase) score += 15;
          if(willHome) score += 20;
          if(willDanger) score -= 30;
          score += np;
          if(score > bestScore){ bestScore = score; bestIdx = i; }
        }
        if(bestIdx >= 0 && mounted) setState(() => pos[1][bestIdx] = pos[1][bestIdx] + b);
        await Future.delayed(Duration(milliseconds: 300));
        if(!mounted) return;
        int np2 = pos[1][bestIdx] + 0;
        if(np2 >= 0 && np2 < 51){
          int myAbs = (np2 + 26) % 52;
          if(![0,8,13,21,26,34,39,47].contains(myAbs)){
            bool gotiKati = false;
            for(int j=0;j<4;j++){
              if(pos[0][j] >= 0 && pos[0][j] < 51){
                int oppAbs = (pos[0][j] + 0) % 52;
                if(oppAbs == myAbs){ if(mounted) setState(() => pos[0][j] = -1); gotiKati = true; }
              }
            }
            if(gotiKati && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("BOT ne tumhari goti kaat di!")));
          }
        }
      }
      if(mounted &&!gameOver){
        if(b == 6){ setState(() => turn = 1); }
        else { setState(() => turn = 0); }
        botLoop();
      }
    } else if(!gameOver && turn == 1){ setState(() => turn = 0); botLoop(); }
  }); }

  void botAutoDice() {
    Future.delayed(Duration(milliseconds: 1200), () {
      if(!mounted || widget.mode!= GameMode.bot || gameOver) return;
      if(turn == 1) botLoop();
      else Future.delayed(Duration(milliseconds: 800), botAutoDice);
    });
  }

  Future<bool> botCanMoveCheck() async {
    for(int i=0;i<4;i++){ if(pos[1][i] == -1 || (pos[1][i] >= 0 && pos[1][i] + dice <= 57)) return true; }
    return false;
  }

  Future<void> initAgoraAndRoom() async {
    await ensurePrefs();
    myName = await getLockedName(); // LOCKED naam - ek baar jo naam bana, wahi hamesha
    await [Permission.microphone].request();
    getRtdb().goOnline();
    var snap = await gRef.child("game").get();
    if(!snap.exists) { if(mounted) Navigator.pop(context); return; }
    await initVoice();
    listenRoom();
  }

  // ===== TOKEN FIX: ONLINE me voice ke liye FRESH token Worker se - channel join se pehle =====
  Future<void> initVoice() async {
    voiceKey++;
    final k = voiceKey;
    if (mounted) setState(() => vsay = "Voice: token la rahe hain...");
    try {
      final freshToken = await fetchAgoraToken("ludo_${widget.roomId}", widget.myPlayer == 0? 1 : 2);
      if (!mounted || k!= voiceKey) return;
      setState(() => vsay = "Voice: token mil gaya (${freshToken.length} chars)");
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(RtcEngineContext(appId: agoraAppId));
      if (!mounted || k!= voiceKey) return;
      await agoraEngine.enableAudio();
      await agoraEngine.setDefaultAudioRoutetoSpeakerphone(true);
      engineReady = true;
      agoraEngine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (c, e) { if (mounted && k == voiceKey) setState(() => vsay = "Voice connected!"); },
        onError: (e, m) { if (mounted && k == voiceKey) setState(() => vsay = "Voice ERROR $e: $m"); },
        onTokenPrivilegeWillExpire: (c, t) async {
          try {
            final nt = await fetchAgoraToken("ludo_${widget.roomId}", widget.myPlayer == 0? 1 : 2);
            await agoraEngine.renewToken(nt);
          } catch (_) {}
        },
      ));
      if (mounted && k == voiceKey) setState(() => vsay = "Voice: channel join ho raha...");
      await agoraEngine.joinChannel(
        token: freshToken,
        channelId: "ludo_${widget.roomId}",
        uid: widget.myPlayer == 0? 1 : 2,
        options: ChannelMediaOptions(autoSubscribeAudio: true, publishMicrophoneTrack: true),
      );
    } catch (e) {
      if (mounted && k == voiceKey) setState(() => vsay = "Voice ERROR $e");
    }
  }

  void toggleVoice() async {
    if(!engineReady) return;
    setState(() => voiceOn =!voiceOn);
    await agoraEngine.muteLocalAudioStream(!voiceOn);
  }

  void toggleSpeaker() async {
    if(!engineReady) return;
    setState(() => speakerOn =!speakerOn);
    await agoraEngine.setEnableSpeakerphone(speakerOn);
  }

  void listenRoom() {
    getRtdb().goOnline();
    _gameSub = gRef.child("game").onValue.listen((ev) {
      if(!mounted || widget.mode!= GameMode.online) return;
      var v = ev.snapshot.value; if(v == null) return;
      var g = Map<String,dynamic>.from(v as Map);
      var p = Map<String,dynamic>.from(g["pos"] as Map);
      List<List<int>> np = [[-1,-1,-1,-1],[-1,-1,-1,-1]];
      p.forEach((k,val){ int pl = int.parse(k.toString()); var m = Map<String,dynamic>.from(val as Map); m.forEach((kk,vv){ np[pl][int.parse(kk.toString())] = int.parse(vv.toString()); }); });
      setState((){
        pos = np; dice = int.parse(g["diceGreen"].toString()); turn = int.parse(g["turn"].toString());
        canMove = g["canMove"] == true; gameOver = g["gameOver"] == true;
      });
      if(gameOver) showWinner();
    });
    gRef.child("players").onValue.listen((ev) async {
      if(!mounted || widget.mode!= GameMode.online) return;
      var v = ev.snapshot.value; if(v == null) return;
      try {
        var m = Map<String,dynamic>.from(v as Map);
        int opp = widget.myPlayer == 0? 1 : 0;
        var key = "p$opp";
        if(m[key]!= null){
          var pm = Map<String,dynamic>.from(m[key] as Map);
          String nm = pm["name"]?.toString()?? "Opponent";
          if(nm.isNotEmpty && nm!= "WAITING" && nm!= "Opponent"){
            if(mounted) setState((){ oppName = nm; oppInRoom = true; });
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$nm ne game join kar liya 🎉")));
          }
        }
      } catch(_){}
    });
    _chatSub = gRef.child("chats").limitToLast(30).onValue.listen((ev) {
      if(!mounted) return;
      var v = ev.snapshot.value; List<Map<String,dynamic>> l = [];
      if(v!= null){ (v as Map).forEach((k,val){ var m = Map<String,dynamic>.from(val as Map); l.add({"player": m["player"]?.toString()??"?", "msg": m["msg"]?.toString()??"", "time": m["time"]}); }); }
      l.sort((a,b){ int ta = a["time"] is int? a["time"] : 0; int tb = b["time"] is int? b["time"] : 0; return ta.compareTo(tb); });
      if(mounted) setState(() => chatList = l);
      Future.delayed(Duration(milliseconds: 100), (){ if(chatScrollCtrl.hasClients) chatScrollCtrl.jumpTo(chatScrollCtrl.position.maxScrollExtent); });
    });
    _timer = Timer.periodic(Duration(seconds: 2), (_) async {
      if(!mounted) return;
      if(widget.mode == GameMode.online && gameOver) return;
      if(widget.mode == GameMode.online && turn!= widget.myPlayer) return;
      if(widget.mode == GameMode.bot && turn!= 0) return;
      var snap = await gRef.child("players").get().timeout(Duration(seconds: 3), onTimeout: () => throw TimeoutException("x"));
    });
  }

  void showWinner(){
    if(!mounted) return;
    String w = turn == 0? (myName?? "Player 1") : oppName;
    showDialog(barrierDismissible: false, context: context, builder: (_) => AlertDialog(
      title: Text("🏆 $w JEET GAYA!", style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [TextButton(onPressed: (){ Navigator.pop(context); Navigator.pop(context); }, child: Text("LOBBY"))],
    ));
  }

  Future<void> rollDice() async {
    if(gameOver || isMoving) return;
    if(widget.mode == GameMode.online && turn!= widget.myPlayer) return;
    if(widget.mode == GameMode.bot && turn!= 0) return;
    int d = Random().nextInt(6) + 1;
    setState((){ diceAnim = [1,2,3,4,5,6]; });
    await Future.delayed(Duration(milliseconds: 250));
    if(!mounted) return;
    setState((){ dice = d; diceAnim = []; });
    bool can = false;
    for(int i=0;i<4;i++){ int p = pos[turn][i]; if(p == -1 && d == 6) can = true; else if(p >= 0 && p + d <= 57) can = true; }
    if(widget.mode == GameMode.online){
      await gRef.child("game").update({"diceGreen": turn == 0? d : dice, "diceRed": turn == 1? d : dice, "canMove": can, "turn": turn});
      if(!can){ await Future.delayed(Duration(milliseconds: 600)); if(mounted) nextTurn(); }
    } else {
      setState(() => canMove = can);
      if(!can){ await Future.delayed(Duration(milliseconds: 600)); if(mounted) nextTurn(); }
    }
  }

  void nextTurn() async {
    if(gameOver) return;
    int nt = turn == 0? 1 : 0;
    if(widget.mode == GameMode.online){
      await gRef.child("game").update({"turn": nt, "canMove": false});
    } else {
      setState((){ turn = nt; canMove = false; });
      if(widget.mode == GameMode.bot && nt == 1) botLoop();
    }
  }

  Future<void> tryMove(int idx) async {
    if(gameOver || isMoving ||!canMove) return;
    if(widget.mode == GameMode.online && turn!= widget.myPlayer) return;
    if(widget.mode == GameMode.bot && turn!= 0) return;
    int p = pos[turn][idx];
    int d = dice;
    bool valid = false;
    if(p == -1 && d == 6) valid = true;
    else if(p >= 0 && p + d <= 57) valid = true;
    if(!valid) return;
    isMoving = true;
    int np = (p == -1)? 0 : p + d;
    setState(() => pos[turn][idx] = np);
    await Future.delayed(Duration(milliseconds: 350));
    if(!mounted){ isMoving = false; return; }
    checkCapture(turn, idx);
    if(checkWin(turn)){
      if(widget.mode == GameMode.online) await gRef.child("game").update({"gameOver": true});
      else setState(() => gameOver = true);
      isMoving = false;
      showWinner();
      return;
    }
    if(widget.mode == GameMode.online){
      Map<String,dynamic> posMap = {};
      for(int pl=0; pl<2; pl++){ Map<String,dynamic> tm = {}; for(int i=0;i<4;i++) tm["$i"] = pos[pl][i]; posMap["$pl"] = tm; }
      await gRef.child("game").update({"pos": posMap});
    }
    isMoving = false;
    if(d == 6){ if(mounted) setState(() => canMove = false); if(widget.mode == GameMode.online){ await gRef.child("game").update({"canMove": false}); } }
    else nextTurn();
  }

  void checkCapture(int pl, int idx){
    int myPos = pos[pl][idx];
    if(myPos < 0 || myPos >= 51) return;
    int myAbs = pl == 0? myPos : (myPos + 26) % 52;
    if([0,8,13,21,26,34,39,47].contains(myAbs)) return;
    int opp = pl == 0? 1 : 0;
    for(int j=0;j<4;j++){
      int op = pos[opp][j];
      if(op < 0 || op >= 51) continue;
      int oppAbs = opp == 0? op : (op + 26) % 52;
      if(oppAbs == myAbs){
        setState(() => pos[opp][j] = -1);
        captured++;
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pl == widget.myPlayer? "Goti kaat di! 🎯" : "Tumhari goti kat gayi! 😅")));
      }
    }
  }

  bool checkWin(int pl){
    for(int i=0;i<4;i++) if(pos[pl][i]!= 57) return false;
    return true;
  }

  void sendChat() async {
    String t = msgCtrl.text.trim(); if(t.isEmpty) return;
    msgCtrl.clear();
    await gRef.child("chats").push().set({"player": myName?? "Player", "msg": t, "time": ServerValue.timestamp});
  }

  @override void dispose(){
    botTimer?.cancel(); _timer?.cancel();
    try{ _gameSub.cancel(); }catch(_){}
    try{ _chatSub.cancel(); }catch(_){}
    if(engineReady){ try{ agoraEngine.leaveChannel(); }catch(_){} try{ agoraEngine.release(); }catch(_){} }
    msgCtrl.dispose(); chatScrollCtrl.dispose();
    super.dispose();
  }

  Offset tokenXY(int pl, int idx, double s){
    int p = pos[pl][idx];
    double cell = s / 15;
    if(p == -1){
      double bx = pl == 0? cell * 1.5 : cell * 10.5;
      double by = pl == 0? cell * 10.5 : cell * 1.5;
      double ox = (idx % 2) * cell * 1.6; double oy = (idx ~/ 2) * cell * 1.6;
      return Offset(bx + ox, by + oy);
    }
    int absPos = pl == 0? p : (p + 26) % 52;
    int cellIdx;
    if(p >= 51){
      List<int> homePath = pl == 0? [52,53,54,55,56,57] : [58,59,60,61,62,63];
      cellIdx = homePath[p - 51];
    } else cellIdx = mainPath[absPos];
    int r = cellIdx ~/ 15, c = cellIdx % 15;
    return Offset(c * cell + cell / 2, r * cell + cell / 2);
  }

  @override Widget build(BuildContext context){
    String title = widget.mode == GameMode.offline? "OFFLINE" : widget.mode == GameMode.bot? "BOT MATCH" : "ROOM ${widget.roomId}";
    String sub = widget.mode == GameMode.online? "${myName?? ""} vs $oppName" : widget.mode == GameMode.bot? "You vs $oppName" : "Player 1 vs Player 2";
    bool myTurn = widget.mode == GameMode.offline? true : (widget.mode == GameMode.bot? turn == 0 : turn == widget.myPlayer);
    return WillPopScope(
      onWillPop: () async {
        if(widget.mode == GameMode.online){ try{ await gRef.child("players/p${widget.myPlayer}").update({"online": false}); }catch(_){} }
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        appBar: AppBar(backgroundColor: Color(0xFF0A0E1A), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: Text("$title - $sub", style: TextStyle(fontSize: 13, color: Colors.white)),
          actions: [
            if(widget.mode == GameMode.online)
              IconButton(icon: Icon(Icons.chat, color: Colors.amber), onPressed: () => setState(() => chatOpen =!chatOpen)),
          ]),
        body: Column(children: [
          Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: turn == 0? Colors.red.withOpacity(0.25) : Colors.green.withOpacity(0.25),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Turn: ${turn == 0? (widget.myPlayer == 0? (myName?? "You") : oppName) : (widget.myPlayer == 1? (myName?? "You") : oppName)}",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(myTurn? (canMove? "CHALO!" : "YOUR TURN - TAP DICE") : "WAIT - ${turn == 0? "pooja" : oppName}",
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ])),
          if(widget.mode == GameMode.online && oppInRoom)
            Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 6), color: Colors.green.withOpacity(0.2),
              child: Text("✅ $oppName ne game join kar liya hai", textAlign: TextAlign.center, style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))),
          if(widget.mode == GameMode.online)
            Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              InkWell(onTap: toggleVoice, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: voiceOn? Colors.green : Colors.red, shape: BoxShape.circle), child: Icon(voiceOn? Icons.mic : Icons.mic_off, color: Colors.white, size: 20))),
              SizedBox(width: 12),
              InkWell(onTap: toggleSpeaker, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: speakerOn? Colors.blue : Colors.grey, shape: BoxShape.circle), child: Icon(speakerOn? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20))),
            ])),
          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: Container(margin: EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 3), borderRadius: BorderRadius.circular(8)),
            child: LayoutBuilder(builder: (ctx, cons){
              double s = cons.maxWidth;
              return Stack(children: [
                CustomPaint(size: Size(s, s), painter: BoardPainter()),
                for(int pl=0; pl<2; pl++) for(int i=0;i<4;i++)
                  Builder(builder: (_){
                    Offset o = tokenXY(pl, i, s);
                    bool clickable = myTurn && canMove && turn == pl &&
                      (widget.mode == GameMode.offline || widget.mode == GameMode.bot || pl == widget.myPlayer) &&
                      ((pos[pl][i] == -1 && dice == 6) || (pos[pl][i] >= 0 && pos[pl][i] + dice <= 57));
                    return Positioned(
                      left: o.dx - s/34, top: o.dy - s/34,
                      child: GestureDetector(
                        onTap: clickable? () => tryMove(i) : null,
                        child: Container(
                          width: s/17, height: s/17,
                          decoration: BoxDecoration(
                            color: pl == 0? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: clickable? Colors.yellow : Colors.white, width: clickable? 3 : 1.5),
                            boxShadow: clickable? [BoxShadow(color: Colors.yellow, blurRadius: 8)] : [],
                          ),
                          child: Center(child: Text("${i+1}", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    );
                  }),
                Positioned.fill(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _diceBox(0, s, myTurn && turn == 0),
                  _diceBox(1, s, myTurn && turn == 1),
                ])),
              ]);
            }))))),
          if(widget.mode == GameMode.online)
            Padding(padding: EdgeInsets.all(8), child: Text(vsay, style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
          if(widget.mode == GameMode.online && chatOpen)
            Container(height: 180, margin: EdgeInsets.all(8), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Expanded(child: ListView.builder(controller: chatScrollCtrl, padding: EdgeInsets.all(8), itemCount: chatList.length,
                  itemBuilder: (c,i){ var m = chatList[i]; return Padding(padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text("${m["player"]}: ${m["msg"]}", style: TextStyle(color: Colors.white70, fontSize: 12))); })),
                Row(children: [Expanded(child: TextField(controller: msgCtrl, style: TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(hintText: "Message...", hintStyle: TextStyle(color: Colors.white30), contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
                  IconButton(icon: Icon(Icons.send, color: Colors.amber, size: 20), onPressed: sendChat)]),
              ])),
        ]),
        floatingActionButton: widget.mode == GameMode.online? FloatingActionButton(
          backgroundColor: Colors.amber,
          child: Icon(Icons.chat, color: Colors.black),
          onPressed: () => setState(() => chatOpen =!chatOpen),
        ) : null,
      ),
    );
  }

  Widget _diceBox(int pl, double s, bool active){
    int show = diceAnim.isNotEmpty? diceAnim[Random().nextInt(diceAnim.length)] : dice;
    return GestureDetector(
      onTap: active? rollDice : null,
      child: Container(
        margin: EdgeInsets.all(s * 0.06),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active? Colors.yellow : Colors.transparent, width: 3),
          boxShadow: active? [BoxShadow(color: Colors.yellow.withOpacity(0.6), blurRadius: 10)] : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("$show", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
            Container(margin: EdgeInsets.all(1), width: 8, height: 8,
              decoration: BoxDecoration(color: show > i? Colors.black : Colors.black26, shape: BoxShape.circle)))),
        ]),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size){
    double cell = size.width / 15;
    Paint red = Paint()..color = Colors.red;
    Paint green = Paint()..color = Colors.green;
    Paint white = Paint()..color = Colors.white;
    Paint yellow = Paint()..color = Colors.amber;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Color(0xFFE8F4F8));
    canvas.drawRect(Rect.fromLTWH(0, 0, cell*6, cell*6), red);
    canvas.drawRect(Rect.fromLTWH(cell*9, 0, cell*6, cell*6), green);
    canvas.drawRect(Rect.fromLTWH(0, cell*9, cell*6, cell*6), Paint()..color = Colors.blue);
    canvas.drawRect(Rect.fromLTWH(cell*9, cell*9, cell*6, cell*6), Paint()..color = Colors.amber);
    for(int r=0;r<15;r++) for(int c=0;c<15;c++){
      if(r<6 && c<6) continue; if(r<6 && c>=9) continue; if(r>=9 && c<6) continue; if(r>=9 && c>=9) continue;
      canvas.drawRect(Rect.fromLTWH(c*cell, r*cell, cell, cell), white);
      canvas.drawRect(Rect.fromLTWH(c*cell, r*cell, cell, cell), Paint()..style = PaintingStyle.stroke..color = Colors.black12);
    }
    List<int> safeCells = [0,8,13,21,26,34,39,47];
    for(int sc in safeCells){
      int r = sc ~/ 15, c = sc % 15;
      canvas.drawCircle(Offset(c*cell + cell/2, r*cell + cell/2), cell*0.3, yellow);
    }
    List<int> redHome = [52,53,54,55,56];
    for(int hc in redHome){ int r = hc ~/ 15, c = hc % 15; canvas.drawRect(Rect.fromLTWH(c*cell, r*cell, cell, cell), red); }
    List<int> greenHome = [58,59,60,61,62];
    for(int hc in greenHome){ int r = hc ~/ 15, c = hc % 15; canvas.drawRect(Rect.fromLTWH(c*cell, r*cell, cell, cell), green); }
    Path tri = Path();
    tri.moveTo(cell*6, cell*6); tri.lineTo(cell*9, cell*6); tri.lineTo(cell*7.5, cell*7.5); tri.close();
    canvas.drawPath(tri, red);
    tri = Path();
    tri.moveTo(cell*9, cell*6); tri.lineTo(cell*9, cell*9); tri.lineTo(cell*7.5, cell*7.5); tri.close();
    canvas.drawPath(tri, green);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}
