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

const String agoraAppId = "0772d1c90f7646a0a2d5649a41cf7632";
const String agoraToken = "007eJxTYPh1YfP9e1y2v5p7p5p7p5p7p5p7p5p7p5p7p5p7"; // tera wala token yahan daal de

const String rtdbUrl = "https://ludo-premium-50-default-rtdb.asia-southeast1.firebasedatabase.app";

FirebaseDatabase getRtdb() {
  return FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: rtdbUrl,
  );
}

enum GameMode { online, offline, bot }

class LobbyScreen extends StatefulWidget {
  @override State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final codeCtrl = TextEditingController();
  String genCode() => (Random().nextInt(9000) + 1000).toString();

  void _createRoomWithCodeDialog() async {
    String c = genCode();
    try {
      print("Creating room $c at $rtdbUrl");
      await getRtdb().ref("ludo_rooms/$c/game").set({
        "pos": [[-1,-1,-1,-1], [-1,-1,-1,-1]],
        "turn": 0,
        "diceGreen": 1,
        "diceRed": 1,
        "canMove": false,
        "gameOver": false,
        "createdAt": DateTime.now().millisecondsSinceEpoch
      });
      print("Room $c created SUCCESS");
    } catch(e) {
      debugPrint("Create room error $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Firebase error: $e"), duration: Duration(seconds: 5)));
      return;
    }
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
  }

  void joinRoom() async {
    String code = codeCtrl.text.trim();
    if(code.length!= 4){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("4 digit code dalo")));
      return;
    }
    try {
      var snap = await getRtdb().ref("ludo_rooms/$code/game").get();
      if(!snap.exists){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room $code mila hi nahi")));
        return;
      }
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Join error: $e")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => LudoGame(roomId: code, myPlayer: 1, mode: GameMode.online)));
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

// ... QuickMatchScreen aur LudoGame ka baki code tera wala hi copy-paste kar de, bas upar wala import wala fix important tha