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
  void _createRoom() async {
    await ensurePrefs(); getRtdb().goOnline();
    String c = genCode();
    await getRtdb().ref(c).set({
      "game": {"pos": {"0": {"0": -1, "1": -1, "2": -1, "3": -1}, "1": {"0": -1, "1": -1, "2": -1, "3": -1}}, "turn": 0, "diceGreen": 1, "diceRed": 1, "canMove": false, "gameOver": false},
      "players": {"p0": {"mobile": ludoPrefs.getString("mobile")??"guest", "name": ludoPrefs.getString("name")??"Player", "player": 0}, "p1": {"mobile": "", "name": "WAITING", "player": 1}},
      "chats": {"init": {"player": "System", "msg": "Room Created", "time": ServerValue.timestamp}}
    });
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: c, myPlayer: 0, mode: GameMode.online)));
  }
  void joinRoom() async {
    await ensurePrefs(); getRtdb().goOnline();
    String code = codeCtrl.text.trim();
    if (code.length!=4) return;
    var snap = await getRtdb().ref(code).get();
    if (!snap.exists) return;
    await getRtdb().ref("$code/players/p1").set({"mobile": ludoPrefs.getString("mobile")??"guest", "name": ludoPrefs.getString("name")??"Player", "player": 1});
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), body: Center(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.casino, size: 60, color: Colors.amber),
      Text("LUDO PREMIUM - FINAL", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.amber)),
      SizedBox(height: 30),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _createRoom, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("CREATE ROOM - ONLINE"))),
      SizedBox(height: 10),
      TextField(controller: codeCtrl, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), decoration: InputDecoration(counterText: "", hintText: "CODE", filled: true, fillColor: Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: joinRoom, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text("JOIN ROOM", style: TextStyle(color: Colors.black)))),
      SizedBox(height: 15),
      SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>LudoGame(roomId: "OFFLINE", myPlayer: 0, mode: GameMode.offline))), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), child: Text("OFFLINE - DOST KE SAATH"))),
      SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>LudoGame(roomId: "BOT", myPlayer: 0, mode: GameMode.bot))), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: Text("VS BOT"))),
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
  int diceGreen=1,diceRed=1,turn=0,consecutiveSixes=0;
  bool canMove=false,gameOver=false,isRolling=false,showChat=false;
  List<List<int>> pos=[[-1,-1,-1,-1],[-1,-1,-1,-1]];
  List<Map<String,dynamic>> chatMessages=[];
  TextEditingController chatCtrl=TextEditingController();
  late AnimationController _diceController;
  final safe=[0,10,20,30];
  final startPos=[0,20];
  final homeEntry=[39,19];
  DatabaseReference? roomRef;
  DatabaseReference? chatRef;
  RtcEngine? agoraEngine;
  String myName="You";
  String p0Name="Player0";
  String p1Name="Player1";
  final List<String> botNames=["Jyoti","Simran","Kajal","Pinki","Sonia"];
  String selectedBotName="Jyoti";

  @override void initState() {
    selectedBotName=botNames[_rng.nextInt(botNames.length)];
    _diceController=AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    initRoom();
    if(widget.mode==GameMode.bot && turn==1) Future.delayed(Duration(milliseconds: 800), ()=>botTurn());
  }

  Future<void> initRoom() async {
    await ensurePrefs();
    myName=ludoPrefs.getString("name")??"You";
    if(widget.mode==GameMode.online){
      getRtdb().goOnline();
      await [Permission.microphone].request();
      try{
        agoraEngine=createAgoraRtcEngine();
        await agoraEngine!.initialize(RtcEngineContext(appId: agoraAppId));
        await agoraEngine!.enableAudio();
        await agoraEngine!.joinChannel(token: agoraToken, channelId: widget.roomId, uid: widget.myPlayer==0?1:2, options: ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication));
      }catch(_){}
      roomRef=getRtdb().ref(widget.roomId);
      chatRef=getRtdb().ref("${widget.roomId}/chats");
      roomRef!.onValue.listen((event){
        if(event.snapshot.value==null ||!mounted) return;
        var all=event.snapshot.value as Map;
        var gameData=all["game"]!=null? Map<String,dynamic>.from(all["game"] as Map):{};
        var playersData=all["players"]!=null? Map<String,dynamic>.from(all["players"] as Map):null;
        setState((){
          if(playersData!=null){
            var p0=playersData["p0"]!=null? Map<String,dynamic>.from(playersData["p0"] as Map):null;
            var p1=playersData["p1"]!=null? Map<String,dynamic>.from(playersData["p1"] as Map):null;
            if(p0!=null && p0["name"]!=null && p0["name"].toString().isNotEmpty && p0["name"].toString()!="WAITING") p0Name=p0["name"].toString();
            if(p1!=null && p1["name"]!=null && p1["name"].toString().isNotEmpty && p1["name"].toString()!="WAITING") p1Name=p1["name"].toString();
          }
          if(gameData['pos']!=null){
            try{
              var raw=gameData['pos'];
              List<List<int>> newPos=[[-1,-1,-1,-1],[-1,-1,-1,-1]];
              if(raw is Map){
                raw.forEach((pk,pv){
                  int p=int.tryParse(pk.toString())??0;
                  if(p>=0&&p<2 && pv is Map){
                    pv.forEach((k,v){
                      int idx=int.tryParse(k.toString())??0;
                      if(idx>=0&&idx<4) newPos[p][idx]=int.tryParse(v.toString())??-1;
                    });
                  }
                });
              }
              pos=newPos;
            }catch(e){}
          }
          if(gameData['turn']!=null) turn=int.tryParse(gameData['turn'].toString())??0;
          if(gameData['diceGreen']!=null) diceGreen=int.tryParse(gameData['diceGreen'].toString())??1;
          if(gameData['diceRed']!=null) diceRed=int.tryParse(gameData['diceRed'].toString())??1;
          if(gameData['canMove']!=null) canMove=gameData['canMove'].toString()=="true";
          if(gameData['gameOver']!=null) gameOver=gameData['gameOver'].toString()=="true";
        });
      });
      chatRef!.onValue.listen((e){
        if(e.snapshot.value!=null && mounted){
          var all=Map<String,dynamic>.from(e.snapshot.value as Map);
          List<Map<String,dynamic>> msgs=[];
          all.forEach((k,v){
            try{ var m=Map<String,dynamic>.from(v as Map); if(m['player']!="System") msgs.add({"player": m['player'], "msg": m['msg']}); }catch(_){}
          });
          setState(()=>chatMessages=msgs);
        }
      });
    } else {
      setState((){
        p0Name=myName;
        p1Name=widget.mode==GameMode.bot?selectedBotName:"Dost";
      });
    }
  }

  @override void dispose() { _diceController.dispose(); chatCtrl.dispose(); super.dispose(); }
  int get dice=>turn==0?diceGreen:diceRed;
  bool get isMyTurn{ if(widget.mode==GameMode.offline) return true; if(widget.mode==GameMode.bot) return turn==0; return turn==widget.myPlayer; }
  bool isValidMove(int p,int idx,int d){ int cur=pos[p][idx]; if(cur==45) return false; if(cur==-1) return d==6; if(cur>=40) return cur+d<=45; return true; }
  void sendMessage() async { if(chatCtrl.text.trim().isEmpty) return; String t=chatCtrl.text.trim(); chatCtrl.clear(); if(widget.mode==GameMode.online && chatRef!=null){ await chatRef!.push().set({"player": myName, "msg": t, "time": ServerValue.timestamp}); } else { setState(()=>chatMessages.add({"player": myName, "msg": t})); } }
  Future<void> syncRoom() async { if(widget.mode==GameMode.online && roomRef!=null){ await getRtdb().ref("${widget.roomId}/game/pos").set({"0": {"0": pos[0][0], "1": pos[0][1], "2": pos[0][2], "3": pos[0][3]}, "1": {"0": pos[1][0], "1": pos[1][1], "2": pos[1][2], "3": pos[1][3]}}); await getRtdb().ref("${widget.roomId}/game/turn").set(turn); await getRtdb().ref("${widget.roomId}/game/diceGreen").set(diceGreen); await getRtdb().ref("${widget.roomId}/game/diceRed").set(diceRed); await getRtdb().ref("${widget.roomId}/game/canMove").set(canMove); await getRtdb().ref("${widget.roomId}/game/gameOver").set(gameOver); } }
  void roll() async { if(gameOver||isRolling) return; if(!isMyTurn) return; if(canMove) return; setState(()=>isRolling=true); _diceController.forward(from: 0); await Future.delayed(Duration(milliseconds: 800)); if(!mounted) return; int d=_rng.nextInt(6)+1; if(d==6){ consecutiveSixes++; if(consecutiveSixes==3){ turn=1-turn; canMove=false; consecutiveSixes=0; isRolling=false; if(turn==0) diceGreen=d; else diceRed=d; setState((){}); await syncRoom(); if(widget.mode==GameMode.bot && turn==1) botTurn(); return; } } else consecutiveSixes=0; if(turn==0) diceGreen=d; else diceRed=d; canMove=true; isRolling=false; setState((){}); await syncRoom(); bool any=false; for(int i=0;i<4;i++) if(isValidMove(turn,i,d)){ any=true; break; } if(!any){ await Future.delayed(Duration(milliseconds: 800)); if(!mounted||gameOver) return; turn=1-turn; canMove=false; setState((){}); await syncRoom(); if(widget.mode==GameMode.bot && turn==1) botTurn(); } }
  void botTurn(){ if(gameOver||!mounted) return; if(turn!=1) return; setState(()=>isRolling=true); _diceController.forward(from: 0); Future.delayed(Duration(milliseconds: 800), (){ if(!mounted) return; int d=_rng.nextInt(6)+1; setState((){ diceRed=d; canMove=true; isRolling=false; }); bool any=false; for(int i=0;i<4;i++) if(isValidMove(1,i,d)){ any=true; break; } if(!any){ Future.delayed(Duration(milliseconds: 500), (){ setState((){ turn=0; canMove=false; }); }); } else { Future.delayed(Duration(milliseconds: 500), (){ int best=-1; for(int i=0;i<4;i++) if(isValidMove(1,i,diceRed)){ best=i; break; } if(best!=-1) moveGoti(best); }); } }); }
  void moveGoti(int idx) async { if(!canMove||gameOver) return; if(!isMyTurn) return; if(!isValidMove(turn,idx,dice)) return; int cur=pos[turn][idx]; int opp=1-turn; if(cur==-1) pos[turn][idx]=startPos[turn]; else if(cur<40){ int dist=(homeEntry[turn]-cur+40)%40; if(dice==dist+1) pos[turn][idx]=40; else { int next=(cur+dice)%40; if(!safe.contains(next)){ for(int k=0;k<4;k++) if(pos[opp][k]==next) pos[opp][k]=-1; } pos[turn][idx]=next; } } else pos[turn][idx]=cur+dice; if(pos[turn].every((v)=>v==45)){ gameOver=true; canMove=false; } else { if(dice!=6) turn=1-turn; canMove=false; } setState((){}); await syncRoom(); if(widget.mode==GameMode.bot && turn==1) Future.delayed(Duration(milliseconds: 600), ()=>botTurn()); }
  Widget dot()=>Container(width: 10,height: 10,decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle));
  Widget emptyDot()=>SizedBox(width: 10,height: 10);
  Widget buildDiceFace(int v){ Widget d=dot(),e=emptyDot(); List<Widget> r1=[e,e,e],r2=[e,e,e],r3=[e,e,e]; if(v==1) r2=[e,d,e]; else if(v==2){ r1=[d,e,e]; r3=[e,e,d]; } else if(v==3){ r1=[d,e,e]; r2=[e,d,e]; r3=[e,e,d]; } else if(v==4){ r1=[d,e,d]; r3=[d,e,d]; } else if(v==5){ r1=[d,e,d]; r2=[e,d,e]; r3=[d,e,d]; } else if(v==6){ r1=[d,e,d]; r2=[d,e,d]; r3=[d,e,d]; } return Container(width: 68,height: 68,decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Padding(padding: EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r1), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r2), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: r3)]))); }
  Offset getHomePathPos(int p,int step,double s){ double r=s*0.25,cx=s/2,cy=s/2; int entry=homeEntry[p]; double ang=(entry/40)*2*pi-pi/2; double ex=cx+r*cos(ang),ey=cy+r*sin(ang); double t=(step+1)/6.0; return Offset(ex+(cx-ex)*t, ey+(cy-ey)*t); }
  Widget goti(int p,int t,double s){ int v=pos[p][t]; double boxSize=s*0.14,pad=s*0.02; Offset o; if(v==-1){ if(p==0){ double bx=10+pad,by=10+pad; o=Offset(bx+(t%2)*(boxSize/2.2), by+(t~/2)*(boxSize/2.2)); } else { double bx=s-10-boxSize+pad,by=s-10-boxSize+pad; o=Offset(bx+(t%2)*(boxSize/2.2), by+(t~/2)*(boxSize/2.2)); } } else if(v==45){ o=Offset(s/2+(t%2==0?-8:8), s/2+(t<2?-8:8)); } else if(v>=40){ o=getHomePathPos(p,v-40,s); } else { double r=s*0.25,ang=(v/40)*2*pi-pi/2; o=Offset(s/2+r*cos(ang), s/2+r*sin(ang)); } bool act=p==turn && canMove && isValidMove(p,t,dice) &&!gameOver && isMyTurn; return Positioned(left: o.dx-11, top: o.dy-11, child: GestureDetector(onTap: act?()=>moveGoti(t):null, child: Container(width: act?28:20, height: act?28:20, decoration: BoxDecoration(color: p==0?Colors.green:Colors.red, shape: BoxShape.circle, border: Border.all(color: act?Colors.yellow:Colors.white, width: act?2.5:1.5))))); }
  @override Widget build(BuildContext context){
    double s=(MediaQuery.of(context).size.width<400?MediaQuery.of(context).size.width:400)-20; double box=s*0.14;
    String titleName=widget.mode==GameMode.offline? "$myName vs Dost" : widget.mode==GameMode.bot? "$myName vs $p1Name" : "$p0Name vs $p1Name";
    String turnName=widget.mode==GameMode.offline? (turn==0?myName:"Dost") : widget.mode==GameMode.bot? (turn==0?myName:p1Name) : (turn==0?p0Name:p1Name);
    return Scaffold(backgroundColor: Color(0xFF0A0E1A), appBar: AppBar(backgroundColor: Color(0xFF151A2B), title: Text("ROOM ${widget.roomId} - $titleName", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)), actions: [IconButton(icon: Icon(showChat?Icons.close:Icons.chat, color: Colors.amber), onPressed: ()=>setState(()=>showChat=!showChat))]),
      body: Column(children: [
        Container(margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Turn: $turnName", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)), Text(isMyTurn?"YOUR TURN - TAP DICE":"WAIT - $turnName", style: TextStyle(fontSize: 11, color: isMyTurn?Colors.greenAccent:Colors.white54, fontWeight: FontWeight.bold))])),
        Expanded(child: Center(child: Container(width: s, height: s, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFF9C4), Color(0xFFE1F5FE), Color(0xFFFCE4EC)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.amber, width: 4)), child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 10, top: 10, width: box, height: box, child: Container(decoration: BoxDecoration(color: Color(0xFFC8E6C9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green, width: 3)))),
          Positioned(right: 10, bottom: 10, width: box, height: box, child: Container(decoration: BoxDecoration(color: Color(0xFFFFCDD2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 3)))),
          Positioned(left: 8, top: box+8, child: GestureDetector(onTap: turn==0 &&!canMove &&!isRolling && isMyTurn? roll : null, child: AnimatedBuilder(animation: _diceController, builder: (c,child){ double a=(isRolling && turn==0)? _diceController.value*4*pi:0; return Transform.rotate(angle: a, child: child); }, child: buildDiceFace(diceGreen)))),
          Positioned(right: 8, bottom: box+8, child: GestureDetector(onTap: turn==1 &&!canMove &&!isRolling && isMyTurn? roll : null, child: AnimatedBuilder(animation: _diceController, builder: (c,child){ double a=(isRolling && turn==1)? _diceController.value*4*pi:0; return Transform.rotate(angle: a, child: child); }, child: buildDiceFace(diceRed)))),
          goti(0,0,s),goti(0,1,s),goti(0,2,s),goti(0,3,s),goti(1,0,s),goti(1,1,s),goti(1,2,s),goti(1,3,s),
        ])))),
        Container(margin: EdgeInsets.fromLTRB(10,5,10,10), padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(20), border: Border.all(color: turn==0?Colors.green:Colors.red, width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.casino, color: turn==0?Colors.green:Colors.red, size: 16), SizedBox(width: 6), Text("${turnName} KI BAARI ${isMyTurn?"(TAP DICE)":""}", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])),
        if(showChat) Container(height: 320, decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Column(children: [
          Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("CHAT - $titleName", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)), GestureDetector(onTap: ()=>setState(()=>showChat=false), child: Icon(Icons.close)) ])),
          Expanded(child: ListView.builder(padding: EdgeInsets.all(10), itemCount: chatMessages.length, itemBuilder: (c,i){ var m=chatMessages[i]; bool isMe=m['player']==myName; return Align(alignment: isMe?Alignment.centerRight:Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical: 4), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isMe?Colors.green:Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text("${m['player']}: ${m['msg']}", style: TextStyle(fontSize: 13, color: Colors.white)))); })),
          Container(padding: EdgeInsets.all(10), child: Row(children: [Expanded(child: TextField(controller: chatCtrl, onSubmitted: (_)=>sendMessage(), style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type message...", filled: true, fillColor: Color(0xFF2A2A3E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))), SizedBox(width: 10), GestureDetector(onTap: sendMessage, child: Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: Icon(Icons.send, color: Colors.black)))])),
        ]))
      ]),
      floatingActionButton: showChat?null:FloatingActionButton.small(backgroundColor: Colors.amber, onPressed: ()=>setState(()=>showChat=!showChat), child: Icon(Icons.chat, color: Colors.black)),
    );
  }
}
