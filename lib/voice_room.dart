import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:http/http.dart' as http;
import 'main.dart';

// ================= CONFIG =================
const String voiceRoomAppId = "023565215b9e4722b8fff10c0340c699";
const String voiceRoomTokenServer = "https://patient-wave-cb8c.rohitsinghindian91.workers.dev";

int makeVoiceUid(String mobile) {
  final d = mobile.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length >= 6) {
    final u = int.tryParse(d.substring(d.length - 6));
    if (u!= null && u > 0) return u;
  }
  return 100000 + (DateTime.now().millisecondsSinceEpoch % 900000);
}

// Token saaf karne wala helper - Worker plain text de ya JSON {"token":"..."} de ya quotes me de, teeno chalega
String cleanVoiceToken(String body) {
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

Future<String> fetchVoiceToken(String channel, int uid) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final res = await http
       .get(Uri.parse("$voiceRoomTokenServer/?channel=$channel&uid=$uid"))
       .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final t = cleanVoiceToken(res.body);
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
  }
  return "";
}

String genderSymbol(String g) {
  if (g == "male") return " ♂";
  if (g == "female") return " ♀";
  return "";
}

// Room number HAMESHA same = USER KA PERMANENT ID NUMBER (7 digit)
// Firestore (pakka) + phone cache (double lock). Login mobile se, lekin ID ye number hai.
Future<String> getOrCreateRoomNo(String mobile) async {
  if (mobile.isEmpty) throw Exception("Login nahi hai");
  final cacheKey = "voice_room_no_$mobile";
  try {
    final doc = await FirebaseFirestore.instance.collection("users").doc(mobile).get();
    var no = doc.data()?["voiceRoomNo"]?.toString();
    if (no!= null && no.isNotEmpty) {
      try { await prefs.setString(cacheKey, no); } catch (_) {}
      return no;
    }
  } catch (_) {}
  try {
    final cached = prefs.getString(cacheKey);
    if (cached!= null && cached.isNotEmpty) {
      try { await FirebaseFirestore.instance.collection("users").doc(mobile).set({"voiceRoomNo": cached}, SetOptions(merge: true)); } catch (_) {}
      return cached;
    }
  } catch (_) {}
  final rnd = Random();
  String no;
  while (true) {
    no = (1000000 + rnd.nextInt(9000000)).toString();
    try {
      final snap = await FirebaseDatabase.instance.ref("vRooms/$no/info").get();
      if (!snap.exists) break;
    } catch (_) { break; }
  }
  try { await FirebaseFirestore.instance.collection("users").doc(mobile).set({"voiceRoomNo": no}, SetOptions(merge: true)); } catch (_) {}
  try { await prefs.setString(cacheKey, no); } catch (_) {}
  return no;
}

// ================= LOBBY =================
class VoiceLobbyScreen extends StatefulWidget {
  const VoiceLobbyScreen({super.key});
  @override
  State<VoiceLobbyScreen> createState() => _VoiceLobbyScreenState();
}

class _VoiceLobbyScreenState extends State<VoiceLobbyScreen> {
  final codeCtrl = TextEditingController();
  bool creating = false;

  void joinRoom(String no) {
    no = no.trim();
    if (no.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room number dalo")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomNo: no)));
  }

  Future<void> openMyRoom() async {
    setState(() => creating = true);
    try {
      final mobile = prefs.getString("mobile")?? "";
      final no = await getOrCreateRoomNo(mobile);
      if (!mounted) return;
      setState(() => creating = false);
      joinRoom(no);
    } catch (e) {
      if (!mounted) return;
      setState(() => creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A12),
      appBar: AppBar(title: const Text("Voice Chat Rooms"), backgroundColor: const Color(0xFF1A0A12)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.mic, size: 60, color: Colors.amber),
          const SizedBox(height: 8),
          const Text("Apna room banao ya kisi ke room me jao",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: creating? null : openMyRoom,
              icon: creating
               ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_home, color: Colors.black),
              label: const Text("MY ROOM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 7,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                    hintText: "7-digit room number",
                    hintStyle: const TextStyle(color: Colors.white30),
                    counterText: "",
                    filled: true,
                    fillColor: const Color(0xFF2A1420),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => joinRoom(codeCtrl.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("JOIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 20),
          const Text("Live Rooms", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref("vRoomList").onValue,
              builder: (ctx, snap) {
                final rooms = <Map<String, dynamic>>[];
                final val = snap.data?.snapshot.value;
                if (val is Map) {
                  val.forEach((k, v) {
                    if (v is Map) rooms.add({"no": k.toString(), "name": (v["name"]?? "?").toString(), "online": v["online"]?? 0});
                  });
                }
                if (rooms.isEmpty) return const Center(child: Text("Koi live room nahi", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (c, i) {
                    final r = rooms[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFF2A1420), borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange]), shape: BoxShape.circle),
                            child: const Icon(Icons.casino_rounded, color: Colors.black, size: 20)),
                        title: Text(r["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("ID:${r["no"]} - ${r["online"]} online", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                        onTap: () => joinRoom(r["no"]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ================= MODELS =================
class _Seat {
  final int index;
  final bool locked;
  final bool micLocked;
  final int uid;
  final String mobile;
  final String name;
  final String role;
  final String gender;
  final String idNo;
  final bool muted;
  bool get empty => mobile.isEmpty;
  _Seat({required this.index, this.locked = false, this.micLocked = false, this.uid = 0, this.mobile = "", this.name = "", this.role = "visitor", this.gender = "", this.idNo = "", this.muted = false});
}

class _Present {
  final int uid;
  final String name;
  final String mobile;
  final String role;
  final String gender;
  final String idNo;
  _Present({required this.uid, required this.name, required this.mobile, required this.role, this.gender = "", this.idNo = ""});
}

class _ChatMsg {
  final String name;
  final String mobile;
  final String text;
  final String role;
  final int at;
  _ChatMsg({required this.name, required this.mobile, required this.text, required this.role, required this.at});
}

// ================= VOICE ROOM =================
class VoiceRoomScreen extends StatefulWidget {
  final String roomNo;
  const VoiceRoomScreen({super.key, required this.roomNo});
  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> with SingleTickerProviderStateMixin {
  RtcEngine? engine;
  late int myUid;
  late String myName;
  late String myMobile;
  String myRole = "visitor";
  String myGender = "";
  String myIdNo = "";
  int _seatGuardUntil = 0;
  String roomName = "...";
  String ownerMobile = "";
  bool joined = false;
  bool micOn = true;
  bool speakerOn = true;
  String status = "Checking...";
  List<_Seat> seats = List.generate(10, (i) => _Seat(index: i));
  List<_Present> present = [];
  List<_ChatMsg> chats = [];
  Set<int> speaking = {};
  int mySeat = -1;
  late TabController tabCtrl;
  final chatCtrl = TextEditingController();
  final chatScroll = ScrollController();

  StreamSubscription<DatabaseEvent>? seatsSub;
  StreamSubscription<DatabaseEvent>? presentSub;
  StreamSubscription<DatabaseEvent>? chatSub;
  StreamSubscription<DatabaseEvent>? roleSub;
  StreamSubscription<DatabaseEvent>? kickSub;
  StreamSubscription<DatabaseEvent>? inviteSub;
  DatabaseReference? myPresentRef;

  DatabaseReference get roomRef => FirebaseDatabase.instance.ref("vRooms/${widget.roomNo}");
  bool get isOwner => myRole == "owner";
  bool get isAdmin => myRole == "admin" || isOwner;

  @override
  void initState() {
    super.initState();
    tabCtrl = TabController(length: 2, vsync: this);
    myMobile = prefs.getString("mobile")?? "";
    myName = prefs.getString("name")?? "Guest";
    myUid = makeVoiceUid(myMobile);
    _enter();
  }

  Future<void> _enter() async {
    try { FirebaseDatabase.instance.goOnline(); } catch (_) {}
    setState(() => status = "Kick check...");
    final kickSnap = await roomRef.child("kicks/$myMobile").get();
    if (kickSnap.exists) {
      final k = Map<String, dynamic>.from(kickSnap.value as Map);
      final until = (k["until"]?? 0) as int;
      if (until == -1 || until > DateTime.now().millisecondsSinceEpoch) {
        if (!mounted) return;
        final by = k["byName"]?? "owner";
        showDialog(barrierDismissible: false, context: context, builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2A1420),
          title: const Text("Kick Out", style: TextStyle(color: Colors.red)),
          content: Text(until == -1? "$by ne tumhe hamesha ke liye kick kiya hai" : "$by ne tumhe kick kiya hai",
              style: const TextStyle(color: Colors.white)),
          actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("OK"))],
        ));
        setState(() => status = "Kicked out");
        return;
      } else {
        await roomRef.child("kicks/$myMobile").remove();
      }
    }
    setState(() => status = "Room load...");
    final infoSnap = await roomRef.child("info").get();
    if (!infoSnap.exists) {
      await roomRef.child("info").set({
        "name": myName, "ownerMobile": myMobile, "ownerName": myName,
        "createdAt": ServerValue.timestamp,
      });
      await roomRef.child("roles/$myMobile").set({"role": "owner", "name": myName});
    }
    final info = Map<String, dynamic>.from((await roomRef.child("info").get()).value as Map);
    ownerMobile = (info["ownerMobile"]?? "").toString();
    if (!mounted) return;
    setState(() => roomName = (info["name"]?? info["ownerName"]?? "?").toString());

    final roleSnap = await roomRef.child("roles/$myMobile").get();
    if (roleSnap.exists) {
      final rm = Map<String, dynamic>.from(roleSnap.value as Map);
      myRole = (rm["role"]?? "visitor").toString();
      myGender = (rm["gender"]?? "").toString();
    } else if (myMobile == ownerMobile) {
      myRole = "owner";
      await roomRef.child("roles/$myMobile").set({"role": "owner", "name": myName});
    }
    if (myGender.isEmpty) {
      try {
        final u = await FirebaseFirestore.instance.collection("users").doc(myMobile).get();
        myGender = u.data()?["gender"]?.toString()?? "";
        if (myGender.isNotEmpty) {
          try { await roomRef.child("roles/$myMobile").update({"gender": myGender}); } catch (_) {}
        }
      } catch (_) {}
    }
    // MERA PERMANENT ID NUMBER lao (yehi room number hai)
    try { myIdNo = await getOrCreateRoomNo(myMobile); } catch (_) {}

    _listenAll();
    await _joinAgora();
    myPresentRef = roomRef.child("visitors/$myUid");
    await myPresentRef!.set({"name": myName, "mobile": myMobile, "idNo": myIdNo, "at": ServerValue.timestamp});
    myPresentRef!.onDisconnect().remove();
    await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}").update({"name": roomName, "id": widget.roomNo});
    await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}/online").runTransaction((v) => Transaction.success(((v as int?)?? 0) + 1));
  }

  void _listenAll() {
    seatsSub = roomRef.child("seats").onValue.listen((e) {
      if (!mounted) return;
      final list = List.generate(10, (i) => _Seat(index: i));
      final val = e.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          final i = int.tryParse(k.toString());
          if (i!= null && i >= 0 && i < 10 && v is Map) {
            final m = Map<String, dynamic>.from(v);
            list[i] = _Seat(
              index: i,
              locked: m["locked"] == true,
              micLocked: m["micLocked"] == true,
              uid: (m["uid"]?? 0) as int,
              mobile: (m["mobile"]?? "").toString(),
              name: (m["name"]?? "").toString(),
              role: (m["role"]?? "visitor").toString(),
              gender: (m["gender"]?? "").toString(),
              idNo: (m["idNo"]?? "").toString(),
              muted: m["muted"] == true,
            );
          }
        });
      }
      final found = list.indexWhere((s) => s.mobile == myMobile && s.mobile.isNotEmpty);
      // SEAT RACE FIX: baithne/uthne ke 3 sec tak purana Firebase data mySeat ko wapas na badle
      if (DateTime.now().millisecondsSinceEpoch > _seatGuardUntil && found!= mySeat) mySeat = found;
      setState(() => seats = list);
      if (mySeat >= 0) {
        final s = seats[mySeat];
        if ((s.micLocked || s.muted) && micOn) {
          micOn = false;
          engine?.muteLocalAudioStream(true);
          if (s.micLocked) _toast("Tumhara mic lock kar diya gaya");
        }
      }
      _applyPublish();
    });

    presentSub = roomRef.child("visitors").onValue.listen((e) async {
      if (!mounted) return;
      final list = <_Present>[];
      final val = e.snapshot.value;
      if (val is Map) {
        final rolesSnap = await roomRef.child("roles").get();
        final roles = <String, String>{};
        final genders = <String, String>{};
        if (rolesSnap.exists && rolesSnap.value is Map) {
          (rolesSnap.value as Map).forEach((k, v) {
            if (v is Map) {
              final vm = Map<String, dynamic>.from(v);
              roles[k.toString()] = (vm["role"]?? "visitor").toString();
              genders[k.toString()] = (vm["gender"]?? "").toString();
            }
          });
        }
        val.forEach((k, v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            final mob = (m["mobile"]?? "").toString();
            list.add(_Present(uid: int.tryParse(k.toString())?? 0, name: (m["name"]?? "?").toString(), mobile: mob, role: roles[mob]?? "visitor", gender: genders[mob]?? "", idNo: (m["idNo"]?? "").toString()));
          }
        });
      }
      if (mounted) setState(() => present = list);
    });

    chatSub = roomRef.child("chat").limitToLast(50).onValue.listen((e) {
      if (!mounted) return;
      final list = <_ChatMsg>[];
      val = e.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            list.add(_ChatMsg(name: (m["name"]?? "?").toString(), mobile: (m["mobile"]?? "").toString(),
                text: (m["text"]?? "").toString(), role: (m["role"]?? "").toString(), at: (m["at"]?? 0) as int));
          }
        });
      }
      list.sort((a, b) => a.at.compareTo(b.at));
      setState(() => chats = list);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (chatScroll.hasClients) chatScroll.jumpTo(chatScroll.position.maxScrollExtent);
      });
    });

    roleSub = roomRef.child("roles/$myMobile").onValue.listen((e) {
      if (!mounted) return;
      if (e.snapshot.exists) {
        final rm = Map<String, dynamic>.from(e.snapshot.value as Map);
        final r = (rm["role"]?? "visitor").toString();
        final g = (rm["gender"]?? "").toString();
        if (g!= myGender) setState(() => myGender = g);
        if (r!= myRole) { setState(() => myRole = r); _toast("Tumhara role: $r"); }
      } else if (myRole!= "visitor" && myMobile!= ownerMobile) {
        setState(() => myRole = "visitor"); _toast("Tumhara role hata diya gaya");
      }
    });

    kickSub = roomRef.child("kicks/$myMobile").onValue.listen((e) {
      if (!mounted ||!e.snapshot.exists) return;
      final k = Map<String, dynamic>.from(e.snapshot.value as Map);
      final until = (k["until"]?? 0) as int;
      if (until == -1 || until > DateTime.now().millisecondsSinceEpoch) {
        _toast("Tumhe kick kar diya gaya!");
        _leave();
      }
    });

    inviteSub = roomRef.child("invites/$myMobile").onValue.listen((e) {
      if (!mounted ||!e.snapshot.exists) return;
      final m = Map<String, dynamic>.from(e.snapshot.value as Map);
      final seat = (m["seat"]?? -1) as int;
      final by = (m["byName"]?? "?").toString();
      roomRef.child("invites/$myMobile").remove();
      if (seat < 0 || seat > 9 || mySeat >= 0) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1420),
        title: const Text("Seat Invite", style: TextStyle(color: Colors.amber)),
        content: Text("$by ne tumhe seat ${seat + 1} pe bulaya hai", style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Mana karo")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _sitOn(seat); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text("Baith jao", style: TextStyle(color: Colors.black))),
        ],
      ));
    });
  }

  Future<void> _joinAgora() async {
    setState(() => status = "Mic permission...");
    await [Permission.microphone].request();
    if (!mounted) return;
    try { await engine?.leaveChannel(); } catch (_) {}
    try { await engine?.release(); } catch (_) {}
    engine = null;
    setState(() => status = "Token...");
    final token = await fetchVoiceToken("voiceroom_${widget.roomNo}", myUid);
    if (!mounted) return;
    if (token.isEmpty) { setState(() => status = "Token nahi mila - Worker check karo"); return; }
    try {
      engine = createAgoraRtcEngine();
      await engine!.initialize(RtcEngineContext(appId: voiceRoomAppId));
      await engine!.enableAudio();
      await engine!.setEnableSpeakerphone(true);
      await engine!.enableAudioVolumeIndication(interval: 300, smooth: 3, reportVad: true);
      engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (c, e) { if (mounted) setState(() { joined = true; status = "Connected"; }); },
        onAudioVolumeIndication: (c, speakers, t, vad) {
          if (!mounted) return;
          final s = <int>{};
          for (var sp in speakers) { if ((sp.volume?? 0) > 5) s.add(sp.uid == 0? myUid : sp.uid!); }
          setState(() => speaking = s);
        },
        onError: (err, msg) { if (mounted) setState(() => status = "Agora error $err: $msg"); },
        onTokenPrivilegeWillExpire: (c, tok) async {
          final nt = await fetchVoiceToken("voiceroom_${widget.roomNo}", myUid);
          if (nt.isNotEmpty) { try { await engine?.renewToken(nt); } catch (_) {} }
        },
      ));
      setState(() => status = "Joining...");
      try {
        await engine!.joinChannel(
          token: token,
          channelId: "voiceroom_${widget.roomNo}",
          uid: myUid,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            autoSubscribeAudio: true,
            publishMicrophoneTrack: false,
          ),
        );
      } on AgoraRtcException {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await engine!.joinChannel(
          token: token,
          channelId: "voiceroom_${widget.roomNo}",
          uid: myUid,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            autoSubscribeAudio: true,
            publishMicrophoneTrack: false,
          ),
        );
      }
    } on AgoraRtcException catch (e) {
      if (mounted) setState(() => status = "Join failed (${e.code}) - token/Worker check karo");
      try { await engine?.release(); } catch (_) {}
      engine = null;
    } catch (e) {
      if (mounted) setState(() => status = "Failed: $e");
    }
  }

  Future<void> _applyPublish() async {
    if (engine == null) return;
    if (mySeat >= 0) {
      await engine!.updateChannelMediaOptions(const ChannelMediaOptions(publishMicrophoneTrack: true));
      await engine!.muteLocalAudioStream(!micOn);
    } else {
      await engine!.updateChannelMediaOptions(const ChannelMediaOptions(publishMicrophoneTrack: false));
    }
  }

  // SEAT FIX: transaction + race guard - dobara baithna hamesha kaam karega
  Future<void> _sitOn(int i) async {
    if (mySeat >= 0) { _toast("Pehle apni seat chhodo"); return; }
    _seatGuardUntil = DateTime.now().millisecondsSinceEpoch + 3000;
    final ref = roomRef.child("seats/$i");
    try {
      final res = await ref.runTransaction((current) {
        if (current!= null) {
          final m = Map<String, dynamic>.from(current as Map);
          if ((m["mobile"]?? "").toString().isNotEmpty) return Transaction.abort();
          if (m["locked"] == true) return Transaction.abort();
        }
        final prevMicLock = current is Map? (Map<String, dynamic>.from(current as Map)["micLocked"] == true) : false;
        return Transaction.success({
          "locked": false, "micLocked": prevMicLock, "uid": myUid, "mobile": myMobile,
          "name": myName, "role": myRole, "gender": myGender, "idNo": myIdNo,
          "muted":!micOn, "at": DateTime.now().millisecondsSinceEpoch,
        });
      });
      if (res.committed) {
        setState(() => mySeat = i);
        _applyPublish();
      } else {
        _toast("Seat nahi mili, dobara try karo");
      }
    } catch (e) {
      _toast("Seat error: $e");
    }
  }

  Future<void> _leaveSeat() async {
    if (mySeat < 0) return;
    final idx = mySeat;
    setState(() => mySeat = -1);
    _seatGuardUntil = DateTime.now().millisecondsSinceEpoch + 3000;
    _applyPublish();
    try { await roomRef.child("seats/$idx").remove(); } catch (_) {}
  }

  Future<void> _toggleMic() async {
    if (mySeat >= 0 && seats[mySeat].micLocked) { _toast("Mic lock hai"); return; }
    setState(() => micOn =!micOn);
    if (mySeat >= 0) {
      await engine?.muteLocalAudioStream(!micOn);
      try { await roomRef.child("seats/$mySeat").update({"muted":!micOn}); } catch (_) {}
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() => speakerOn =!speakerOn);
    await engine?.setEnableSpeakerphone(speakerOn);
  }

  Future<void> _setRole(String mobile, String name, String role) async {
    await roomRef.child("roles/$mobile").update({"role": role, "name": name});
    final si = seats.indexWhere((s) => s.mobile == mobile);
    if (si >= 0) { try { await roomRef.child("seats/$si").update({"role": role}); } catch (_) {} }
    _toast("$name -> $role");
  }

  Future<void> _removeRole(String mobile, String name) async {
    await roomRef.child("roles/$mobile").remove();
    final si = seats.indexWhere((s) => s.mobile == mobile);
    if (si >= 0) { try { await roomRef.child("seats/$si").update({"role": "visitor"}); } catch (_) {} }
    _toast("$name ka role hataya");
  }

  Future<void> _lockSeat(int i, bool lock) async {
    await roomRef.child("seats/$i").update({"locked": lock});
    _toast(lock? "Seat lock" : "Seat unlock");
  }

  Future<void> _lockMic(int i, bool lock) async {
    final upd = <String, dynamic>{"micLocked": lock};
    if (lock) upd["muted"] = true;
    await roomRef.child("seats/$i").update(upd);
    _toast(lock? "Mic lock" : "Mic unlock");
  }

  Future<void> _removeFromSeat(int i) async {
    await roomRef.child("seats/$i").remove();
    _toast("Seat se hataya");
  }

  Future<void> _inviteToSeat(String mobile, int i) async {
    await roomRef.child("invites/$mobile").set({"seat": i, "by": myMobile, "byName": myName, "at": ServerValue.timestamp});
    _toast("Invite bheja");
  }

  Future<void> _kick(String mobile, String name, int days) async {
    final until = days < 0? -1 : DateTime.now().millisecondsSinceEpoch + days * 86400000;
    await roomRef.child("kicks/$mobile").set({
      "name": name, "by": myMobile, "byName": myName, "until": until, "at": ServerValue.timestamp,
    });
    final si = seats.indexWhere((s) => s.mobile == mobile);
    if (si >= 0) await roomRef.child("seats/$si").remove();
    _toast("$name kick ${days < 0? "forever" : "$days din"}");
  }

  // Voice room se seedha friend request - ID number se pehchan, mobile andar hi rehta hai
  Future<void> _addFriend(String toMobile, String toName) async {
    try {
      final fs = FirebaseFirestore.instance;
      final fr = await fs.collection("users").doc(myMobile).collection("friends").doc(toMobile).get();
      if (fr.exists) { _toast("Pehle se friend hai"); return; }
      final q1 = await fs.collection("friend_requests").where("from", isEqualTo: myMobile).where("to", isEqualTo: toMobile).where("status", isEqualTo: "pending").get();
      final q2 = await fs.collection("friend_requests").where("from", isEqualTo: toMobile).where("to", isEqualTo: myMobile).where("status", isEqualTo: "pending").get();
      if (q1.docs.isNotEmpty || q2.docs.isNotEmpty) { _toast("Request pehle se pending hai"); return; }
      await fs.collection("friend_requests").add({"from": myMobile, "to": toMobile, "fromName": myName, "status": "pending", "time": FieldValue.serverTimestamp()});
      _toast("$toName ko friend request bheji");
    } catch (e) { _toast("Error: $e"); }
  }

  void _chooseGender() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF2A1420),
      title: const Text("Apna gender chuno", style: TextStyle(color: Colors.white)),
      actions: [
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _saveGender("male"); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text("♂ Male", style: TextStyle(color: Colors.white))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _saveGender("female"); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
          child: const Text("♀ Female", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> _saveGender(String g) async {
    setState(() => myGender = g);
    try {
      await roomRef.child("roles/$myMobile").update({"gender": g});
      if (mySeat >= 0) { try { await roomRef.child("seats/$mySeat").update({"gender": g}); } catch (_) {} }
      try { await FirebaseFirestore.instance.collection("users").doc(myMobile).set({"gender": g}, SetOptions(merge: true)); } catch (_) {}
    } catch (_) {}
    _toast(g == "male"? "Gender: Male ♂" : "Gender: Female ♀");
  }

  Future<void> _sendChat() async {
    final t = chatCtrl.text.trim();
    if (t.isEmpty) return;
    chatCtrl.clear();
    await roomRef.child("chat").push().set({
      "name": myName, "mobile": myMobile, "text": t, "role": myRole, "at": ServerValue.timestamp,
    });
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF2A1420),
      title: const Text("Chat saaf karein?", style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Nahi")),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Saaf karo", style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok == true) await roomRef.child("chat").remove();
  }

  Future<void> _leave({bool pop = true}) async {
    try { if (mySeat >= 0) await roomRef.child("seats/$mySeat").remove(); } catch (_) {}
    try { await myPresentRef?.remove(); } catch (_) {}
    try {
      await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}/online").runTransaction((v) {
        final n = ((v as int?)?? 1) - 1;
        return Transaction.success(n < 0? 0 : n);
      });
    } catch (_) {}
    for (var s in [seatsSub, presentSub, chatSub, roleSub, kickSub, inviteSub]) {
      try { await s?.cancel(); } catch (_) {}
    }
    try { await engine?.leaveChannel(); } catch (_) {}
    try { await engine?.release(); } catch (_) {}
    engine = null;
    if (pop && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _leave(pop: false);
    tabCtrl.dispose();
    chatCtrl.dispose();
    chatScroll.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { await _leave(pop: false); return true; },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF2B0F1E), Color(0xFF5C1030), Color(0xFF3D0B22)]),
          ),
          child: SafeArea(
            child: Column(children: [
              _header(),
              _seatsGrid(),
              _tabs(),
              Expanded(
                child: TabBarView(controller: tabCtrl, children: [
                  _chatTab(),
                  _membersTab(),
                ]),
              ),
              _bottomBar(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange]), shape: BoxShape.circle),
          child: const Icon(Icons.casino_rounded, color: Colors.black, size: 30),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(roomName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
            Text("ID:${widget.roomNo}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.block, color: Colors.redAccent),
            tooltip: "Kick list",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _KickListScreen(roomNo: widget.roomNo))),
          ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _leave),
      ]),
    );
  }

  Widget _seatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 8, childAspectRatio: 0.82),
        itemCount: 10,
        itemBuilder: (ctx, i) => _seatTile(seats[i]),
      ),
    );
  }

  Widget _seatTile(_Seat s) {
    final isSpeaking = speaking.contains(s.uid) &&!s.empty;
    final isMe = s.mobile == myMobile && s.mobile.isNotEmpty;
    Widget circle;
    if (s.locked && s.empty) {
      circle = _seatCircle(icon: Icons.lock, bg: Colors.white10, iconColor: Colors.white38);
    } else if (s.empty) {
      circle = _seatCircle(icon: Icons.mic, bg: Colors.white10, iconColor: Colors.white54);
    } else {
      circle = Stack(alignment: Alignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSpeaking? Colors.greenAccent : Colors.transparent, width: 2.5),
            boxShadow: isSpeaking? [BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 10)] : [],
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: isMe? Colors.amber : const Color(0xFF7A4A5E),
            child: Text(s.name.isNotEmpty? s.name[0].toUpperCase() : "?",
                style: TextStyle(color: isMe? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
        ),
        Positioned(bottom: 0, right: 2, child: _roleBadge(s.role)),
        if (s.muted || s.micLocked)
          const Positioned(top: 0, right: 2,
              child: CircleAvatar(radius: 9, backgroundColor: Colors.red,
                  child: Icon(Icons.mic_off, size: 10, color: Colors.white))),
      ]);
    }
    return InkWell(
      onTap: () => _onSeatTap(s),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        circle,
        const SizedBox(height: 2),
        Text(s.empty? "${s.index + 1}" : s.name.split(" ").first + genderSymbol(s.gender),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: s.empty? Colors.white24 : Colors.white, fontSize: 10)),
      ]),
    );
  }

  Widget _seatCircle({required IconData icon, required Color bg, required Color iconColor}) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }

  Widget _roleBadge(String role) {
    if (role == "owner") {
      return const CircleAvatar(radius: 9, backgroundColor: Colors.amber,
          child: Icon(Icons.workspace_premium, size: 10, color: Colors.black));
    }
    if (role == "admin") {
      return const CircleAvatar(radius: 9, backgroundColor: Colors.blue,
          child: Icon(Icons.shield, size: 10, color: Colors.white));
    }
    return const SizedBox.shrink();
  }

  void _onSeatTap(_Seat s) {
    if (s.empty) {
      if (s.locked) { _toast("Seat lock hai"); return; }
      if (isAdmin) { _seatAdminSheet(s); } else { _sitOn(s.index); }
      return;
    }
    _userSheet(name: s.name, mobile: s.mobile, uid: s.uid, role: s.role, gender: s.gender, idNo: s.idNo, seatIndex: s.index, isSeated: true);
  }

  void _seatAdminSheet(_Seat s) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF2A1420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text("Seat ${s.index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.event_seat, color: Colors.amber), title: const Text("Baith jao", style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _sitOn(s.index); }),
          ListTile(leading: Icon(s.locked? Icons.lock_open : Icons.lock, color: Colors.orange),
              title: Text(s.locked? "Seat unlock karo" : "Seat lock karo", style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _lockSeat(s.index,!s.locked); }),
          const SizedBox(height: 8),
        ])));
  }

  void _userSheet({required String name, required String mobile, required int uid, required String role, String gender = "", String idNo = "", int seatIndex = -1, bool isSeated = false}) {
    final isMe = mobile == myMobile;
    final targetIsOwner = role == "owner" || mobile == ownerMobile;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF2A1420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          final items = <Widget>[
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.amber, child: Text(name.isNotEmpty? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              title: Text("$name${genderSymbol(isMe? myGender : gender)} ${_roleTag(role)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(isMe? "ID: $myIdNo" : "ID: ${idNo.isNotEmpty? idNo : "..."}",
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            const Divider(color: Colors.white12),
          ];
          void addTile(IconData icon, Color c, String label, VoidCallback fn) {
            items.add(ListTile(leading: Icon(icon, color: c), title: Text(label, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); fn(); }));
          }

          if (isMe) {
            if (isSeated) addTile(Icons.event_seat, Colors.orange, "Seat se uth jao", () => _leaveSeat());
            addTile(micOn? Icons.mic_off : Icons.mic, Colors.amber, micOn? "Khud ko mute karo" : "Unmute karo", _toggleMic);
            addTile(Icons.wc, Colors.pinkAccent,
                myGender.isEmpty? "Apna gender set karo" : "Gender: ${myGender == "male"? "Male ♂" : "Female ♀"} (badlo)",
                _chooseGender);
          } else {
            addTile(Icons.person_add_alt, Colors.greenAccent, "Add Friend", () => _addFriend(mobile, name));
            if (isOwner) {
              if (!targetIsOwner) {
                if (role!= "admin") addTile(Icons.shield, Colors.blue, "Admin banao", () => _setRole(mobile, name, "admin"));
                if (role!= "member") addTile(Icons.person_add, Colors.green, "Member banao", () => _setRole(mobile, name, "member"));
                if (role == "admin" || role == "member") addTile(Icons.person_remove, Colors.orange, "Role hatao", () => _removeRole(mobile, name));
              }
              if (isSeated) {
                final st = seats[seatIndex];
                addTile(st.micLocked? Icons.mic : Icons.mic_off, Colors.purple, st.micLocked? "Mic unlock karo" : "Mic lock karo",
                    () => _lockMic(seatIndex,!st.micLocked));
                addTile(Icons.event_seat, Colors.orange, "Seat se hatao", () => _removeFromSeat(seatIndex));
              } else {
                addTile(Icons.event_seat, Colors.amber, "Seat pe invite karo", () => _inviteDialog(mobile));
              }
              if (!targetIsOwner) {
                addTile(Icons.block, Colors.red, "Kick - 7 din", () => _kick(mobile, name, 7));
                addTile(Icons.delete_forever, Colors.red, "Kick - Forever", () => _kick(mobile, name, -1));
              }
            } else if (isAdmin) {
              if (!targetIsOwner && role!= "admin") {
                addTile(Icons.block, Colors.red, "Kick - 3 din", () => _kick(mobile, name, 3));
                if (role!= "member") addTile(Icons.person_add, Colors.green, "Member banao", () => _setRole(mobile, name, "member"));
                if (isSeated) {
                  final st = seats[seatIndex];
                  addTile(Icons.mic_off, Colors.purple, st.muted? "Unmute karo" : "Mute karo", () async {
                    await roomRef.child("seats/$seatIndex").update({"muted":!st.muted});
                  });
                } else {
                  addTile(Icons.event_seat, Colors.amber, "Seat pe invite karo", () => _inviteDialog(mobile));
                }
              }
            }
          }
          items.add(const SizedBox(height: 8));
          return SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: items)));
        });
  }

  void _inviteDialog(String mobile) {
    final emptySeats = seats.where((s) => s.empty &&!s.locked).toList();
    if (emptySeats.isEmpty) { _toast("Koi khali seat nahi"); return; }
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF2A1420),
      title: const Text("Kaunsi seat?", style: TextStyle(color: Colors.white)),
      content: Wrap(spacing: 8, children: emptySeats.map((s) =>
          ChoiceChip(label: Text("${s.index + 1}"), selected: false, onSelected: (_) {
            Navigator.pop(context);
            _inviteToSeat(mobile, s.index);
          })).toList()),
    ));
  }

  String _roleTag(String r) {
    if (r == "owner") return "OWNER";
    if (r == "admin") return "ADMIN";
    if (r == "member") return "MEMBER";
    return "";
  }

  Widget _tabs() {
    return TabBar(controller: tabCtrl, indicatorColor: Colors.amber,
        labelColor: Colors.white, unselectedLabelColor: Colors.white38,
        tabs: const [Tab(text: "Chat"), Tab(text: "Members")]);
  }

  Widget _chatTab() {
    return Column(children: [
      Expanded(
        child: chats.isEmpty
         ? const Center(child: Text("Koi chat nahi - pehla message bhejo!", style: TextStyle(color: Colors.white38)))
            : ListView.builder(
                controller: chatScroll,
                padding: const EdgeInsets.all(12),
                itemCount: chats.length,
                itemBuilder: (c, i) {
                  final m = chats[i];
                  final isMe = m.mobile == myMobile;
                  return Align(
                    alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                          color: isMe? Colors.amber.withOpacity(0.25) : Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("${m.name}${m.role.isNotEmpty? " (${m.role.toUpperCase()})" : ""}",
                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ]),
                    ),
                  );
                },
              ),
      ),
      if (isOwner)
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _clearChat,
          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 16),
          label: const Text("Chat saaf karo", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        )),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: chatCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                  hintText: "Type karo...",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true, fillColor: Colors.black.withOpacity(0.35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
              onSubmitted: (_) => _sendChat(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sendChat,
            child: Container(padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.black, size: 18)),
          ),
        ]),
      ),
    ]);
  }

  Widget _membersTab() {
    if (present.isEmpty) return const Center(child: Text("Koi nahi", style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: present.length,
      itemBuilder: (c, i) {
        final p = present[i];
        final seated = seats.any((s) => s.mobile == p.mobile);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Stack(children: [
              CircleAvatar(backgroundColor: p.mobile == myMobile? Colors.amber : const Color(0xFF7A4A5E),
                  child: Text(p.name.isNotEmpty? p.name[0].toUpperCase() : "?",
                      style: TextStyle(color: p.mobile == myMobile? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
              Positioned(bottom: 0, right: 0, child: _roleBadge(p.role)),
            ]),
            title: Text("${p.name}${p.mobile == myMobile? " (Tum)" : ""}${genderSymbol(p.mobile == myMobile? myGender : p.gender)}",
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text("${_roleTag(p.role)}${seated? " - Seat pe" : " - Visitor"} - ID: ${p.idNo.isNotEmpty? p.idNo : "..."}",
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            onTap: () {
              final si = seats.indexWhere((s) => s.mobile == p.mobile);
              _userSheet(name: p.name, mobile: p.mobile, uid: p.uid, role: p.role, gender: p.gender, idNo: p.idNo, seatIndex: si, isSeated: si >= 0);
            },
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Column(children: [
        Text(status, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _bigBtn(icon: micOn? Icons.mic : Icons.mic_off, label: micOn? "Mic" : "Mute",
              active: micOn, onTap: _toggleMic),
          _bigBtn(icon: speakerOn? Icons.volume_up : Icons.volume_off, label: "Speaker",
              active: speakerOn, onTap: _toggleSpeaker),
          _bigBtn(icon: Icons.call_end, label: "Leave", active: false, danger: true, onTap: _leave),
        ]),
      ]),
    );
  }

  Widget _bigBtn({required IconData icon, required String label, required bool active, bool danger = false, required VoidCallback onTap}) {
    final c = danger? Colors.red : (active? Colors.amber : Colors.white24);
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: c, size: 24)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ================= KICK LIST =================
class _KickListScreen extends StatefulWidget {
  final String roomNo;
  const _KickListScreen({required this.roomNo});
  @override
  State<_KickListScreen> createState() => _KickListScreenState();
}

class _KickListScreenState extends State<_KickListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A12),
      appBar: AppBar(title: const Text("Kick List"), backgroundColor: const Color(0xFF1A0E1A)),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref("vRooms/${widget.roomNo}/kicks").onValue,
        builder: (ctx, snap) {
          final list = <Map<String, dynamic>>[];
          final val = snap.data?.snapshot.value;
          if (val is Map) {
            val.forEach((k, v) {
              if (v is Map) {
                final m = Map<String, dynamic>.from(v);
                m["mobile"] = k.toString();
                list.add(m);
              }
            });
          }
          if (list.isEmpty) return const Center(child: Text("Koi kick nahi", style: TextStyle(color: Colors.white54)));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final k = list[i];
              final until = (k["until"]?? 0) as int;
              final forever = until == -1;
              final left = forever? "Forever" : "${((until - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil()} din baki";
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: const Color(0xFF2A1420), borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text((k["name"]?? "?").toString(), style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Kick mara: ${k["byName"]?? "?"} - $left", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () async {
                      await FirebaseDatabase.instance.ref("vRooms/${widget.roomNo}/kicks/${k["mobile"]}").remove();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unkick ho gaya")));
                    },
                    child: const Text("Unkick", style: TextStyle(color: Colors.greenAccent)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
