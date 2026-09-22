import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String agoraAppId = "0772d1c90f7646a0a2d5649a41cf7632";

enum GameMode { offline1v1, vsLaddi, online }

class LudoGame extends StatefulWidget {
  final GameMode gameMode;
  final String? roomId;
  final bool isCreator;
  const LudoGame({super.key, required this.gameMode, this.roomId, this.isCreator = false});
  @override
  State<LudoGame> createState() => _LudoGameState();
}

class _LudoGameState extends State<LudoGame> {
  late RtcEngine agoraEngine;
  bool isAgoraJoined = false;
  bool isMicOn = true;
  bool isSpeakerOn = true;
  int currentPlayer = 0;
  int diceValue = 1;
  bool canRoll = true;
  List<List<int>> gotiPos = List.generate(4, (_) => List.filled(4, -1));
  List<List<bool>> gotiHome = List.generate(4, (_) => List.filled(4, false));
  Random random = Random();
  DatabaseReference? roomRef; StreamSubscription? roomSub;
  @override
  void initState() {
    super.initState();
    initAgora();
    initGame();
    if (widget.gameMode == GameMode.online && widget.roomId!= null) {
      setupOnline();
      joinVoice(widget.roomId!);
    }
  }
  Future<void> initAgora() async {
    await [Permission.microphone].request();
    agoraEngine = createAgoraRtcEngine();
    await agoraEngine.initialize(RtcEngineContext(appId: agoraAppId));
    await agoraEngine.enableAudio();
    await agoraEngine.setEnableSpeakerphone(true);
  }
  Future<void> joinVoice(String roomId) async {
    try {
      await agoraEngine.joinChannel(token: "", channelId: roomId, uid: 0, options: const ChannelMediaOptions(clientRoleType: ClientRoleType.clientRoleBroadcaster, channelProfile: ChannelProfileType.channelProfileCommunication,),);
      isAgoraJoined = true;
    } catch (e) { debugPrint("Agora join error $e"); }
  }
  void toggleMic() async { setState(() => isMicOn =!isMicOn); await agoraEngine.muteLocalAudioStream(!isMicOn); }
  void toggleSpeaker() async { setState(() => isSpeakerOn =!isSpeakerOn); await agoraEngine.setEnableSpeakerphone(isSpeakerOn); }
  void initGame() {}
  void setupOnline() { roomRef = FirebaseDatabase.instance.ref("ludo_rooms/${widget.roomId}"); }
  void rollDice() { if (!canRoll) return; setState(() { diceValue = random.nextInt(6) + 1; canRoll = false; }); }
  @override
  void dispose() { roomSub?.cancel(); if (isAgoraJoined) { agoraEngine.leaveChannel(); agoraEngine.release(); } super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Colors.amber, title: Text(widget.roomId!= null? "ROOM ${widget.roomId}" : "LUDO PREMIUM"), actions: [IconButton(icon: Icon(isMicOn? Icons.mic : Icons.mic_off, color: isMicOn? Colors.black : Colors.red), onPressed: toggleMic,), IconButton(icon: Icon(isSpeakerOn? Icons.volume_up : Icons.volume_off, color: Colors.black), onPressed: toggleSpeaker,),],),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Dice: $diceValue", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)), const SizedBox(height: 20), ElevatedButton(onPressed: rollDice, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("ROLL DICE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))), const SizedBox(height: 20), Text("Mic: ${isMicOn? 'ON' : 'OFF'} | Speaker: ${isSpeakerOn? 'ON' : 'OFF'}", style: const TextStyle(color: Colors.white54)), const SizedBox(height: 10), Text("Agora Channel: ${widget.roomId?? 'OFFLINE'}", style: const TextStyle(color: Colors.white30, fontSize: 10)),],),),
    );
  }
}