import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

const String agoraAppId = "68178816ba6d47c6864cc5d584f3e2b8";
const String agoraToken = "";

// FINAL - main.dart wale instance ko hi use karega, duplicate nahi
FirebaseDatabase getRtdb() {
  final db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: "https://ludo-premium-50-e427e-default-rtdb.asia-southeast1.firebasedatabase.app",
  );
  db.goOnline();
  return db;
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
  
  void _createRoom() async {
    await ensurePrefs(); 
    String c = genCode();
    String mobile = ludoPrefs.getString("mobile")??"guest";
    String myName = ludoPrefs.getString("name")??"Player";
    await getRtdb().ref("$c/game").set({"pos": [[-1,-1,-1,-1], [-1,-1,-1,-1]], "turn": 0, "diceGreen": 1, "diceRed": 1, "canMove": false, "gameOver": false, "createdAt": ServerValue.timestamp});
    await getRtdb().ref("$c/players/0").set({"mobile": mobile, "name": myName, "player": 0, "joinedAt": ServerValue.timestamp});
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
  }

  void joinRoom() async {
    await ensurePrefs();
    String code = codeCtrl.text.trim();
    if(code.length!=4) return;
    var snap = await getRtdb().ref("$code/game").get();
    if(!snap.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room $code nahi mila"))); return; }
    String mobile = ludoPrefs.getString("mobile")??"guest";
    String myName = ludoPrefs.getString("name")??"Player";
    await getRtdb().ref("$code/players/1").set({"mobile": mobile, "name": myName, "player": 1, "joinedAt": ServerValue.timestamp});
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber), Text("LUDO PREMIUM", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amber)), SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), icon: Icon(Icons.people), label: Text("OFFLINE - 1 PHONE 2 PLAYER"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), icon: Icon(Icons.smart_toy), label: Text("DOST KE SATH KHELO (BOT)"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickMatchScreen())))),
      SizedBox(height: 20), Divider(color: Colors.white24),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: _createRoom, child: Text("CREATE ROOM - ONLINE", style: TextStyle(color: Colors.white)))),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), decoration: InputDecoration(counterText: "", hintText: "CODE", filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: joinRoom, child: Text("JOIN ROOM - ONLINE", style: TextStyle(color: Colors.white)))),
    ]))));
  }
}

class QuickMatchScreen extends StatefulWidget { @override State<QuickMatchScreen> createState() => _QuickMatchScreenState(); }
class _QuickMatchScreenState extends State<QuickMatchScreen> {
  int countdown = 10; bool launched = false; Timer? t;
  @override void initState(){ super.initState(); t = Timer.periodic(Duration(seconds: 1), (timer){ if(countdown>0) setState(()=>countdown--); else { timer.cancel(); if(!launched){ launched=true; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot))); } } }); }
  @override void dispose(){ t?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context){ return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Text("$countdown", style: TextStyle(color: Colors.amber, fontSize: 80, fontWeight: FontWeight.w900)))); }
}

class LudoGame extends StatefulWidget {
  final String roomId; final int myPlayer; final GameMode mode;
  const LudoGame({super.key, required this.roomId, required this.myPlayer, required this.mode});
  @override State<LudoGame> createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> with SingleTickerProviderStateMixin {
  final _rng = Random(); int diceGreen = 1, diceRed = 1, turn = 0, consecutiveSixes = 0; bool canMove = false, gameOver = false, isRolling = false, showChat = false; bool isMicOn = true, isSpeakerOn = true;
  RtcEngine? agoraEngine;
  List<List<int>> pos = [[-1,-1,-1,-1], [-1,-1,-1,-1]]; List<Map<String, dynamic>> chatMessages = []; TextEditingController chatCtrl = TextEditingController();
  late AnimationController _diceController; final safe = [0, 10, 20, 30]; final startPos = [0, 20]; final homeEntry = [39, 19];
  DatabaseReference? roomRef; DatabaseReference? chatRef; DatabaseReference? playersRef;
  String myName = "You"; String opponentName = "Opponent"; String opponentMobile = "";
  final List<String> botNames = ["Jyoti","Simran","Kajal","Pinki","Sonia"]; String selectedBotName = "Jyoti";

  @override void initState() { selectedBotName = botNames[_rng.nextInt(botNames.length)]; _diceController = AnimationController(vsync: this, duration: Duration(milliseconds: 800)); initRoom(); }

  Future<void> initRoom() async {
    await ensurePrefs(); myName = ludoPrefs.getString("name")??"You";
    if(widget.mode == GameMode.online){
      getRtdb().goOnline();
      await [Permission.microphone].request();
      agoraEngine = createAgoraRtcEngine(); await agoraEngine!.initialize(RtcEngineContext(appId: agoraAppId)); await agoraEngine!.enableAudio(); await agoraEngine!.setEnableSpeakerphone(true);
      try { await agoraEngine!.joinChannel(token: agoraToken, channelId: widget.roomId, uid: widget.myPlayer==0?1:2, options: ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication, autoSubscribeAudio: true, publishMicrophoneTrack: true)); } catch(_){}

      roomRef = getRtdb().ref("${widget.roomId}/game");
      chatRef = getRtdb().ref("${widget.roomId}/chats");
      playersRef = getRtdb().ref("${widget.roomId}/players");

      // CONTACT FIX - pehle ek baar get() fir live listener, bina keepSynced ke
      playersRef!.onValue.listen((event){
        if(event.snapshot.value!=null && mounted){
          final map = event.snapshot.value as Map;
          final opp = 1 - widget.myPlayer;
          if(map.containsKey("$opp")){
            final d = Map<String,dynamic>.from(map["$opp"] as Map);
            setState((){
              opponentName = d["name"]?.toString()??opponentName;
              opponentMobile = d["mobile"]?.toString()??"";
            });
          }
          // agar dono player aa gaye to show
          if(map.containsKey("0") && map.containsKey("1")){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Contact: ${map["0"]["name"]} vs ${map["1"]["name"]}")));
          }
        }
      });

      roomRef!.onValue.listen((event){
        if(event.snapshot.value!=null && mounted){
          var data = Map<String,dynamic>.from(event.snapshot.value as Map);
          setState((){
            if(data['pos']!=null){ try { var raw = data['pos'] as List; pos = List<List<int>>.from(raw.map((e)=> List<int>.from((e as List).map((x)=> x as int)))); } catch(_){} }
            if(data['turn']!=null) turn = data['turn'] as int;
            if(data['diceGreen']!=null) diceGreen = data['diceGreen'] as int;
            if(data['diceRed']!=null) diceRed = data['diceRed'] as int;
            if(data['canMove']!=null) canMove = data['canMove'] as bool;
            if(data['gameOver']!=null) gameOver = data['gameOver'] as bool;
          });
        }
      });
      chatRef!.onChildAdded.listen((e){
        if(e.snapshot.value!=null && mounted){
          var d = Map<String,dynamic>.from(e.snapshot.value as Map);
          setState(()=> chatMessages.add({"player": d['player'], "msg": d['msg']}));
        }
      });
    } else { opponentName = selectedBotName; }
  }

  void syncRoom(){ if(widget.mode==GameMode.online && roomRef!=null){ roomRef!.update({"pos": pos, "turn": turn, "diceGreen": diceGreen, "diceRed": diceRed, "canMove": canMove, "gameOver": gameOver}); } }
  int get dice => turn==0?diceGreen:diceRed;
  bool get isMyTurn => widget.mode==GameMode.offline?true: widget.mode==GameMode.bot?turn==0:turn==widget.myPlayer;
  bool isValidMove(int p,int idx,int d){ int cur=pos[p][idx]; if(cur==45) return false; if(cur==-1) return d==6; if(cur>=40) return cur+d<=45; int dist=(homeEntry[p]-cur+40)%40; if(d==dist+1) return true; if(d>dist+1) return false; return true; }
  void roll(){ if(canMove||gameOver||isRolling||!isMyTurn) return; setState(()=>isRolling=true); _diceController.forward(from:0); Future.delayed(Duration(milliseconds:700),(){ if(!mounted) return; int d=_rng.nextInt(6)+1; setState((){ if(turn==0) diceGreen=d; else diceRed=d; canMove=true; isRolling=false; }); syncRoom(); bool any=false; for(int i=0;i<4;i++) if(isValidMove(turn,i,d)) any=true; if(!any) Future.delayed(Duration(milliseconds:600),(){ setState(()=>turn=1-turn); canMove=false; syncRoom(); }); }); }
  void botTurn(){ if(turn!=1) return; roll(); Future.delayed(Duration(milliseconds:900),(){ int best=-1; for(int i=0;i<4;i++) if(isValidMove(1,i,diceRed)) best=i; if(best!=-1) moveGoti(best); }); }
  void moveGoti(int idx){ if(!canMove) return; if(!isValidMove(turn,idx,dice)) return; setState((){ int cur=pos[turn][idx]; int opp=1-turn; if(cur==-1) pos[turn][idx]=startPos[turn]; else if(cur<40){ int dist=(homeEntry[turn]-cur+40)%40; if(dice==dist+1) pos[turn][idx]=40; else { int next=(cur+dice)%40; if(!safe.contains(next)){ for(int k=0;k<4;k++) if(pos[opp][k]==next) pos[opp][k]=-1; } pos[turn][idx]=next; } } else pos[turn][idx]=cur+dice; if(pos[turn].every((v)=>v==45)) gameOver=true; else { if(dice!=6) turn=1-turn; } canMove=false; }); syncRoom(); if(widget.mode==GameMode.bot && turn==1) Future.delayed(Duration(milliseconds:600),()=>botTurn()); }
  Widget dot()=>Container(width:10,height:10,decoration:BoxDecoration(color:Colors.black,shape:BoxShape.circle)); Widget empty()=>SizedBox(width:10,height:10);
  Widget buildDice(int v){ Widget d=dot(),e=empty(); List<Widget> r1=[e,e,e],r2=[e,e,e],r3=[e,e,e]; if(v==1) r2=[e,d,e]; else if(v==2){ r1=[d,e,e]; r3=[e,e,d]; } else if(v==3){ r1=[d,e,e]; r2=[e,d,e]; r3=[e,e,d]; } else if(v==4){ r1=[d,e,d]; r3=[d,e,d]; } else if(v==5){ r1=[d,e,d]; r2=[e,d,e]; r3=[d,e,d]; } else { r1=[d,e,d]; r2=[d,e,d]; r3=[d,e,d]; } return Container(width:68,height:68,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Padding(padding:EdgeInsets.all(8),child:Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:r1),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:r2),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:r3)]))); }
  Widget diceNear(int p,int val){ bool isTurn=turn==p&&!canMove&&!gameOver; bool canTap=isTurn&&!isRolling&&isMyTurn; Color col=p==0?Colors.green:Colors.red; return GestureDetector(onTap:canTap?roll:null,child:Container(width:85,height:85,decoration:BoxDecoration(color:isTurn?col.withOpacity(0.2):Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:isTurn?col:Colors.black12,width:isTurn?3:1.5)),child:Center(child:buildDice(val)))); }
  Offset homePos(int p,int step,double s){ double r=s*0.25,cx=s/2,cy=s/2; int entry=homeEntry[p]; double ang=(entry/40)*2*pi-pi/2; double ex=cx+r*cos(ang),ey=cy+r*sin(ang); double t=(step+1)/6.0; return Offset(ex+(cx-ex)*t,ey+(cy-ey)*t); }
  Widget goti(int p,int t,double s){ int v=pos[p][t]; double box=s*0.14,pad=s*0.02; Offset o; if(v==-1){ double bx=p==0?10+pad:s-10-box+pad,by=p==0?10+pad:s-10-box+pad; o=Offset(bx+(t%2)*(box/2.2),by+(t~/2)*(box/2.2)); } else if(v==45) o=Offset(s/2+(t%2==0?-8:8),s/2+(t<2?-8:8)); else if(v>=40) o=homePos(p,v-40,s); else { double r=s*0.25,ang=(v/40)*2*pi-pi/2; o=Offset(s/2+r*cos(ang),s/2+r*sin(ang)); } bool act=p==turn&&canMove&&isValidMove(p,t,dice)&&!gameOver&&isMyTurn; return Positioned(left:o.dx-11,top:o.dy-11,child:GestureDetector(onTap:act?()=>moveGoti(t):null,child:Container(width:act?28:20,height:act?28:20,decoration:BoxDecoration(color:p==0?Colors.green:Colors.red,shape:BoxShape.circle,border:Border.all(color:act?Colors.yellow:Colors.white,width:act?2.5:1.5))))); }

  @override Widget build(BuildContext context){
    double s=(MediaQuery.of(context).size.width<400?MediaQuery.of(context).size.width:400)-20; double box=s*0.14;
    String turnName=widget.mode==GameMode.online?(turn==widget.myPlayer?myName:opponentName):(turn==0?myName:opponentName);
    return Scaffold(backgroundColor:Color(0xFF0A0E1A), appBar: AppBar(backgroundColor:Color(0xFF151A2B), title: Text("ROOM ${widget.roomId} - $myName vs $opponentName", style: TextStyle(fontSize:11,color:Colors.white,fontWeight:FontWeight.bold)), actions: [IconButton(icon:Icon(Icons.chat,color:Colors.amber),onPressed:()=>setState(()=>showChat=!showChat))]),
      body: Column(children:[
        Container(margin:EdgeInsets.all(8),padding:EdgeInsets.all(10),decoration:BoxDecoration(color:Color(0xFF151A2B),borderRadius:BorderRadius.circular(10)),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text("Turn: $turnName",style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),Text(isMyTurn?"YOUR TURN":"WAIT - $opponentName",style:TextStyle(color:isMyTurn?Colors.greenAccent:Colors.white54)) ])),
        Expanded(child: Stack(children:[
          Center(child: Container(width:s,height:s,decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFFFF9C4),Color(0xFFE1F5FE),Color(0xFFFCE4EC)]),borderRadius:BorderRadius.circular(24),border:Border.all(color:Colors.amber,width:4)),child:Stack(children:[
            Positioned(left:10,top:10,width:box,height:box,child:Container(decoration:BoxDecoration(color:Colors.green.shade100,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.green,width:3)))),
            Positioned(right:10,bottom:10,width:box,height:box,child:Container(decoration:BoxDecoration(color:Colors.red.shade100,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.red,width:3)))),
            Positioned(left:8,top:box+8,child:diceNear(0,diceGreen)), Positioned(right:8,bottom:box+8,child:diceNear(1,diceRed)),
            for(int i=0;i<40;i++) Positioned(left:s/2+s*0.25*cos((i/40)*2*pi-pi/2)-7,top:s/2+s*0.25*sin((i/40)*2*pi-pi/2)-7,child:Container(width:14,height:14,decoration:BoxDecoration(color:safe.contains(i)?Colors.amber:Colors.white,shape:BoxShape.circle))),
            goti(0,0,s),goti(0,1,s),goti(0,2,s),goti(0,3,s),goti(1,0,s),goti(1,1,s),goti(1,2,s),goti(1,3,s),
          ]))),
          Positioned(top:15,left:0,right:0,child:Center(child:Container(padding:EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.black.withOpacity(0.6),borderRadius:BorderRadius.circular(20)),child:Row(mainAxisSize:MainAxisSize.min,children:[
            GestureDetector(onTap:()async{ setState(()=>isMicOn=!isMicOn); await agoraEngine?.muteLocalAudioStream(!isMicOn); },child:Container(padding:EdgeInsets.all(8),decoration:BoxDecoration(color:isMicOn?Colors.green:Colors.red,shape:BoxShape.circle),child:Icon(isMicOn?Icons.mic:Icons.mic_off,color:Colors.white,size:18))),
            SizedBox(width:10),
            GestureDetector(onTap:()async{ setState(()=>isSpeakerOn=!isSpeakerOn); await agoraEngine?.setEnableSpeakerphone(isSpeakerOn); },child:Container(padding:EdgeInsets.all(8),decoration:BoxDecoration(color:isSpeakerOn?Colors.green:Colors.red,shape:BoxShape.circle),child:Icon(isSpeakerOn?Icons.volume_up:Icons.volume_off,color:Colors.white,size:18))),
          ])))),
          if(showChat) Positioned(bottom:0,left:0,right:0,child:Container(height:350,decoration:BoxDecoration(color:Color(0xFF151A2B),borderRadius:BorderRadius.only(topLeft:Radius.circular(16),topRight:Radius.circular(16))),child:Column(children:[
            Container(padding:EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.amber,borderRadius:BorderRadius.only(topLeft:Radius.circular(16),topRight:Radius.circular(16))),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text("CHAT - $opponentName",style:TextStyle(color:Colors.black,fontWeight:FontWeight.bold)),GestureDetector(onTap:()=>setState(()=>showChat=false),child:Icon(Icons.close))])),
            Expanded(child: ListView.builder(padding:EdgeInsets.all(10),itemCount:chatMessages.length,itemBuilder:(c,i){ var m=chatMessages[i]; return Text("${m['player']}: ${m['msg']}",style:TextStyle(color:Colors.white)); })),
            Row(children:[Expanded(child:TextField(controller:chatCtrl,style:TextStyle(color:Colors.white),decoration:InputDecoration(hintText:"Type...",filled:true,fillColor:Color(0xFF2A2A3E),border:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:BorderSide.none)))), IconButton(icon:Icon(Icons.send,color:Colors.amber),onPressed:()async{ if(chatCtrl.text.trim().isEmpty) return; String t=chatCtrl.text.trim(); chatCtrl.clear(); await chatRef!.push().set({"player":myName,"msg":t}); })]),
          ])))
        ])),
      ]),
      floatingActionButton: FloatingActionButton.small(backgroundColor:Colors.amber,onPressed:()=>setState(()=>showChat=!showChat),child:Icon(Icons.chat,color:Colors.black)),
    );
  }
}