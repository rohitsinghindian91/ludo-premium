import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'main.dart' hide Text;

// ================= CONFIG =================
const String voiceRoomAppId = "abec454452ca4fbba9bbd6296dbf4509";
const String voiceRoomTokenServer = "https://patient-wave-cb8c.rohitsinghindian91.workers.dev";

// Keep-option: minimize karke bahar aane par room yaad rahe
String? minimizedRoomNo;
// Global engine taaki Keep par voice chalu rahe
RtcEngine? globalVoiceEngine;
String? globalVoiceRoom;
int globalVoiceUid = 0;
bool globalMicOn = true;
bool globalSpeakerOn = true;
String tokenDebug = "";

int makeVoiceUid(String mobile) {
  final d = mobile.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length >= 6) {
    final u = int.tryParse(d.substring(d.length - 6));
    if (u!= null && u > 0) return u;
  }
  return 100000 + (DateTime.now().millisecondsSinceEpoch % 900000);
}

String cleanVoiceToken(String body) {
  var t = body.trim();
  if (t.isEmpty) { tokenDebug = "khali response"; return ""; }
  if (t.startsWith("{")) {
    try {
      final m = jsonDecode(t) as Map<String, dynamic>;
      for (final k in ["token", "rtcToken", "rtc_token", "agoraToken", "data"]) {
        final v = m[k]?.toString()?? "";
        if (v.isNotEmpty &&!v.startsWith("{")) { t = v; break; }
      }
      if (t.startsWith("{")) {
        final e = (m["error"]?? m["message"]?? "").toString();
        tokenDebug = e.isNotEmpty? e.substring(0, e.length > 60? 60 : e.length) : "token key nahi mili";
        return "";
      }
    } catch (_) { tokenDebug = "galat JSON"; return ""; }
  }
  t = t.trim();
  if (t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
    t = t.substring(1, t.length - 1).trim();
  }
  if (t.startsWith("<")) { tokenDebug = "HTML mila (token nahi)"; return ""; }
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
      } else {
        tokenDebug = "HTTP ${res.statusCode}";
      }
    } catch (e) {
      tokenDebug = "network fail";
    }
    await Future.delayed(const Duration(seconds: 1));
  }
  return "";
}
bool hasPower(Map<String,dynamic> u, String p){
  return (List<String>.from(u["powers"]?? [])).contains(p);
}
Map<String,dynamic> _cachedMe = {};
String genderSymbol(String g) {
  if (g == "male") return " â™‚";
  if (g == "female") return " â™€";
  return "";
}

// FIX 1: Naam HAMESHA registration wala (Firestore users/mobile -> name)
Future<String> getLockedName(String mobile, String fallback) async {
  if (mobile.isEmpty) return fallback;
  try {
    final doc = await FirebaseFirestore.instance.collection("users").doc(mobile).get();
    final n = doc.data()?["name"]?.toString().trim()?? "";
    if (n.isNotEmpty) {
      try { await prefs.setString("name", n); } catch (_) {}
      return n;
    }
  } catch (_) {}
  return fallback;
}

Future<String> getOrCreateRoomNo(String mobile) async {
  if (mobile.isEmpty) throw Exception("Login nahi hai");
  final cacheKey = "voice_room_no_$mobile";
  try {
    final doc = await FirebaseFirestore.instance.collection("users").doc(mobile).get();
    var no = doc.data()?["voiceRoomNo"]?.toString();
    if (no != null && no.isNotEmpty) {
      try { await prefs.setString(cacheKey, no); } catch (_) {}
      return no; // admin edited value ko priority
    }
  } catch (_) {}
  // ... baki same as before - yahan se continue karo, } mat lagao

  try {
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
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
    minimizedRoomNo = null;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomNo: no)));
  }

  // FIX 3: Keep kiya hua room - wapas jao banner
  void backToRoom() {
    final no = minimizedRoomNo;
    if (no == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomNo: no, rejoin: true)));
  }

  Future<void> openMyRoom() async {
    setState(() => creating = true);
    try {
      final mobile = prefs.getString("mobile")?? "";
      final no = await getOrCreateRoomNo(mobile);
      if (!mounted) return;
      setState(() => creating = false);
      minimizedRoomNo = null;
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
          // FIX 3: minimized room banner
          if (minimizedRoomNo!= null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.headset_mic, color: Colors.white),
                title: Text("Room $minimizedRoomNo me ho",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Tap karke wapas jao", style: TextStyle(color: Colors.white70, fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward, color: Colors.white),
                onTap: backToRoom,
              ),
            ),
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
          Row(children: [
            const Text("Live Rooms", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (minimizedRoomNo!= null)
              TextButton.icon(
                onPressed: backToRoom,
                icon: const Icon(Icons.headset_mic, color: Colors.greenAccent, size: 16),
                label: const Text("Wapas jao", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref("vRoomList").onValue,
              builder: (ctx, snap) {
                final rooms = <Map<String, dynamic>>[];
                final val = snap.data?.snapshot.value;
                if (val is Map) {
                  val.forEach((k, v) {
                    if (v is Map) rooms.add({"no": k.toString(), "name": (v["name"]?? "?").toString(), "online": v["online"]?? 0, "seated": v["seated"]?? 0, "locked": v["locked"] == true});
                  });
                }
                rooms.sort((a, b) => ((b["seated"]?? 0) as int).compareTo((a["seated"]?? 0) as int));
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
                            child: Icon(r["locked"] == true? Icons.lock : Icons.casino_rounded, color: Colors.black, size: 20)),
                        title: Text(r["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("ID:${r["no"]} â€¢ ${r["online"]} online${r["locked"] == true? " â€¢ ðŸ”’ Locked" : ""}",
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
  final String photo;
  final bool muted;
  bool get empty => mobile.isEmpty;
  _Seat({required this.index, this.locked = false, this.micLocked = false, this.uid = 0, this.mobile = "", this.name = "", this.role = "visitor", this.gender = "", this.idNo = "", this.photo = "", this.muted = false});
}

class _Present {
  final int uid;
  final String name;
  final String mobile;
  final String role;
  final String gender;
  final String idNo;
  final String photo;
  _Present({required this.uid, required this.name, required this.mobile, required this.role, this.gender = "", this.idNo = "", this.photo = ""});
}

class _ChatMsg {
  final String key;
  final String name;
  final String mobile;
  final String text;
  final String role;
  final int at;
  final String type; // text | image
  final String imageUrl;
  final String photo;
  final bool viewOnce;
  final Map<String, dynamic> viewedBy;
  _ChatMsg({this.key = "", required this.name, required this.mobile, required this.text, required this.role, required this.at,
    this.type = "text", this.imageUrl = "", this.photo = "", this.viewOnce = false, this.viewedBy = const {}});
}
// ================= VOICE ROOM =================
class VoiceRoomScreen extends StatefulWidget {
  final String roomNo;
  final bool rejoin;
  const VoiceRoomScreen({super.key, required this.roomNo, this.rejoin = false});
  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> with SingleTickerProviderStateMixin {
  RtcEngine? get engine => globalVoiceEngine;
  late int myUid;
  late String myName;
  late String myMobile;
  String myRole = "visitor";
  String myGender = "";
  String myIdNo = "";
  String myPhoto = "";
  int _seatGuardUntil = 0;
  String roomName = "...";
  String ownerMobile = "";
  bool roomLocked = false;
  bool joined = false;
  bool micOn = true;
  bool speakerOn = true;
  bool _keepAlive = false;
  String status = "Checking...";
  int myJoinedAt = 0;
  bool _chatFirstLoad = true;
  Set<String> _oldChatKeys = {};
  String roomNotice = "";
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
  StreamSubscription<DatabaseEvent>? lockSub;
  StreamSubscription<DatabaseEvent>? noticeSub;
  StreamSubscription<DatabaseEvent>? themeSub;
  DatabaseReference? myPresentRef;

  // ===== PK BATTLE (Step 4) =====
  bool inPk = false;
  String pkId = "";
  String pkOpponentRoom = "";
  String pkOpponentName = "";
  int myPkScore = 0;
  int oppPkScore = 0;
  StreamSubscription<DatabaseEvent>? pkSub;
  Timer? pkTimer;
  int pkTimeLeft = 300;
  bool isPkHost = false;


  // ===== STEP 6: VIP FRAMES + ENTRY EFFECTS =====
  int myLevel = 1;
  String myFrame = "none";
  
  int _getLevelFromXp(int xp) {
    if (xp < 100) return 1;
    if (xp < 300) return 2;
    if (xp < 600) return 3;
    if (xp < 1000) return 4;
    if (xp < 1500) return 5;
    if (xp < 2200) return 6;
    if (xp < 3000) return 7;
    if (xp < 4000) return 8;
    if (xp < 5500) return 9;
    return 10 + ((xp - 5500) ~/ 2000);
  }

  Color _getLevelColor(int level) {
    if (level <= 1) return const Color(0xFF9CA3AF);
    if (level <= 3) return const Color(0xFF22C55E);
    if (level <= 5) return const Color(0xFF3B82F6);
    if (level <= 7) return const Color(0xFF8B5CF6);
    if (level <= 9) return const Color(0xFFF59E0B);
    if (level <= 15) return const Color(0xFFEC4899);
    return const Color(0xFFFFD700);
  }

  String _getFrameForLevel(int level) {
    if (level <= 2) return "none";
    if (level <= 4) return "bronze";
    if (level <= 6) return "silver";
    if (level <= 8) return "gold";
    if (level <= 10) return "diamond";
    if (level <= 15) return "royal";
    return "supreme";
  }

  Widget _buildFrameForLevel(int level, Widget child) {
    final frame = _getFrameForLevel(level);
    if (frame == "none") return child;
    
    Color borderColor = _getLevelColor(level);
    double borderWidth = 2;
    List<BoxShadow>? shadows;
    
    if (frame == "bronze") { borderColor = const Color(0xFFCD7F32); borderWidth = 2.5; }
    else if (frame == "silver") { borderColor = const Color(0xFFC0C0C0); borderWidth = 3; shadows = [BoxShadow(color: borderColor.withOpacity(0.5), blurRadius: 8)]; }
    else if (frame == "gold") { borderColor = const Color(0xFFFFD700); borderWidth = 3.5; shadows = [BoxShadow(color: borderColor.withOpacity(0.6), blurRadius: 10)]; }
    else if (frame == "diamond") { borderColor = const Color(0xFF00FFFF); borderWidth = 4; shadows = [BoxShadow(color: borderColor.withOpacity(0.7), blurRadius: 12), BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 16)]; }
    else if (frame == "royal") { borderColor = const Color(0xFF9D00FF); borderWidth = 4.5; shadows = [BoxShadow(color: borderColor.withOpacity(0.8), blurRadius: 15), BoxShadow(color: Colors.pink.withOpacity(0.4), blurRadius: 20)]; }
    else if (frame == "supreme") { borderColor = const Color(0xFFFFD700); borderWidth = 5; shadows = [BoxShadow(color: Colors.amber.withOpacity(0.9), blurRadius: 18), BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 25)]; }

    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: borderWidth), boxShadow: shadows),
      child: child,
    );
  }

  void _showEntryEffect(String userName, int level) {
    if (level < 4) return;
    String effect = "";
    if (level <= 5) effect = "â­";
    else if (level <= 7) effect = "ðŸ”¥";
    else if (level <= 9) effect = "âš¡";
    else if (level <= 15) effect = "ðŸ¦š";
    else effect = "ðŸ‰";

    _toast("$effect $userName (Lv.$level) entered! $effect");
    
    // Show fancy dialog for high levels
    if (level >= 8 && mounted) {
      showDialog(context: context, barrierDismissible: true, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [_getLevelColor(level), _getLevelColor(level).withOpacity(0.5)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30, width: 2)), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(effect, style: const TextStyle(fontSize: 50)),
        const SizedBox(height: 8),
        Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text("Level $level â€¢ ${_getLevelTitle(level)}", style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Text("$effect Welcome! $effect", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]))));
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.of(context, rootNavigator: true).pop(); });
    }
  }

  String _getLevelTitle(int level) {
    if (level <= 1) return "Newbie";
    if (level <= 2) return "Rookie";
    if (level <= 3) return "Explorer";
    if (level <= 4) return "Adventurer";
    if (level <= 5) return "Warrior";
    if (level <= 6) return "Champion";
    if (level <= 7) return "Hero";
    if (level <= 8) return "Legend";
    if (level <= 9) return "Mythic";
    if (level <= 15) return "VIP $level";
    return "SUPREME $level";
  }



  // ===== STEP 7: ROOM THEMES FIXED (using widget.roomNo) =====
  String roomTheme = "default";
  final Map<String, Map<String,dynamic>> _roomThemes = {
    "default": {"name":"Default","color": Color(0xFF4A0E2A),"icon":"ðŸ "},
    "royal": {"name":"Royal Palace","color": Color(0xFF4A1A6B),"icon":"ðŸ‘‘"},
    "beach": {"name":"Beach Party","color": Color(0xFF0E4A6B),"icon":"ðŸ–ï¸"},
    "space": {"name":"Space Station","color": Color(0xFF0A1A3A),"icon":"ðŸš€"},
    "jungle": {"name":"Jungle","color": Color(0xFF1A4A1A),"icon":"ðŸŒ´"},
    "neon": {"name":"Neon City","color": Color(0xFF4A0E4A),"icon":"ðŸŒƒ"},
    "gold": {"name":"Gold Luxury","color": Color(0xFF4A3A0E),"icon":"ðŸ’Ž"},
  };
  Future<void> _loadRoomTheme() async {
    try {
      final snap = await roomRef.child("info/theme").get();
      if (snap.exists && mounted) setState(() => roomTheme = snap.value as String? ?? "default");
    } catch (_) {}
  }
  Future<void> _changeRoomTheme(String newTheme) async {
    try {
      if (!isOwner) { _toast("Only owner can change theme"); return; }
      await roomRef.child("info/theme").set(newTheme);
      if (mounted) setState(() => roomTheme = newTheme);
    } catch (e) { _toast("Theme fail: $e"); }
  }
  void _showThemePicker() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("Room Theme", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 16),
      GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: _roomThemes.length, itemBuilder: (_, i){
        final key = _roomThemes.keys.elementAt(i);
        final theme = _roomThemes[key]!;
        return InkWell(onTap: (){ Navigator.pop(context); _changeRoomTheme(key); }, child: Container(decoration: BoxDecoration(color: theme["color"], borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(theme["icon"], style: const TextStyle(fontSize: 32)), Text(theme["name"], style: const TextStyle(color: Colors.white, fontSize: 11))]))); 
      }),
    ])));
  }



  // ===== STEP 8: VOICE FILTERS + BLOCK/REPORT + FOLLOW =====
  String voiceFilter = "normal";
  final Map<String, Map<String,dynamic>> _voiceFilters = {
    "normal": {"name":"Normal","icon":"ðŸŽ™ï¸"},
    "robot": {"name":"Robot","icon":"ðŸ¤–"},
    "girl": {"name":"Girl Voice","icon":"ðŸ‘§"},
    "boy": {"name":"Boy Voice","icon":"ðŸ‘¦"},
    "echo": {"name":"Echo","icon":"ðŸ”Š"},
    "deep": {"name":"Deep","icon":"ðŸŽ¤"},
  };

  Future<void> _changeVoiceFilter(String filter) async {
    setState(() => voiceFilter = filter);
    _toast("Voice filter: ${_voiceFilters[filter]?["name"]} ${_voiceFilters[filter]?["icon"]}");
    // Actual voice filter would need Agora extension, here we just save preference
    await FirebaseFirestore.instance.collection("users").doc(myMobile).update({"voiceFilter": filter});
  }

  void _showVoiceFilterPicker() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("ðŸŽ™ï¸ Voice Filter Chuno", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 16),
      GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: _voiceFilters.length, itemBuilder: (_, i){
        final key = _voiceFilters.keys.elementAt(i);
        final filter = _voiceFilters[key]!;
        final isSelected = voiceFilter == key;
        return InkWell(onTap: (){ Navigator.pop(context); _changeVoiceFilter(key); }, child: Container(decoration: BoxDecoration(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : Colors.white24, width: isSelected ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(filter["icon"], style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(filter["name"], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ])));
      }),
    ])));
  }

  Future<void> _blockUser(String targetMobile, String targetName) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Block User?", style: TextStyle(color: Colors.white)),
      content: Text("$targetName ko block karna hai? Wo tumhe message nahi bhej payega.", style: const TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text("Cancel")), TextButton(onPressed: ()=> Navigator.pop(context, true), child: const Text("Block", style: TextStyle(color: Colors.red)))],
    ));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection("users").doc(myMobile).collection("blocked").doc(targetMobile).set({
        "id": targetMobile, "name": targetName, "blockedAt": FieldValue.serverTimestamp()
      });
      _toast("$targetName blocked ðŸš«");
    } catch (e) { _toast("Block failed: $e"); }
  }

  Future<void> _reportUser(String targetMobile, String targetName) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Report User", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("$targetName ko report karna hai?", style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        TextField(controller: reasonCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Reason likho...", hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ]),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text("Cancel")), TextButton(onPressed: ()=> Navigator.pop(context, true), child: const Text("Report", style: TextStyle(color: Colors.orange)))],
    ));
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection("reports").add({
        "reporter": myMobile, "reported": targetMobile, "reporterName": myName, "reportedName": targetName,
        "reason": reasonCtrl.text.trim(), "roomNo": widget.roomNo, "at": FieldValue.serverTimestamp()
      });
      _toast("Report sent âœ…");
    } catch (e) { _toast("Report failed: $e"); }
  }

  Future<void> _followUser(String targetMobile, String targetName, String targetPhoto) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(myMobile).collection("following").doc(targetMobile).set({
        "id": targetMobile, "name": targetName, "photoUrl": targetPhoto, "followedAt": FieldValue.serverTimestamp()
      });
      await FirebaseFirestore.instance.collection("users").doc(targetMobile).collection("followers").doc(myMobile).set({
        "id": myMobile, "name": myName, "photoUrl": myPhoto, "followedAt": FieldValue.serverTimestamp()
      });
      _toast("$targetName followed âœ…");
    } catch (e) { _toast("Follow failed: $e"); }
  }


  // ===== GIFT SYSTEM (Step 2) =====
  int myCoins = 0;
  List<Map<String, dynamic>> giftList = [];
  StreamSubscription<DatabaseEvent>? giftSub;
  Set<String> _seenGiftKeys = {};

  DatabaseReference get roomRef => FirebaseDatabase.instance.ref("vRooms/${widget.roomNo}");
  bool get isOwner => myRole == "owner";
  bool get isAdmin => myRole == "admin" || isOwner;

  @override
  Future<void> _loadMyLevel() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(myMobile).get();
      if (doc.exists) {
        final xp = (doc.data()?["xp"] ?? 0) as int;
        if (mounted) setState(() { myLevel = _getLevelFromXp(xp); myFrame = _getFrameForLevel(myLevel); });
      }
    } catch (_) {}
  }

  void initState() {
    super.initState();
    _loadMyLevel();
    tabCtrl = TabController(length: 2, vsync: this);
    myMobile = prefs.getString("mobile")?? "";
    myName = prefs.getString("name")?? "Guest";
    myUid = makeVoiceUid(myMobile);
    if (widget.rejoin) { micOn = globalMicOn; speakerOn = globalSpeakerOn; }
    _enter();
    _loadMyCoins();
    _listenGifts();
    _loadRoomTheme();
  }

  Future<void> _enter() async {
    try { FirebaseDatabase.instance.goOnline(); } catch (_) {}
    // FIX 1: naam hamesha registration wala
    myName = await getLockedName(myMobile, myName);
    if (!widget.rejoin) myJoinedAt = DateTime.now().millisecondsSinceEpoch;
    if (!mounted) return;
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
        "createdAt": ServerValue.timestamp, "locked": false, "roomPassword": "",
      });
      await roomRef.child("roles/$myMobile").set({"role": "owner", "name": myName});
    }
    final info = Map<String, dynamic>.from((await roomRef.child("info").get()).value as Map);
    ownerMobile = (info["ownerMobile"]?? "").toString();
    roomLocked = info["locked"] == true;
    if (!mounted) return;
    setState(() {
      roomName = (info["name"]?? info["ownerName"]?? "?").toString();
      roomNotice = (info["notice"]?? "").toString();
    });

    // FIX: powers pehle load karo - join_locked check ke liye zaroori
    try {
      final me = await FirebaseFirestore.instance.collection("users").doc(myMobile).get();
      _cachedMe = me.data()?? {};
    } catch (_) {}

    // FIX 8: lock room - password check (owner ko nahi, join_locked power walo ko nahi)
    if (roomLocked && myMobile!= ownerMobile &&!widget.rejoin &&!hasPower(_cachedMe, "join_locked")) {
      final ok = await _askRoomPassword();
      if (!ok) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    final roleSnap = await roomRef.child("roles/$myMobile").get();
    if (roleSnap.exists) {
      final rm = Map<String, dynamic>.from(roleSnap.value as Map);
      myRole = (rm["role"]?? "visitor").toString();
      myGender = (rm["gender"]?? "").toString();
      // FIX 1: role me naam bhi lock wala rakho
      if ((rm["name"]?? "").toString()!= myName) {
        try { await roomRef.child("roles/$myMobile").update({"name": myName}); } catch (_) {}
      }
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
    try { myIdNo = await getOrCreateRoomNo(myMobile); } catch (_) {}
    // FIX: Keep karke wapas aaye ho to apni seat mat udao
    if (!widget.rejoin) {
      try {
        final ss = await roomRef.child("seats").get();
        final sv = ss.value;
        Future<void> cleanOne(String key, dynamic v) async {
          if (v is Map && myMobile.isNotEmpty) {
            final m = Map<String, dynamic>.from(v);
            if ((m["mobile"]?? "").toString() == myMobile) {
              await roomRef.child("seats/$key").remove();
              _bumpSeated(-1);
            }
          }
        }
        if (sv is Map) {
          for (final e in sv.entries) { await cleanOne(e.key.toString(), e.value); }
        } else if (sv is List) {
          for (int i = 0; i < sv.length; i++) { await cleanOne(i.toString(), sv[i]); }
        }
      } catch (_) {}
    }

    _listenAll();
    // FIX 3: Keep karke wapas aaye ho to dobara join mat karo
    if (widget.rejoin && globalVoiceEngine!= null && globalVoiceRoom == widget.roomNo) {
      setState(() { joined = true; status = "Connected"; });
      _applyPublish();
    } else {
      await _joinAgora();
    }
    try { final ud = await FirebaseFirestore.instance.collection("users").doc(myMobile).get(); myPhoto = ud.data()?["photoUrl"]?.toString()?? ""; } catch (_) {}
    myPresentRef = roomRef.child("visitors/$myUid");
    await myPresentRef!.set({"name": myName, "mobile": myMobile, "idNo": myIdNo, "photo": myPhoto, "at": ServerValue.timestamp});
    myPresentRef!.onDisconnect().remove();
    await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}").update(
        {"name": roomName, "id": widget.roomNo, "locked": roomLocked});
    await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}/online").runTransaction((v) => Transaction.success(((v as int?)?? 0) + 1));
  }

  // FIX 8: password dialog
  Future<bool> _askRoomPassword() async {
    final ctrl = TextEditingController();
    final res = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1420),
        title: const Text("ðŸ”’ Locked Room", style: TextStyle(color: Colors.amber)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Ye room lock hai. Owner se password lekar dalo.",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: "Password",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Wapas")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text("Join", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    if (res!= true) return false;
    try {
      final snap = await roomRef.child("info/roomPassword").get();
      final pw = snap.value?.toString()?? "";
      if (pw.isNotEmpty && ctrl.text.trim() == pw) return true;
      if (mounted) _toast("Galat password!");
      return false;
    } catch (_) {
      return false;
    }
  }

  // FIX 8: owner lock/unlock
  Future<void> _toggleRoomLock() async {
    if (!isOwner) return;
    if (!roomLocked) {
      final ctrl = TextEditingController();
      final res = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2A1420),
          title: const Text("Room Lock karo", style: TextStyle(color: Colors.amber)),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: "Password set karo",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text("Lock", style: TextStyle(color: Colors.black))),
          ],
        ),
      );
      if (res == null || res.isEmpty) return;
      await roomRef.child("info").update({"locked": true, "roomPassword": res});
      await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}").update({"locked": true});
      setState(() => roomLocked = true);
      _toast("Room lock ho gaya ðŸ”’");
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2A1420),
          title: const Text("Room Unlock karein?", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Nahi")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Unlock", style: TextStyle(color: Colors.white))),
          ],
        ),
      );
      if (ok!= true) return;
      await roomRef.child("info").update({"locked": false, "roomPassword": ""});
      await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}").update({"locked": false});
      setState(() => roomLocked = false);
      _toast("Room unlock ho gaya ðŸ”“");
    }
  }
    void _listenAll() {
    seatsSub = roomRef.child("seats").onValue.listen((e) {
      if (!mounted) return;
      final list = List.generate(10, (i) => _Seat(index: i));
      final val = e.snapshot.value;
      void parseSeat(int i, dynamic v) {
        if (i < 0 || i >= 10 || v is! Map) return;
        final m = Map<String, dynamic>.from(v);
        int u;
        try { u = (m["uid"]?? 0) as int; } catch (_) { u = int.tryParse((m["uid"]?? "0").toString())?? 0; }
        list[i] = _Seat(
          index: i,
          locked: m["locked"] == true,
          micLocked: m["micLocked"] == true,
          uid: u,
          mobile: (m["mobile"]?? "").toString(),
          name: (m["name"]?? "").toString(),
          role: (m["role"]?? "visitor").toString(),
          gender: (m["gender"]?? "").toString(),
          idNo: (m["idNo"]?? "").toString(),
          photo: (m["photo"]?? "").toString(),
          muted: m["muted"] == true,
        );
      }
      if (val is Map) {
        val.forEach((k, v) {
          final i = int.tryParse(k.toString());
          if (i!= null) parseSeat(i, v);
        });
      } else if (val is List) {
        for (int i = 0; i < val.length && i < 10; i++) {
          parseSeat(i, val[i]);
        }
      }
      final found = list.indexWhere((s) => s.mobile == myMobile && s.mobile.isNotEmpty);
      if (DateTime.now().millisecondsSinceEpoch > _seatGuardUntil && found!= mySeat) mySeat = found;
      setState(() => seats = list);
      if (mySeat >= 0) {
        final s = seats[mySeat];
        if ((s.micLocked || s.muted) && micOn) {
          micOn = false;
          globalVoiceEngine?.muteLocalAudioStream(true);
          if (s.micLocked) _toast("Tumhara mic lock kar diya gaya");
        }
      }
      _applyPublish();
    });

    // FIX 7: members me seat wale + visitors sab
    presentSub = roomRef.child("visitors").onValue.listen((e) async {
      if (!mounted) return;
      final list = <_Present>[];
      final seen = <String>{};
      for (final s in seats) {
        if (!s.empty) {
          seen.add(s.mobile);
          list.add(_Present(uid: s.uid, name: s.name, mobile: s.mobile, role: s.role, gender: s.gender, idNo: s.idNo, photo: s.photo));
        }
      }
      final val = e.snapshot.value;
      if (val is Map) {
        final rolesSnap = await roomRef.child("roles").get();
        final roles = <String, String>{};
        final genders = <String, String>{};
        final names = <String, String>{};
        if (rolesSnap.exists && rolesSnap.value is Map) {
          (rolesSnap.value as Map).forEach((k, v) {
            if (v is Map) {
              final vm = Map<String, dynamic>.from(v);
              roles[k.toString()] = (vm["role"]?? "visitor").toString();
              genders[k.toString()] = (vm["gender"]?? "").toString();
              names[k.toString()] = (vm["name"]?? "").toString();
            }
          });
        }
        val.forEach((k, v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            final mob = (m["mobile"]?? "").toString();
            if (mob.isEmpty || seen.contains(mob)) return;
            seen.add(mob);
            // FIX 1: naam lock wala dikhao
            final lockedName = names[mob];
            list.add(_Present(
                uid: int.tryParse(k.toString())?? 0,
                name: (lockedName!= null && lockedName.isNotEmpty)? lockedName : (m["name"]?? "?").toString(),
                mobile: mob,
                role: roles[mob]?? "visitor",
                gender: genders[mob]?? "",
                idNo: (m["idNo"]?? "").toString(), photo: (m["photo"]?? "").toString()));
          }
        });
      }
      if (mounted) setState(() => present = list);
    });

    chatSub = roomRef.child("chat").limitToLast(50).onValue.listen((e) {
      if (!mounted) return;
      final list = <_ChatMsg>[];
      final val = e.snapshot.value;
      if (val is Map) {
        val.forEach((k, v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            final vb = m["viewedBy"];
            int at;
            try { at = (m["at"]?? 0) as int; } catch (_) { at = int.tryParse((m["at"]?? "0").toString())?? 0; }
            list.add(_ChatMsg(
              key: k.toString(),
              name: (m["name"]?? "?").toString(),
              mobile: (m["mobile"]?? "").toString(),
              photo: (m["photo"]?? "").toString(),
              text: (m["text"]?? "").toString(),
              role: (m["role"]?? "").toString(),
              at: at,
              type: (m["type"]?? "text").toString(),
              imageUrl: (m["imageUrl"]?? "").toString(),
              viewOnce: m["viewOnce"] == true,
              viewedBy: vb is Map? Map<String, dynamic>.from(vb) : <String, dynamic>{},
            ));
          }
        });
      }
      list.sort((a, b) => a.at.compareTo(b.at));
      // FIX: fresh chat - room me abhi aaye ho to purane message mat dikhao
      if (!widget.rejoin) {
        if (_chatFirstLoad) {
          _oldChatKeys = list.map((m) => m.key).toSet();
          _chatFirstLoad = false;
        }
        list.removeWhere((m) => _oldChatKeys.contains(m.key));
      } else {
        _chatFirstLoad = false;
      }
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

    lockSub = roomRef.child("info/locked").onValue.listen((e) {
      if (!mounted) return;
      final l = e.snapshot.value == true;
      if (l!= roomLocked) {
        setState(() => roomLocked = l);
        _toast(l? "Room lock ho gaya ðŸ”’" : "Room unlock ho gaya ðŸ”“");
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

    themeSub = roomRef.child("info/theme").onValue.listen((e) {
      if (!mounted) return;
      final val = e.snapshot.value;
      if (val != null && mounted) setState(() => roomTheme = val as String);
    });
    noticeSub = roomRef.child("info/notice").onValue.listen((e) {
      if (!mounted) return;
      final n = e.snapshot.value?.toString()?? "";
      if (n!= roomNotice) setState(() => roomNotice = n);
    });
    }
// ================= VOICE JOIN (final) =================
int _joinRetry = 0;

Future<void> _joinAgora() async {
  if (!mounted || joined) return;
  try {
    var st = await Permission.microphone.status;
    if (!st.isGranted) {
      st = await Permission.microphone.request();
    }
    if (!st.isGranted) {
      if (mounted) setState(() => status = "Mic permission do (tap: retry)");
      return;
    }
  } catch (_) {}
  if (globalVoiceEngine!= null && globalVoiceRoom!= widget.roomNo) {
    try { await globalVoiceEngine?.leaveChannel(); } catch (_) {}
    try { await globalVoiceEngine?.release(); } catch (_) {}
    globalVoiceEngine = null;
    globalVoiceRoom = null;
  }
  // Engine null hai (Leave ke baad) to yahin naya banao
  if (globalVoiceEngine == null) {
    try {
      if (mounted) setState(() => status = "Engine bana raha...");
      final e = createAgoraRtcEngine();
      await e.initialize(RtcEngineContext(appId: voiceRoomAppId));
      globalVoiceEngine = e;
      globalVoiceRoom = widget.roomNo;
    } catch (_) {
      if (mounted) setState(() => status = "Engine fail (tap: retry)");
      return;
    }
  }
  final eng = globalVoiceEngine;
  if (eng == null ||!mounted || joined) return;
  final channel = "voiceroom_${widget.roomNo}";
  try {
    if (mounted) setState(() => status = "Connecting...");
    final token = await fetchVoiceToken(channel, myUid);
    print("JOIN TRY: channel=$channel uid=$myUid token_len=${token.length} debug=$tokenDebug");
    if (token.isEmpty) throw Exception("token nahi mila");
    await eng.setDefaultAudioRouteToSpeakerphone(true);
    await eng.enableAudio();
    await eng.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
    eng.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (c, e) {
        _joinRetry = 0;
        try { eng.setEnableSpeakerphone(true); } catch (_) {}
        if (mounted) setState(() { joined = true; status = "Connected"; });
        _applyPublish();
      },
      onAudioVolumeIndication: (c, speakers, total, _) {
        final set = <int>{};
        for (final sp in speakers) {
          if ((sp.volume?? 0) > 5) set.add(sp.uid == 0? myUid : (sp.uid?? myUid));
        }
        if (mounted) setState(() => speaking = set);
      },
      onError: (code, msg) {
        if (mounted) setState(() => status = "Error $code: $msg (tap: retry)");
      },
      onTokenPrivilegeWillExpire: (c, _) async {
        try {
          final nt = await fetchVoiceToken(channel, myUid);
          if (nt.isNotEmpty) await eng.renewToken(nt);
        } catch (_) {}
      },
    ));
    await eng.joinChannel(
      token: token,
      channelId: channel,
      uid: myUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        autoSubscribeAudio: true,
        publishMicrophoneTrack: false,
      ),
    );
  } catch (e) {
    _autoRetry();
  }
}

Future<void> _autoRetry() async {
  if (!mounted || joined) return;
  _joinRetry++;
  if (_joinRetry > 5) {
    if (mounted) setState(() => status = "Connect nahi hua (tap: retry)");
    return;
  }
  await Future.delayed(const Duration(seconds: 2));
  if (!mounted || joined) return;
  try { await globalVoiceEngine?.leaveChannel(); } catch (_) {}
  _joinAgora();
}

  Future<void> _applyPublish() async {
    final eng = globalVoiceEngine;
    if (eng == null ||!joined) return;
    final shouldPublish = micOn && mySeat >= 0;
    try {
      await eng.updateChannelMediaOptions(ChannelMediaOptions(
        publishMicrophoneTrack: shouldPublish,
      ));
    } catch (_) {}
    try {
      await eng.muteLocalAudioStream(!shouldPublish);
    } catch (_) {}
  }

  Future<void> _sitOn(int i, {bool adminBypass = false}) async {
    if (mySeat >= 0) { _toast("Pehle apni seat chhodo"); return; }
    _seatGuardUntil = DateTime.now().millisecondsSinceEpoch + 3000;
    final ref = roomRef.child("seats/$i");
    try {
      final snap = await ref.get();
      bool wasEmpty = true;
      if (snap.exists && snap.value is Map) {
        final m = Map<String, dynamic>.from(snap.value as Map);
        final oldMobile = (m["mobile"]?? "").toString();
        if (oldMobile.isNotEmpty && oldMobile!= myMobile) { _toast("Seat nahi mili, dobara try karo"); return; }
        if (m["locked"] == true &&!adminBypass) { _toast("Seat lock hai"); return; }
        wasEmpty = oldMobile.isEmpty;
      }
      await ref.set({
        "locked": false, "micLocked": false, "uid": myUid, "mobile": myMobile,
        "name": myName, "role": myRole, "gender": myGender, "idNo": myIdNo, "photo": myPhoto,
        "muted":!micOn, "at": DateTime.now().millisecondsSinceEpoch,
      });
      if (wasEmpty) _bumpSeated(1);
      setState(() => mySeat = i);
      _applyPublish();
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
    try { await roomRef.child("seats/$idx").remove(); _bumpSeated(-1); } catch (_) {}
  }

  Future<void> _bumpSeated(int delta) async {
    try {
      await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}/seated").runTransaction((v) {
        final n = ((v as int?)?? 0) + delta;
        return Transaction.success(n < 0? 0 : n);
      });
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    if (mySeat >= 0 && seats[mySeat].micLocked) { _toast("Mic lock hai"); return; }
    setState(() { micOn =!micOn; globalMicOn = micOn; });
    await _applyPublish();
    if (mySeat >= 0) {
      try { await roomRef.child("seats/$mySeat").update({"muted":!micOn}); } catch (_) {}
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() { speakerOn =!speakerOn; globalSpeakerOn = speakerOn; });
    await globalVoiceEngine?.setEnableSpeakerphone(speakerOn);
  }

  Future<void> _setRole(String mobile, String name, String role) async {
    final locked = await getLockedName(mobile, name);
    await roomRef.child("roles/$mobile").update({"role": role, "name": locked});
    final si = seats.indexWhere((s) => s.mobile == mobile);
    if (si >= 0) { try { await roomRef.child("seats/$si").update({"role": role, "name": locked}); } catch (_) {} }
    _toast("$locked -> $role");
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
    bool iAmVipMute = hasPower(_cachedMe, "can_mute_anyone");
    final targetMobile1 = seats[i].mobile;
    if(targetMobile1.isNotEmpty){
      try{
        final t = await FirebaseFirestore.instance.collection("users").doc(targetMobile1).get();
        if(hasPower(t.data()?? {}, "no_mute") &&!iAmVipMute){
          _toast("Isko mute nahi kar sakte"); return;
        }
      }catch(_){}
    }
    final upd = <String, dynamic>{"micLocked": lock};
    if (lock) upd["muted"] = true;
    await roomRef.child("seats/$i").update(upd);
    _toast(lock? "Mic lock" : "Mic unlock");
  }

  // FIX: no_mic_leave power - isko mic se koi nahi utar sakta (sirf can_remove_mic wala utar sakta hai)
  Future<void> _removeFromSeat(int i) async {
    final targetMobile = seats[i].mobile;
    if (targetMobile.isNotEmpty &&!hasPower(_cachedMe, "can_remove_mic")) {
      try {
        final t = await FirebaseFirestore.instance.collection("users").doc(targetMobile).get();
        if (hasPower(t.data()?? {}, "no_mic_leave")) {
          _toast("Isko mic se nahi utar sakte â›”");
          return;
        }
      } catch (_) {}
    }
    await roomRef.child("seats/$i").remove();
    _bumpSeated(-1);
    _toast("Seat se hataya");
  }

  Future<void> _inviteToSeat(String mobile, int i) async {
    await roomRef.child("invites/$mobile").set({"seat": i, "by": myMobile, "byName": myName, "at": ServerValue.timestamp});
    _toast("Invite bheja");
  }

  Future<void> _kick(String mobile, String name, int days) async {
    bool iAmVipKick = hasPower(_cachedMe, "can_kick_anyone");
    try {
      final t = await FirebaseFirestore.instance.collection("users").doc(mobile).get();
      if(hasPower(t.data()?? {}, "no_kick") &&!iAmVipKick){
        _toast("Isko kick nahi kar sakte"); return;
      }
    } catch (_) {}
    if(!isAdmin &&!iAmVipKick){ _toast("Sirf admin kick kar sakta hai"); return; }
    final until = days < 0? -1 : DateTime.now().millisecondsSinceEpoch + days * 86400000;
    await roomRef.child("kicks/$mobile").set({
      "name": name, "by": myMobile, "byName": myName, "until": until, "at": ServerValue.timestamp,
    });
    final si = seats.indexWhere((s) => s.mobile == mobile);
    if (si >= 0) { await roomRef.child("seats/$si").remove(); _bumpSeated(-1); }
    _toast("$name kick ${days < 0? "forever" : "$days din"}");
  }

  // âœ… FIXED: q2 line me isEqualTo lagaya
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
      content: const Text("Note: 1 mahine me sirf 2 baar badal sakte ho",
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      actions: [
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _saveGender("male"); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text("â™‚ Male", style: TextStyle(color: Colors.white))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _saveGender("female"); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
          child: const Text("â™€ Female", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  // FIX 4: gender 1 mahine me max 2 baar
  Future<void> _saveGender(String g) async {
    if (g == myGender) { _toast("Ye gender pehle se set hai"); return; }
    try {
      final docRef = FirebaseFirestore.instance.collection("users").doc(myMobile);
      final doc = await docRef.get();
      final now = DateTime.now();
      final monthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
      final data = doc.data()?? {};
      final changes = Map<String, dynamic>.from(data["genderChanges"]?? {});
      final count = (changes[monthKey]?? 0) as int;
      if (count >= 2) {
        _toast("Is mahine 2 baar badal chuke ho - agle mahine try karo");
        return;
      }
      changes[monthKey] = count + 1;
      await docRef.set({"gender": g, "genderChanges": changes}, SetOptions(merge: true));
      setState(() => myGender = g);
      try {
        await roomRef.child("roles/$myMobile").update({"gender": g});
        if (mySeat >= 0) { try { await roomRef.child("seats/$mySeat").update({"gender": g}); } catch (_) {} }
      } catch (_) {}
      _toast(g == "male"? "Gender: Male â™‚" : "Gender: Female â™€");
    } catch (e) {
      _toast("Error: $e");
    }
  }

  Future<void> _sendChat() async {
    final t = chatCtrl.text.trim();
    if (t.isEmpty) return;
    chatCtrl.clear();
    await roomRef.child("chat").push().set({
      "name": myName, "mobile": myMobile, "text": t, "role": myRole, "photo": myPhoto, "at": ServerValue.timestamp,
      "type": "text",
    });
  }

  // Photo Cloudinary par bhejega, URL wapas dega
  Future<String> _uploadToCloudinary(Uint8List bytes) async {
    final req = http.MultipartRequest(
      "POST",
      Uri.parse("https://api.cloudinary.com/v1_1/i5r1swhi/image/upload"),
    )
     ..fields['upload_preset'] = 'ludo_chat'
     ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'chat.jpg'));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (streamed.statusCode!= 200) throw Exception("Cloudinary: ${res.body}");
    return json.decode(res.body)['secure_url'] as String;
  }

  // FIX: chat me photo bhejo - normal ya view-once (3 sec) [Cloudinary]
  Future<void> _pickAndSendImage() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1420),
        title: const Text("Photo bhejo", style: TextStyle(color: Colors.white)),
        content: const Text("Kaunsi photo bhejni hai?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, "once"),
            child: const Text("View-once (3 sec)")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, "normal"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text("Normal photo", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    if (choice == null) return;
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1080);
      if (x == null) return;
      _toast("Photo upload ho rahi hai...");
      final bytes = await x.readAsBytes();
      final url = await _uploadToCloudinary(bytes);
      await roomRef.child("chat").push().set({
        "name": myName, "mobile": myMobile, "text": "", "role": myRole, "at": ServerValue.timestamp,
        "type": "image", "imageUrl": url, "viewOnce": choice == "once", "viewedBy": {},
      });
    } catch (e) {
      _toast("Photo fail: $e");
    }
  }

  Widget _chatContent(_ChatMsg m) {
    if (m.type == "image" && m.imageUrl.isNotEmpty) {
      final seen = m.viewedBy[myMobile] == true;
      if (m.viewOnce && seen) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Text("Dekh liya", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
        );
      }
      // View-once: kholne se pehle saaf photo mat dikhao
      if (m.viewOnce &&!seen) {
        return InkWell(
          onTap: () => _openImage(m),
          child: Container(
            height: 150,
            width: 200,
            decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4))),
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.visibility_off, color: Colors.amber, size: 28),
              SizedBox(height: 6),
              Text("3s photo", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text("Tap karke dekho", style: TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
          ),
        );
      }
      return InkWell(
        onTap: () => _openImage(m),
        child: Stack(alignment: Alignment.topRight, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(m.imageUrl, height: 150, fit: BoxFit.cover,
                loadingBuilder: (c, w, p) => p == null
                   ? w
                    : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (c, e, st) => const SizedBox(
                    height: 60, child: Center(child: Icon(Icons.broken_image, color: Colors.white38)))),
          ),
          if (m.viewOnce)
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Text("3s", style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ]),
      );
    }
    return Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 13));
  }

  void _openImage(_ChatMsg m) {
    if (m.type!= "image" || m.imageUrl.isEmpty) return;
    if (m.viewOnce && m.viewedBy[myMobile] == true) { _toast("Ye photo ek baar dekh li gayi"); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewScreen(
      url: m.imageUrl,
      viewOnce: m.viewOnce,
      onViewed: () async {
        try { await roomRef.child("chat/${m.key}/viewedBy/$myMobile").set(true); } catch (_) {}
      },
    )));
  }

  // FIX: owner room notice likhe / badle
  Future<void> _editNotice() async {
    if (!isOwner) return;
    final ctrl = TextEditingController(text: roomNotice);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1420),
        title: const Text("Room Notice", style: TextStyle(color: Colors.amber)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
              hintText: "Sabko kya dikhana hai? (khali chhodo = hata do)",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black38,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text("Save", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    if (res == null) return;
    await roomRef.child("info").update({"notice": res});
    setState(() => roomNotice = res);
    _toast(res.isEmpty? "Notice hata diya" : "Notice lag gaya");
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

  // FIX 3: back dabane par Keep / Leave option
  Future<String?> _askKeepOrLeave() async {
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF2A1420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Room se bahar jana hai?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.headset_mic, color: Colors.greenAccent),
            title: const Text("Keep - room me raho, bahar jao",
                style: TextStyle(color: Colors.white)),
            subtitle: const Text("Voice chalu rahegi, icon par tap karke wapas aa jaoge",
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            onTap: () => Navigator.pop(context, "keep"),
          ),
          ListTile(
            leading: const Icon(Icons.call_end, color: Colors.redAccent),
            title: const Text("Leave - room chhod do",
                style: TextStyle(color: Colors.white)),
            subtitle: const Text("Voice band ho jayegi",
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            onTap: () => Navigator.pop(context, "leave"),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    return res;
  }

  Future<bool> _onBackPressed() async {
    final res = await _askKeepOrLeave();
    if (res == "keep") {
      _keepAlive = true;
      minimizedRoomNo = widget.roomNo;
      return true; // pop, lekin _leave mat karo
    } else if (res == "leave") {
      _keepAlive = false;
      minimizedRoomNo = null;
      await _leave(pop: false);
      return true;
    }
    return false;
  }

  // FIX: upar wala exit button bhi Keep/Leave puchega
  Future<void> _exitPressed() async {
    final res = await _askKeepOrLeave();
    if (res == null ||!mounted) return;
    if (res == "keep") {
      _keepAlive = true;
      minimizedRoomNo = widget.roomNo;
    } else {
      _keepAlive = false;
      minimizedRoomNo = null;
      await _leave(pop: false);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _leave({bool pop = true}) async {
    minimizedRoomNo = null;
    if (mounted) setState(() { chats.clear(); });
    try { if (mySeat >= 0) { await roomRef.child("seats/$mySeat").remove(); _bumpSeated(-1); } } catch (_) {}
    try { await myPresentRef?.remove(); } catch (_) {}
    try {
      await FirebaseDatabase.instance.ref("vRoomList/${widget.roomNo}/online").runTransaction((v) {
        final n = ((v as int?)?? 1) - 1;
        return Transaction.success(n < 0? 0 : n);
      });
    } catch (_) {}
    for (var s in [seatsSub, presentSub, chatSub, roleSub, kickSub, inviteSub, lockSub, noticeSub, giftSub, pkSub]) {
      try { await s?.cancel(); } catch (_) {}
    }
    try { await globalVoiceEngine?.leaveChannel(); } catch (_) {}
    try { await globalVoiceEngine?.release(); } catch (_) {}
    globalVoiceEngine = null;
    globalVoiceRoom = null;
    if (pop && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    // FIX 3: Keep kiya to engine zinda rakho
    if (_keepAlive) {
      for (var s in [seatsSub, presentSub, chatSub, roleSub, kickSub, inviteSub, lockSub, noticeSub, giftSub, pkSub]) {
        try { s?.cancel(); } catch (_) {}
      }
      // seat aur present rakho taaki wapas aane par sab waisa hi mile
    } else {
      _leave(pop: false);
    }
    tabCtrl.dispose();
    chatCtrl.dispose();
    chatScroll.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  // FIX 6: gender icon DP (male=boy, female=girl), bolne par green glow
  Widget _avatarFor(String name, String gender, double radius, {bool isMe = false, bool glow = false, String photo = ""}) {
    IconData icon;
    Color bg;
    if (gender == "male") {
      icon = Icons.boy;
      bg = isMe? Colors.blue : const Color(0xFF2A5A8A);
    } else if (gender == "female") {
      icon = Icons.girl;
      bg = isMe? Colors.pinkAccent : const Color(0xFF8A2A5A);
    } else {
      icon = Icons.person;
      bg = isMe? Colors.amber : const Color(0xFF7A4A5E);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: glow? Colors.greenAccent : Colors.transparent, width: 2.5),
        boxShadow: glow? [BoxShadow(color: Colors.greenAccent.withOpacity(0.7), blurRadius: 12)] : [],
      ),
      child: photo.isNotEmpty
          ? CircleAvatar(radius: radius, backgroundColor: bg, backgroundImage: NetworkImage(photo))
          : CircleAvatar(
              radius: radius,
              backgroundColor: bg,
              child: Icon(icon, color: Colors.white, size: radius * 1.3),
            ),
    );
  }
  // ===== DP helpers (Step 1) =====
  String _photoFor(String mobile) {
    if (mobile == myMobile) return myPhoto;
    for (final p in present) { if (p.mobile == mobile && p.photo.isNotEmpty) return p.photo; }
    for (final s in seats) { if (s.mobile == mobile && s.photo.isNotEmpty) return s.photo; }
    return "";
  }
  Widget _chatAvatar(String mobile, String name, String msgPhoto, bool isMe) {
    final ph = msgPhoto.isNotEmpty? msgPhoto : _photoFor(mobile);
    if (ph.isNotEmpty) return CircleAvatar(radius: 12, backgroundImage: NetworkImage(ph));
    return CircleAvatar(radius: 12, backgroundColor: isMe? Colors.amber : Colors.white24,
        child: Text(name.isNotEmpty? name[0].toUpperCase() : "?", style: const TextStyle(fontSize: 12, color: Colors.black)));
  }
    // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF2B0F1E), Color(0xFF5C1030), Color(0xFF3D0B22)]),
          ),
          child: SafeArea(
            child: Column(children: [
              _header(),
              if (roomNotice.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.4))),
                  child: Row(children: [
                    const Icon(Icons.campaign, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(roomNotice, style: const TextStyle(color: Colors.amber, fontSize: 12))),
                  ]),
                ),
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
            Row(children: [
              Flexible(
                child: Text(roomName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              ),
              if (roomLocked) const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.lock, color: Colors.amber, size: 18),
              ),
            ]),
            Text("ID:${widget.roomNo}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        // FIX 8: owner lock/unlock button
                if (isOwner)
          IconButton(
            icon: Icon(roomLocked? Icons.lock_open : Icons.lock, color: Colors.amber),
            tooltip: roomLocked? "Room unlock karo" : "Room lock karo",
            onPressed: _toggleRoomLock,
          ),
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.amber),
            tooltip: "Notice likho",
            onPressed: _editNotice,
          ),
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.block, color: Colors.redAccent),
            tooltip: "Kick list",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _KickListScreen(roomNo: widget.roomNo))),
          ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _exitPressed),
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
        _avatarFor(s.name, s.gender, 26, isMe: isMe, glow: isSpeaking, photo: isMe? myPhoto : s.photo),
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
        if(!s.empty)
          FutureBuilder(
            future: FirebaseFirestore.instance.collection("users").doc(s.mobile).get(),
            builder: (c, snap){
              final tag = snap.data?.data()?["tag"]?.toString()?? "";
              if(tag.isEmpty) return SizedBox.shrink();
              return Container(
                margin: EdgeInsets.only(top:2),
                padding: EdgeInsets.symmetric(horizontal:6, vertical:2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tag,
                  style: TextStyle(fontSize:9, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              );
            },
          ),
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
      if (isAdmin) { _seatAdminSheet(s); return; }
      if (s.locked) { _toast("Seat lock hai"); return; }
      _sitOn(s.index);
      return;
    }
    _userSheet(name: s.name, mobile: s.mobile, uid: s.uid, role: s.role, gender: s.gender, idNo: s.idNo, photo: s.photo, seatIndex: s.index, isSeated: true);
  }

  void _seatAdminSheet(_Seat s) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF2A1420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text("Seat ${s.index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.event_seat, color: Colors.amber), title: const Text("Baith jao", style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _sitOn(s.index, adminBypass: true); }),
          ListTile(leading: Icon(s.locked? Icons.lock_open : Icons.lock, color: Colors.orange),
              title: Text(s.locked? "Seat unlock karo" : "Seat lock karo", style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _lockSeat(s.index,!s.locked); }),
          const SizedBox(height: 8),
        ])));
  }

  void _userSheet({required String name, required String mobile, required int uid, required String role, String gender = "", String idNo = "", String photo = "", int seatIndex = -1, bool isSeated = false}) {
    final isMe = mobile == myMobile;
    final targetIsOwner = role == "owner" || mobile == ownerMobile;
    // FIX 1: sheet me bhi lock naam
    final showName = isMe? myName : name;
    final showGender = isMe? myGender : gender;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF2A1420),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          final items = <Widget>[
            ListTile(
              leading: _avatarFor(showName, showGender, 20, photo: photo),
              title: Text("$showName${genderSymbol(showGender)} ${_roleTag(role)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                myGender.isEmpty? "Apna gender set karo" : "Gender: ${myGender == "male"? "Male â™‚" : "Female â™€"} (badlo)",
                _chooseGender);
          } else {
            addTile(Icons.person_add_alt, Colors.greenAccent, "Add Friend", () => _addFriend(mobile, showName));
            if (isOwner) {
              if (!targetIsOwner) {
                if (role!= "admin") addTile(Icons.shield, Colors.blue, "Admin banao", () => _setRole(mobile, showName, "admin"));
                if (role!= "member") addTile(Icons.person_add, Colors.green, "Member banao", () => _setRole(mobile, showName, "member"));
                if (role == "admin" || role == "member") addTile(Icons.person_remove, Colors.orange, "Role hatao", () => _removeRole(mobile, showName));
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
                addTile(Icons.block, Colors.red, "Kick - 7 din", () => _kick(mobile, showName, 7));
                addTile(Icons.delete_forever, Colors.red, "Kick - Forever", () => _kick(mobile, showName, -1));
              }
            } else if (isAdmin) {
              // FIX: can_remove_mic / can_kick_anyone power wala admin, admin ko bhi handle kar sakta hai
              final bool vipRemove = hasPower(_cachedMe, "can_remove_mic");
              final bool vipKick = hasPower(_cachedMe, "can_kick_anyone");
              if (!targetIsOwner && (role!= "admin" || vipKick || vipRemove)) {
                if (role!= "admin" || vipKick) {
                  addTile(Icons.block, Colors.red, "Kick - 3 din", () => _kick(mobile, showName, 3));
                }
                if (role!= "member") addTile(Icons.person_add, Colors.green, "Member banao", () => _setRole(mobile, showName, "member"));
                if (isSeated) {
                  final st = seats[seatIndex];
                  addTile(st.micLocked? Icons.mic : Icons.mic_off, Colors.purple, st.micLocked? "Mic unlock karo" : "Mic lock karo",
                      () => _lockMic(seatIndex,!st.micLocked));
                  addTile(Icons.event_seat, Colors.orange, "Seat se hatao", () => _removeFromSeat(seatIndex));
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
                        Row(children: [
                          _chatAvatar(m.mobile, m.name, m.photo, isMe),
                          const SizedBox(width: 6),
                          Expanded(child: Text("${m.name}${m.role.isNotEmpty? " (${m.role.toUpperCase()})" : ""}",
                              style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 4),
                        _chatContent(m),
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
          InkWell(
            onTap: _pickAndSendImage,
            child: Container(padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                child: const Icon(Icons.image, color: Colors.amber, size: 18)),
          ),
          const SizedBox(width: 8),
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
        final isMe = p.mobile == myMobile;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Stack(children: [
              _avatarFor(p.name, isMe? myGender : p.gender, 18, photo: isMe? myPhoto : p.photo),
              Positioned(bottom: 0, right: 0, child: _roleBadge(p.role)),
            ]),
            title: Text("${p.name}${isMe? " (Tum)" : ""}${genderSymbol(isMe? myGender : p.gender)}",
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text("${_roleTag(p.role)}${seated? " - Seat pe" : " - Visitor"} - ID: ${p.idNo.isNotEmpty? p.idNo : "..."}",
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            onTap: () {
              final si = seats.indexWhere((s) => s.mobile == p.mobile);
              _userSheet(name: p.name, mobile: p.mobile, uid: p.uid, role: p.role, gender: p.gender, idNo: p.idNo, photo: p.photo, seatIndex: si, isSeated: si >= 0);
            },
          ),
        );
      },
    );
  }

  // ===== GIFT SYSTEM METHODS (Step 2) =====
  Future<void> _loadMyCoins() async {
    try {
      final d = await FirebaseFirestore.instance.collection("users").doc(myMobile).get();
      if (mounted) setState(() => myCoins = (d.data()?['coins'] ?? 0) as int);
    } catch (_) {}
  }

  void _listenGifts() {
    giftSub = roomRef.child("gifts").limitToLast(1).onChildAdded.listen((e) {
      if (e.snapshot.key == null || _seenGiftKeys.contains(e.snapshot.key)) return;
      _seenGiftKeys.add(e.snapshot.key!);
      try {
        final g = Map<String, dynamic>.from(e.snapshot.value as Map);
        _showGiftAnim(g);
      } catch (_) {}
    });
  }

  void _showGiftAnim(Map<String, dynamic> g) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Positioned.fill(
      child: Material(color: Colors.transparent,
        child: Center(child: _giftAnimCard(g))),
    ));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () { try { entry.remove(); } catch (_) {} });
  }

  Widget _giftAnimCard(Map<String, dynamic> g) {
    final img = (g['giftImg'] ?? "") as String;
    return Container(
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber, width: 2)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("\u{1F381}", style: TextStyle(fontSize: 50)),
        if (img.isNotEmpty)
          Image.network(img, width: 100, height: 100,
              errorBuilder: (_, __, ___) => const SizedBox()),
        const SizedBox(height: 12),
        Text("${g['fromName']} ne ${g['toName']} ko",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        Text("${g['giftName']}",
            style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
        Text("bheja! (${g['price']} coins)",
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ]),
    );
  }

  // ===== PK BATTLE METHODS (Step 4) =====
  void _handlePk() {
    if (inPk) { _showPkEndDialog(); } else { _showPkChallengeSheet(); }
  }
  void _showPkEndDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("PK khatam karein?", style: TextStyle(color: Colors.white)),
      content: Text("Score: $myPkScore vs $oppPkScore\nTime left: ${pkTimeLeft}s", style: const TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Continue")), TextButton(onPressed: () { Navigator.pop(context); _endPk(force: true); }, child: const Text("End PK", style: TextStyle(color: Colors.red)))],
    ));
  }
  void _showPkChallengeSheet() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PkChallengeSheet(roomId: widget.roomNo, onChallenge: _startPkChallenge));
  }
  Future<void> _startPkChallenge(String opponentRoomId) async {
    try {
      final rtdb = FirebaseDatabase.instance;
      final oppPkRef = rtdb.ref("vRoomList/$opponentRoomId/pk");
      final oppSnap = await oppPkRef.get();
      if (oppSnap.exists) { _toast("Ye room pehle se PK me hai!"); return; }
      final myPkRef = rtdb.ref("vRoomList/${widget.roomNo}/pk");
      final mySnap = await myPkRef.get();
      if (mySnap.exists) { _toast("Tum pehle se PK me ho!"); return; }
      final pkData = {"id": DateTime.now().millisecondsSinceEpoch.toString(), "room1": widget.roomNo, "room2": opponentRoomId, "room1Name": myName, "room2Name": "Room $opponentRoomId", "score1": 0, "score2": 0, "startTime": ServerValue.timestamp, "duration": 300, "status": "active"};
      await myPkRef.set(pkData);
      await rtdb.ref("vRoomList/$opponentRoomId/pk").set(pkData);
      setState(() { inPk = true; pkId = pkData["id"] as String; pkOpponentRoom = opponentRoomId; pkOpponentName = "Room $opponentRoomId"; myPkScore = 0; oppPkScore = 0; pkTimeLeft = 300; isPkHost = true; });
      _listenPk(); _startPkTimer(); _toast("âš”ï¸ PK shuru! 5 min battle!");
    } catch (e) { _toast("PK start fail: $e"); }
  }
  void _listenPk() {
    pkSub?.cancel();
    final rtdb = FirebaseDatabase.instance;
    pkSub = rtdb.ref("vRoomList/${widget.roomNo}/pk").onValue.listen((event) {
      if (!event.snapshot.exists) { if (inPk) _endPk(); return; }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      if (!mounted) return;
      setState(() {
        if (data["room1"] == widget.roomNo) { myPkScore = (data["score1"] ?? 0) as int; oppPkScore = (data["score2"] ?? 0) as int; pkOpponentRoom = (data["room2"] ?? "").toString(); pkOpponentName = (data["room2Name"] ?? data["room2"] ?? "").toString(); }
        else { myPkScore = (data["score2"] ?? 0) as int; oppPkScore = (data["score1"] ?? 0) as int; pkOpponentRoom = (data["room1"] ?? "").toString(); pkOpponentName = (data["room1Name"] ?? data["room1"] ?? "").toString(); }
        pkId = (data["id"] ?? "").toString(); inPk = true;
      });
    });
  }
  void _startPkTimer() {
    pkTimer?.cancel();
    pkTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (pkTimeLeft <= 0) { t.cancel(); _endPk(); return; }
      setState(() => pkTimeLeft--);
    });
  }
  Future<void> _endPk({bool force = false}) async {
    try {
      pkTimer?.cancel(); pkSub?.cancel();
      final rtdb = FirebaseDatabase.instance;
      final isWinner = myPkScore > oppPkScore; final isDraw = myPkScore == oppPkScore;
      if (force || pkTimeLeft <= 0) {
        int reward = 0; if (isWinner) reward = 100; else if (isDraw) reward = 30; else reward = 10;
        if (reward > 0) { try { await FirebaseFirestore.instance.collection("users").doc(myMobile).update({"coins": FieldValue.increment(reward), "xp": FieldValue.increment(isWinner ? 50 : 10)}); if (mounted) setState(() => myCoins += reward); } catch (_) {} }
        try { await rtdb.ref("vRoomList/${widget.roomNo}/pk").remove(); if (pkOpponentRoom.isNotEmpty) await rtdb.ref("vRoomList/$pkOpponentRoom/pk").remove(); } catch (_) {}
        if (mounted) { String msg = isDraw ? "ðŸ¤ Draw! +$reward coins" : (isWinner ? "ðŸ† Jeet gaye! +$reward coins!" : "ðŸ˜¢ Haar gaye +$reward coins"); _toast(msg); }
      }
      if (mounted) setState(() { inPk = false; pkId = ""; pkOpponentRoom = ""; pkOpponentName = ""; myPkScore = 0; oppPkScore = 0; pkTimeLeft = 300; isPkHost = false; });
    } catch (e) { _toast("PK end error: $e"); }
  }
  Future<void> _updatePkScore(int giftPrice) async {
    if (!inPk) return;
    try {
      final rtdb = FirebaseDatabase.instance;
      final pkRef = rtdb.ref("vRoomList/${widget.roomNo}/pk");
      final snap = await pkRef.get(); if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final isRoom1 = data["room1"] == widget.roomNo; final field = isRoom1 ? "score1" : "score2"; final current = (data[field] ?? 0) as int;
      await pkRef.update({field: current + giftPrice});
      if (pkOpponentRoom.isNotEmpty) { final oppRef = rtdb.ref("vRoomList/$pkOpponentRoom/pk"); final oppSnap = await oppRef.get(); if (oppSnap.exists) await oppRef.update({field: current + giftPrice}); }
    } catch (_) {}
  }
  Widget _buildPkBar() {
    if (!inPk) return const SizedBox.shrink();
    final total = myPkScore + oppPkScore; final myPercent = total > 0 ? myPkScore / total : 0.5;
    return Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24, width: 1)),
      child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.local_fire_department, color: Colors.amber, size: 18), const SizedBox(width: 4), Text("PK ${pkTimeLeft}s", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]), Text("$myPkScore : $oppPkScore", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(pkOpponentName.isNotEmpty ? pkOpponentName : pkOpponentRoom, style: const TextStyle(color: Colors.white70, fontSize: 11))]), const SizedBox(height: 6), Stack(children: [Container(height: 6, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3))), FractionallySizedBox(widthFactor: myPercent.clamp(0.05, 0.95), child: Container(height: 6, decoration: BoxDecoration(color: myPkScore >= oppPkScore ? Colors.amber : Colors.white70, borderRadius: BorderRadius.circular(3))))])]) );
  }

  void _openGiftPanel() async {
    try {
      final snap = await FirebaseFirestore.instance.collection("gifts")
          .where("active", isEqualTo: true).orderBy("coinPrice").get();
      giftList = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) { _toast("Gifts load nahi hue"); return; }
    if (!mounted) return;
    final targets = seats.where((s) => !s.empty && s.mobile != myMobile).toList();
    if (targets.isEmpty) { _toast("Seat par koi nahi hai"); return; }
    _Seat? selected;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0F1E),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setSt) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("\u{1F381} Gift Bhejo",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text("\u{1FA99} $myCoins",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          const Text("Kisko bhejna hai?", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(height: 72, child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: targets.length,
            itemBuilder: (_, i) {
              final t = targets[i];
              final sel = selected?.mobile == t.mobile;
              return InkWell(
                onTap: () => setSt(() => selected = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sel ? Colors.amber.withOpacity(0.3) : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? Colors.amber : Colors.transparent)),
                  child: Column(children: [
                    CircleAvatar(radius: 18,
                      backgroundImage: t.photo.isNotEmpty ? NetworkImage(t.photo) : null,
                      child: t.photo.isEmpty
                          ? Text(t.name.isNotEmpty ? t.name[0] : "?",
                              style: const TextStyle(color: Colors.white)) : null),
                    Text(t.name.length > 8 ? t.name.substring(0, 8) : t.name,
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ])));
            })),
          const SizedBox(height: 12),
          const Text("Gift chuno:", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Expanded(child: giftList.isEmpty
            ? const Center(child: Text("Koi gift nahi hai",
                style: TextStyle(color: Colors.white54)))
            : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 0.8),
              itemCount: giftList.length,
              itemBuilder: (_, i) {
                final g = giftList[i];
                final img = (g['imageUrl'] ?? "") as String;
                final price = (g['coinPrice'] ?? 0) as int;
                final afford = myCoins >= price;
                return InkWell(
                  onTap: () {
                    if (selected == null) { _toast("Pehle kisko bhejna hai chuno"); return; }
                    if (!afford) { _toast("Coins kam hain!"); return; }
                    Navigator.pop(ctx2);
                    _sendGift(g, selected!.mobile, selected!.name);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (img.isNotEmpty)
                        Image.network(img, width: 50, height: 50,
                            errorBuilder: (_, __, ___) =>
                                const Text("\u{1F381}", style: TextStyle(fontSize: 40)))
                      else
                        const Text("\u{1F381}", style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 4),
                      Text("${g['name'] ?? ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text("\u{1FA99} $price",
                          style: TextStyle(color: afford ? Colors.amber : Colors.red,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ])));
              })),
        ]))),
    );
  }

  Future<void> _sendGift(Map<String, dynamic> gift, String toMobile, String toName) async {
    final price = (gift['coinPrice'] ?? 0) as int;
    if (myCoins < price) { _toast("Coins kam hain! Pehle coins khareedo"); return; }
    _toast("Gift bheja ja raha hai...");
    try {
      final fs = FirebaseFirestore.instance;
      final senderRef = fs.collection("users").doc(myMobile);
      final recvRef = fs.collection("users").doc(toMobile);
      await fs.runTransaction((tx) async {
        final sSnap = await tx.get(senderRef);
        final rSnap = await tx.get(recvRef);
        final sCoins = (sSnap.data()?['coins'] ?? 0) as int;
        if (sCoins < price) throw Exception("Coins kam hain");
        tx.update(senderRef, {"coins": sCoins - price});
        final rCoins = (rSnap.data()?['coins'] ?? 0) as int;
        tx.update(recvRef, {"coins": rCoins + price});
      });
      final now = FieldValue.serverTimestamp();
      await fs.collection("coinTx").add({
        "mobile": myMobile, "type": "gift_sent", "amount": -price,
        "detail": "${gift['name']} -> $toName", "at": now,
      });
      await fs.collection("coinTx").add({
        "mobile": toMobile, "type": "gift_received", "amount": price,
        "detail": "${gift['name']} <- $myName", "at": now,
      });
      await roomRef.child("gifts").push().set({
        "fromMobile": myMobile, "fromName": myName,
        "toMobile": toMobile, "toName": toName,
        "giftName": gift['name'], "giftImg": gift['imageUrl'] ?? "",
        "price": price, "at": ServerValue.timestamp,
      });
      if (mounted) setState(() => myCoins -= price);
      _updatePkScore(price);
      _toast("Gift bhej diya! \u{1F381}");
    } catch (e) {
      _toast("Gift fail: $e");
    }
  }

  // FIX 6: neeche wala Leave hataya - ab sirf Mic + Speaker
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Column(children: [
        InkWell(
          onTap: () { if (!joined) { _joinRetry = 0; _joinAgora(); } },
          child: Text(status + " | " + tokenDebug + (joined? "" : " (tap: retry)"),
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _bigBtn(icon: micOn? Icons.mic : Icons.mic_off, label: micOn? "Mic" : "Mute",
              active: micOn, onTap: _toggleMic),
          _bigBtn(icon: Icons.local_fire_department, label: inPk? "${pkTimeLeft}s" : "PK", active: inPk, onTap: _handlePk),
          _bigBtn(icon: Icons.card_giftcard, label: "Gift",
              active: true, onTap: _openGiftPanel),
          _bigBtn(icon: speakerOn? Icons.volume_up : Icons.volume_off, label: "Speaker",
              active: speakerOn, onTap: _toggleSpeaker),
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

// ================= PHOTO VIEWER =================
class _PhotoViewScreen extends StatefulWidget {
  final String url;
  final bool viewOnce;
  final VoidCallback onViewed;
  const _PhotoViewScreen({required this.url, required this.viewOnce, required this.onViewed});
  @override
  State<_PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<_PhotoViewScreen> {
  int sec = 3;
  Timer? _t;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewOnce) {
      _t = Timer.periodic(const Duration(seconds: 1), (x) {
        if (!mounted) { x.cancel(); return; }
        if (sec <= 1) {
          x.cancel();
          widget.onViewed();
          if (mounted) Navigator.pop(context);
        } else {
          setState(() => sec--);
        }
      });
    }
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode == 200) {
        await Gal.putImageBytes(Uint8List.fromList(res.bodyBytes));
        if (mounted) {
          ScaffoldMessenger.of(context)
             .showSnackBar(const SnackBar(content: Text("Gallery me save ho gaya")));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download fail (${res.statusCode})")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.viewOnce? "$sec sec" : "Photo",
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (!widget.viewOnce)
            saving
               ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: _save),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(widget.url,
              errorBuilder: (c, e, st) =>
                  const Icon(Icons.broken_image, color: Colors.white38, size: 60)),
        ),
      ),
    );
  }
}


class PkChallengeSheet extends StatefulWidget {
  final String roomId;
  final Function(String) onChallenge;
  const PkChallengeSheet({super.key, required this.roomId, required this.onChallenge});
  @override State<PkChallengeSheet> createState() => _PkChallengeSheetState();
}

class _PkChallengeSheetState extends State<PkChallengeSheet> {
  List<Map<String, dynamic>> liveRooms = [];
  bool loading = true;
  @override void initState() { super.initState(); _loadRooms(); }
  Future<void> _loadRooms() async {
    try {
      final rtdb = FirebaseDatabase.instance;
      final snap = await rtdb.ref("vRoomList").get();
      if (!snap.exists) { if (mounted) setState(() => loading = false); return; }
      final data = snap.value as Map;
      final rooms = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        if (key.toString() == widget.roomId) return;
        if (value is Map) {
          final info = value["info"] as Map? ?? {};
          final pk = value["pk"];
          rooms.add({"id": key.toString(), "name": (info["name"] ?? "Room $key").toString(), "online": ((value["present"] ?? {}) as Map).length, "inPk": pk != null});
        }
      });
      if (mounted) setState(() { liveRooms = rooms; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        const Row(children: [Icon(Icons.local_fire_department, color: Colors.orange), SizedBox(width: 8), Text("PK Challenge", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        const Text("Kisi live room ko challenge karo! 5 min battle, gifts = points", style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 16),
        if (loading) const Center(child: CircularProgressIndicator())
        else if (liveRooms.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("Koi live room nahi", style: TextStyle(color: Colors.white54)))
        else SizedBox(height: 300, child: ListView.builder(itemCount: liveRooms.length, itemBuilder: (_, i) {
          final r = liveRooms[i]; final inPk = r["inPk"] as bool;
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: inPk ? Colors.red.withOpacity(0.3) : Colors.white12)), child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: Colors.purple, child: Text(r["id"].toString().substring(0, 2), style: const TextStyle(color: Colors.white, fontSize: 12))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text("ID: ${r["id"]} - ${r["online"]} online${inPk ? " - PK me" : ""}", style: TextStyle(color: inPk ? Colors.redAccent : Colors.white54, fontSize: 11))])),
            ElevatedButton(onPressed: inPk ? null : () { Navigator.pop(context); widget.onChallenge(r["id"]); }, style: ElevatedButton.styleFrom(backgroundColor: inPk ? Colors.grey : Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: Text(inPk ? "Busy" : "PK", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ]));
        })),
      ]),
    );
  }

class _CropDialogVoice extends StatefulWidget {
  final Uint8List originalBytes;
  const _CropDialogVoice({required this.originalBytes});
  @override State<_CropDialogVoice> createState() => _CropDialogVoiceState();
}
class _CropDialogVoiceState extends State<_CropDialogVoice> {
  bool isSquareCrop = true;
  @override Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("DP Crop Karo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(12)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(widget.originalBytes, height: 200, fit: BoxFit.contain))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: ()=> setState(()=> isSquareCrop=true), icon: Icon(isSquareCrop ? Icons.check_box : Icons.check_box_outline_blank), label: const Text("Square"), style: ElevatedButton.styleFrom(backgroundColor: isSquareCrop ? const Color(0xFFFBBF24) : const Color(0xFF0F172A), foregroundColor: isSquareCrop ? Colors.black : Colors.white))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: ()=> setState(()=> isSquareCrop=false), icon: Icon(!isSquareCrop ? Icons.check_box : Icons.check_box_outline_blank), label: const Text("Original"), style: ElevatedButton.styleFrom(backgroundColor: !isSquareCrop ? const Color(0xFFFBBF24) : const Color(0xFF0F172A), foregroundColor: !isSquareCrop ? Colors.black : Colors.white))),
        ]),
      ])),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Cancel")), ElevatedButton(onPressed: (){ Navigator.pop(context, widget.originalBytes); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), child: const Text("Use This"))],
    );
  }
}

}
