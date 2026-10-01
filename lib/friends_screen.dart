import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

class FriendsScreen extends StatefulWidget {
  final String mobile;
  const FriendsScreen({super.key, required this.mobile});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final Map<String,String> _photoCache = {};
  // ===== DP helper (Step 1) =====
  Widget _dpAvatar(String mobile, String name, Color bg) {
    final cached = _photoCache[mobile];
    if (cached != null) {
      if (cached.isNotEmpty) return CircleAvatar(backgroundImage: NetworkImage(cached));
      return CircleAvatar(backgroundColor: bg, child: Text(name.isNotEmpty? name.substring(0,1).toUpperCase() : "?", style: TextStyle(color: bg == Colors.amber? Colors.black : Colors.white)));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(mobile).get(),
      builder: (c, snap) {
        final ph = snap.data?.data() == null? "" : ((snap.data!.data() as Map)["photoUrl"]?.toString()?? "");
        if (snap.connectionState == ConnectionState.done) _photoCache[mobile] = ph;
        if (ph.isNotEmpty) return CircleAvatar(backgroundImage: NetworkImage(ph));
        return CircleAvatar(backgroundColor: bg, child: Text(name.isNotEmpty? name.substring(0,1).toUpperCase() : "?", style: TextStyle(color: bg == Colors.amber? Colors.black : Colors.white)));
      },
    );
  }
  late TabController tabCtrl;
  final searchCtrl = TextEditingController();
  List<DocumentSnapshot> pending = [];
  List<Map<String, dynamic>> friendsWithName = [];
  List<Map<String, dynamic>> blockedWithName = [];
  List<DocumentSnapshot> searchResult = [];
  bool loading = true;
  String myName = "";
  String myIdNo = "";
  List<String> myPowers = [];

  @override void initState() { super.initState(); tabCtrl = TabController(length: 4, vsync: this); loadAll(); }

  Future<void> loadAll() async {
    setState((){ loading = true; });
    try {
      var me = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      myName = me.data()?["name"]?? "You";
      myIdNo = me.data()?["voiceRoomNo"]?.toString()?? "";
      myPowers = List<String>.from(me.data()?["powers"]?? []);
      // block list pehle lao taaki blocked logon ki request filter ho sake
      var b = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").get();
      var blockedIds = b.docs.map((d) => d.id).toSet();
      List<Map<String, dynamic>> btemp = [];
      for(var doc in b.docs){
        var bdata = doc.data() as Map<String, dynamic>;
        String bm = bdata["mobile"]?.toString()?? doc.id;
        var userDoc = await FirebaseFirestore.instance.collection("users").doc(bm).get();
        String bname = userDoc.data()?["name"]?? "User";
        String bid = userDoc.data()?["voiceRoomNo"]?.toString()?? "";
        btemp.add({"mobile": bm, "name": bname, "idNo": bid});
      }
      // FIX: composite index se bachne ke liye sirf "to" par query, status ka filter code me
      // blocked logon ki request list me nahi dikhegi
      var p = await FirebaseFirestore.instance.collection("friend_requests").where("to", isEqualTo: widget.mobile).get();
      var pendingDocs = p.docs.where((d) {
        var m = d.data() as Map<String, dynamic>;
        if (m["status"]!= "pending") return false;
        if (blockedIds.contains(m["from"]?.toString())) return false;
        return true;
      }).toList();
      var f = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").get();
      List<Map<String, dynamic>> temp = [];
      for(var doc in f.docs){
        var fdata = doc.data() as Map<String, dynamic>;
        String fm = fdata["mobile"]?.toString()?? doc.id;
        var userDoc = await FirebaseFirestore.instance.collection("users").doc(fm).get();
        String fname = userDoc.data()?["name"]?? "Friend";
        String fid = userDoc.data()?["voiceRoomNo"]?.toString()?? "";
        temp.add({"mobile": fm, "name": fname, "idNo": fid});
      }
      if(!mounted) return;
      setState((){ pending = pendingDocs; friendsWithName = temp; blockedWithName = btemp; loading = false; });
    } catch (e) {
      if(!mounted) return;
      setState(()=> loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Load fail: $e")));
    }
  }

  // SABHI CHATS CLEAR (sirf mere liye) - Firestore se delete NAHI hota, admin panel me sab safe rahega
  Future<void> _clearAllChats() async {
    if (friendsWithName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Koi chat nahi hai")));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sabhi chats clear karein?"),
        content: Text("${friendsWithName.length} friends ke saath ki chat SIRF tumhare phone se clear hogi.\nDosto ko sab dikhta rahega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sab clear karo")),
        ],
      ),
    );
    if (yes!= true) return;
    try {
      for (var f in friendsWithName) {
        final fm = f["mobile"].toString();
        final s = [widget.mobile, fm]..sort();
        await FirebaseFirestore.instance.collection("friend_chats").doc(s.join("_"))
          .set({"clearedBy": {widget.mobile: FieldValue.serverTimestamp()}}, SetOptions(merge: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sabhi chats clear ho gayi âœ…")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // ID NUMBER ya NAAM se search - 7 digit ka permanent ID (voice room number) ya naam dono chalega
  // Mobile number kisi ko nahi dikhega
  Future<void> searchUser() async {
    String s = searchCtrl.text.trim();
    if(s.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ID ya naam likho"))); return; }
    if(s==myIdNo) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ye tumhari apni ID hai"))); return; }
    try {
      // maine jinko block kiya hai wo search me nahi dikhenge
      var myBlocked = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").get();
      var blockedIds = myBlocked.docs.map((d) => d.id).toSet();
      QuerySnapshot q;
      // 7 digit number hai to ID se dhoondo, warna naam se
      if(RegExp(r'^[0-9]{7}$').hasMatch(s)){
        q = await FirebaseFirestore.instance.collection("users").where("voiceRoomNo", isEqualTo: s).limit(10).get();
      } else {
        q = await FirebaseFirestore.instance.collection("users").where("name", isGreaterThanOrEqualTo: s).where("name", isLessThan: s + '\uf8ff').limit(10).get();
      }
      var docs = q.docs.where((doc) => doc.id!= widget.mobile &&!blockedIds.contains(doc.id)).toList();
      if(docs.isEmpty){ setState(()=> searchResult=[]); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Koi user nahi mila"))); return; }
      setState(()=> searchResult=docs);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search fail: $e")));
    }
  }

  Future<void> sendRequest(String toMobile) async {
    try {
      // block check: maine isko block kiya hai ya isne mujhe
      var iBlocked = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").doc(toMobile).get();
      if(iBlocked.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tumne isko block kiya hai - pehle unblock karo"))); return; }
      var blockedMe = await FirebaseFirestore.instance.collection("users").doc(toMobile).collection("blocked").doc(widget.mobile).get();
      if(blockedMe.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request nahi bhej sakte"))); return; }
      // FIX: composite index se bachne ke liye 2 filter hataye, pending check code me
      var q = await FirebaseFirestore.instance.collection("friend_requests").where("from", isEqualTo: widget.mobile).get();
      bool alreadySent = q.docs.any((d){
        var m = d.data() as Map<String, dynamic>;
        return m["to"] == toMobile && m["status"] == "pending";
      });
      if(alreadySent){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se bhej rakhi hai"))); return; }
      var fr = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").doc(toMobile).get();
      if(fr.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se friend hai"))); return; }
      await FirebaseFirestore.instance.collection("friend_requests").add({"from": widget.mobile, "to": toMobile, "fromName": myName, "status": "pending", "time": FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request bhej di")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  Future<void> acceptRequest(DocumentSnapshot req) async {
    try {
      var data = req.data() as Map<String,dynamic>;
      String from = data["from"]; String to = data["to"];
      await FirebaseFirestore.instance.collection("users").doc(to).collection("friends").doc(from).set({"mobile": from, "addedAt": FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection("users").doc(from).collection("friends").doc(to).set({"mobile": to, "addedAt": FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "accepted"});
      loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  Future<void> rejectRequest(DocumentSnapshot req) async {
    try {
      await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "rejected"});
      loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // BLOCK: request wale ko block karo - request band + block list me jayega + friend tha to unfriend bhi
  Future<void> blockUser(String targetMobile, DocumentSnapshot? req) async {
    if(targetMobile.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Block karein?"),
        content: const Text("Ye user tumhe request nahi bhej payega aur message bhi nahi kar payega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Block")),
        ],
      ),
    );
    if(yes!= true) return;
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").doc(targetMobile).set({"mobile": targetMobile, "blockedAt": FieldValue.serverTimestamp()});
      if(req!= null){
        await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "blocked"});
      }
      // friend tha to dono taraf se unfriend bhi
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").doc(targetMobile).delete();
      await FirebaseFirestore.instance.collection("users").doc(targetMobile).collection("friends").doc(widget.mobile).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Block kar diya")));
      loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // UNBLOCK: block list se hatao
  Future<void> unblockUser(String targetMobile) async {
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("blocked").doc(targetMobile).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unblock ho gaya")));
      loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // UNFRIEND: dono taraf se dosti khatm
  Future<void> unfriend(String fm, String fname) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unfriend karein?"),
        content: Text("$fname se dosti toot jayegi.\nDono taraf se unfriend ho jaoge."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Unfriend")),
        ],
      ),
    );
    if(yes!= true) return;
    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").doc(fm).delete();
      await FirebaseFirestore.instance.collection("users").doc(fm).collection("friends").doc(widget.mobile).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unfriend ho gaya")));
      loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // admin power check: "chat_without_add" hai to bina add kiye seedha message
  bool _canDirectMsg(Map d){
    List tp = d["powers"]?? [];
    return tp.contains("chat_without_add") || myPowers.contains("chat_without_add");
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Colors.amber, title: Text("FRIENDS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: Icon(Icons.delete_sweep, color: Colors.black), tooltip: "Sabhi chats clear karo",
            onPressed: _clearAllChats),
        ],
        bottom: TabBar(controller: tabCtrl, labelColor: Colors.black, unselectedLabelColor: Colors.black54, isScrollable: true, tabs: [Tab(text: "ADD"), Tab(text: "REQUESTS (${pending.length})"), Tab(text: "MY FRIENDS (${friendsWithName.length})"), Tab(text: "BLOCKED (${blockedWithName.length})")])),
      body: loading? Center(child: CircularProgressIndicator(color: Colors.amber)):
      TabBarView(controller: tabCtrl, children: [
        // ===== TAB 1: ADD (search) =====
        Padding(padding: EdgeInsets.all(16), child: Column(children: [
          if(myIdNo.isNotEmpty)
            Container(margin: EdgeInsets.only(bottom:12), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.4))),
              child: Row(children: [Icon(Icons.badge, color: Colors.amber), SizedBox(width:8), Text("Tumhari ID: $myIdNo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width:4), Expanded(child: Text("(dosto ko ye ID do)", style: TextStyle(color: Colors.white54, fontSize: 11)))])),
          Row(children: [Expanded(child: TextField(controller: searchCtrl, keyboardType: TextInputType.text, maxLength: 20, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: "", labelText: "ID ya Naam se Search", labelStyle: TextStyle(color: Colors.white54, fontSize: 12), filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))), SizedBox(width:8), ElevatedButton(onPressed: searchUser, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text("SEARCH", style: TextStyle(color: Colors.black))) ]),
          SizedBox(height:8),
          Text("Mobile number kisi ko nahi dikhega - ID ya naam se add karo", style: TextStyle(color: Colors.white38, fontSize: 11)),
          SizedBox(height:12),
          Expanded(child: searchResult.isEmpty? Center(child: Text("ID ya naam likhke SEARCH dabao", style: TextStyle(color: Colors.white54))): ListView.builder(itemCount: searchResult.length, itemBuilder: (c,i){
            var d=searchResult[i].data() as Map;
            String name = d["name"]?? "User";
            String fid = d["voiceRoomNo"]?.toString()?? "";
            String toMobile = searchResult[i].id;
            bool directMsg = _canDirectMsg(d);
            return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [
              _dpAvatar(toMobile, name, Colors.amber),
              SizedBox(width:12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: $fid", style: TextStyle(color: Colors.white54, fontSize: 11))])),
              directMsg
               ? ElevatedButton(onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> PrivateChatScreen(myMobile: widget.mobile, friendMobile: toMobile, friendName: name, myName: myName))); }, child: Text("MESSAGE"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))
                : ElevatedButton(onPressed: ()=>sendRequest(toMobile), child: Text("ADD"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))
            ]));
          }))
        ])),
        // ===== TAB 2: REQUESTS (Accept / Reject / Block) =====
        pending.isEmpty? Center(child: Text("Koi request nahi", style: TextStyle(color: Colors.white54))): ListView.builder(padding: EdgeInsets.all(12), itemCount: pending.length, itemBuilder: (c,i){
          var data=pending[i].data() as Map;
          String fromName = data["fromName"]?? "Kisi ne";
          String fromMobile = data["from"]?.toString()?? "";
          return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [
            Expanded(child: Text("$fromName ne request bheji", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ElevatedButton(onPressed: ()=>acceptRequest(pending[i]), child: Text("Accept", style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 10))),
            SizedBox(width:6),
            ElevatedButton(onPressed: ()=>rejectRequest(pending[i]), child: Text("Reject", style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(horizontal: 10))),
            SizedBox(width:6),
            ElevatedButton(onPressed: ()=>blockUser(fromMobile, pending[i]), child: Text("Block", style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: EdgeInsets.symmetric(horizontal: 10))),
          ]));
        }),
        // ===== TAB 3: MY FRIENDS (chat + unfriend) =====
        friendsWithName.isEmpty? Center(child: Text("Koi friend nahi", style: TextStyle(color: Colors.white54))): ListView.builder(padding: EdgeInsets.all(12), itemCount: friendsWithName.length, itemBuilder: (c,i){
          var data=friendsWithName[i];
          String fname = data["name"];
          String fm = data["mobile"];
          String fid = data["idNo"]?? "";
          return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [
            _dpAvatar(fm, fname, Colors.green),
            SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fname, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: $fid", style: TextStyle(color: Colors.white54, fontSize: 11))])),
            IconButton(icon: Icon(Icons.chat, color: Colors.amber), tooltip: "Chat", onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> PrivateChatScreen(myMobile: widget.mobile, friendMobile: fm, friendName: fname, myName: myName))); }),
            IconButton(icon: Icon(Icons.person_remove, color: Colors.red), tooltip: "Unfriend", onPressed: ()=>unfriend(fm, fname)),
          ]));
        }),
        // ===== TAB 4: BLOCKED (unblock) =====
        blockedWithName.isEmpty? Center(child: Text("Kisi ko block nahi kiya", style: TextStyle(color: Colors.white54))): ListView.builder(padding: EdgeInsets.all(12), itemCount: blockedWithName.length, itemBuilder: (c,i){
          var data=blockedWithName[i];
          String bname = data["name"];
          String bm = data["mobile"];
          String bid = data["idNo"]?? "";
          return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))), child: Row(children: [
            _dpAvatar(bm, bname, Colors.red),
            SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(bname, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: $bid", style: TextStyle(color: Colors.white54, fontSize: 11))])),
            ElevatedButton(onPressed: ()=>unblockUser(bm), child: Text("Unblock"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
          ]));
        }),
      ])
    );
  }
}

// ============ PRIVATE CHAT: text + photo (view-once/normal) + soft delete + clear chat (sirf mere liye) ============
class PrivateChatScreen extends StatefulWidget {
  final String myMobile; final String friendMobile; final String friendName; final String myName;
  const PrivateChatScreen({super.key, required this.myMobile, required this.friendMobile, required this.friendName, required this.myName});
  @override State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final msgCtrl = TextEditingController();
  DateTime? _clearedAt;

  String getChatId(){ List<String> s=[widget.myMobile, widget.friendMobile]; s.sort(); return s.join("_"); }

  CollectionReference<Map<String,dynamic>> get msgCol =>
      FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages");

  @override
  void initState() {
    super.initState();
    _loadClearedAt();
  }

  Future<void> _loadClearedAt() async {
    try {
      final d = await FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).get();
      final cb = d.data()?["clearedBy"];
      if (cb is Map && cb[widget.myMobile] is Timestamp) {
        if (mounted) setState(() => _clearedAt = (cb[widget.myMobile] as Timestamp).toDate());
      }
    } catch (_) {}
  }

  void _toast(String s){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2))); }

  String _fmtTime(Timestamp? t){
    if (t == null) return "";
    final dt = t.toDate();
    int h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = h >= 12? "PM" : "AM";
    h = h % 12; if (h == 0) h = 12;
    return "$h:$m $ap";
  }

  String _dayLabel(DateTime dt){
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  Widget _dateChip(String label){
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _clearChat() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Chat clear karein?"),
        content: const Text("Is friend ke saath ki saari chat SIRF tumhare phone se clear hogi.\nSaamne wale ko sab dikhta rahega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear karo")),
        ],
      ),
    );
    if (yes!= true) return;
    try {
      await FirebaseFirestore.instance.collection("friend_chats").doc(getChatId())
        .set({"clearedBy": {widget.myMobile: FieldValue.serverTimestamp()}}, SetOptions(merge: true));
      if (mounted) setState(() => _clearedAt = DateTime.now());
      _toast("Chat clear ho gayi âœ…");
    } catch (e) { _toast("Fail: $e"); }
  }

  Future<String> _uploadToCloudinary(Uint8List bytes) async {
    final req = http.MultipartRequest("POST", Uri.parse("https://api.cloudinary.com/v1_1/i5r1swhi/image/upload"))
..fields['upload_preset'] = 'ludo_chat'
..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'chat.jpg'));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (streamed.statusCode!= 200) throw Exception("Cloudinary: ${res.body}");
    return json.decode(res.body)['secure_url'] as String;
  }

  Future<void> sendMsg() async {
    if(msgCtrl.text.trim().isEmpty) return;
    try {
      String text = msgCtrl.text.trim(); msgCtrl.clear();
      await msgCol.add({
        "from": widget.myMobile, "fromName": widget.myName, "to": widget.friendMobile,
        "type": "text", "msg": text, "viewedBy": {}, "time": FieldValue.serverTimestamp(),
      });
    } catch (e) { _toast("Bhej nahi paya: $e"); }
  }

  Future<void> _pickAndSendImage() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Photo bhejo"),
        content: const Text("Kaunsi photo bhejni hai?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, "once"), child: const Text("View-once (3 sec)")),
          ElevatedButton(onPressed: () => Navigator.pop(context, "normal"), child: const Text("Normal photo")),
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
      await msgCol.add({
        "from": widget.myMobile, "fromName": widget.myName, "to": widget.friendMobile,
        "type": "image", "imageUrl": url, "viewOnce": choice == "once", "viewedBy": {},
        "time": FieldValue.serverTimestamp(),
      });
    } catch (e) { _toast("Photo fail: $e"); }
  }

  bool _canDelete(Timestamp? t){
    if (t == null) return true;
    return DateTime.now().difference(t.toDate()).inMinutes < 2;
  }

  Future<void> _askDelete(String docId) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete karein?"),
        content: const Text("Ye message dono ke inbox se delete ho jayega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete for everyone")),
        ],
      ),
    );
    if (yes == true) {
      await msgCol.doc(docId).set({"hiddenFor": {widget.myMobile: true, widget.friendMobile: true}}, SetOptions(merge: true));
      _toast("Delete ho gaya");
    }
  }

  Future<void> _savePhoto(String url) async {
    try {
      _toast("Save ho rahi hai...");
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      final res = await http.get(Uri.parse(url));
      await Gal.putImageBytes(Uint8List.fromList(res.bodyBytes), name: "chat_${DateTime.now().millisecondsSinceEpoch}");
      _toast("Gallery me save ho gayi âœ…");
    } catch (e) { _toast("Save fail: $e"); }
  }

  void _openPhoto(QueryDocumentSnapshot<Map<String,dynamic>> doc){
    final d = doc.data();
    final url = (d["imageUrl"]?? "").toString();
    if (url.isEmpty) return;
    final bool viewOnce = d["viewOnce"] == true;
    final bool isMe = d["from"] == widget.myMobile;
    final Map viewedBy = Map.from(d["viewedBy"]?? {});
    if (viewOnce &&!isMe && viewedBy[widget.myMobile] == true) { _toast("Ye photo ek baar dekh li gayi"); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewScreen(
      url: url, viewOnce: viewOnce, showSave:!viewOnce,
      onSave: () => _savePhoto(url),
      onViewed: (!viewOnce || isMe)? null : () {
        msgCol.doc(doc.id).update({"viewedBy.${widget.myMobile}": true});
      },
    )));
  }

  Widget _bubble(QueryDocumentSnapshot<Map<String,dynamic>> doc){
    final d = doc.data();
    final bool isMe = d["from"] == widget.myMobile;
    final String type = (d["type"]?? "text").toString();
    final Timestamp? t = d["time"] as Timestamp?;
    final bool canDel = isMe && _canDelete(t);

    Widget content;
    if (type == "image") {
      final String url = (d["imageUrl"]?? "").toString();
      final bool viewOnce = d["viewOnce"] == true;
      final Map viewedBy = Map.from(d["viewedBy"]?? {});
      final bool seen = viewedBy[widget.myMobile] == true;
      if (viewOnce && seen &&!isMe) {
        content = const Text("Dekh liya ðŸ‘€", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic));
      } else if (viewOnce &&!seen &&!isMe) {
        content = GestureDetector(
          onTap: () => _openPhoto(doc),
          child: Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(url, height: 150, fit: BoxFit.cover),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Text("ðŸ‘ Tap to view", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      } else {
        content = GestureDetector(
          onTap: () => _openPhoto(doc),
          child: Stack(alignment: Alignment.topRight,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.network(url, height: 150, fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) => p == null? w : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (c, e, s) => const SizedBox(height: 60, child: Center(child: Icon(Icons.broken_image, color: Colors.white38))))),
              if (viewOnce) Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Text("3s", style: TextStyle(color: Colors.white, fontSize: 10))),
            ]),
        );
      }
    } else {
      content = Text(d["msg"]?? "", style: TextStyle(color: isMe? Colors.black : Colors.white));
    }

    return Align(
      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: canDel? () => _askDelete(doc.id) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: isMe? Colors.amber : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              if (_fmtTime(t).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_fmtTime(t), style: TextStyle(color: isMe? Colors.black54 : Colors.white38, fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: const Color(0xFF151A2B), title: Row(children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection("users").doc(widget.friendMobile).get(),
            builder: (c, snap) {
              final ph = snap.data?.data() == null? "" : ((snap.data!.data() as Map)["photoUrl"]?.toString()?? "");
              if (ph.isNotEmpty) return CircleAvatar(radius: 16, backgroundImage: NetworkImage(ph));
              return CircleAvatar(radius: 16, backgroundColor: Colors.amber, child: Text(widget.friendName.isNotEmpty? widget.friendName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.black, fontSize: 14)));
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.friendName, style: const TextStyle(color: Colors.white))),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v){ if(v=="clear") _clearChat(); },
            itemBuilder: (_) => [const PopupMenuItem(value: "clear", child: Text("Chat clear karo"))],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: msgCol.orderBy("time", descending: false).snapshots(),
          builder: (context, snap){
            if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.white54))));
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
            final allDocs = snap.data?.docs?? [];
            final docs = allDocs.where((doc){
              final dd = doc.data();
              final hiddenFor = dd["hiddenFor"];
              if (hiddenFor is Map && hiddenFor[widget.myMobile] == true) return false;
              if (_clearedAt!= null) {
                final t = dd["time"];
                if (t is Timestamp &&!t.toDate().isAfter(_clearedAt!)) return false;
              }
              return true;
            }).toList();
            if (docs.isEmpty) return const Center(child: Text("Abhi koi message nahi â€” pehla message bhejo ðŸ‘‹", style: TextStyle(color: Colors.white54)));
            List<Widget> items = [];
            String lastDay = "";
            for (var doc in docs) {
              final mt = doc.data()["time"];
              final DateTime? mdt = mt is Timestamp? mt.toDate() : null;
              if (mdt!= null) {
                final dayKey = "${mdt.year}-${mdt.month}-${mdt.day}";
                if (dayKey!= lastDay) { lastDay = dayKey; items.add(_dateChip(_dayLabel(mdt))); }
              }
              items.add(_bubble(doc));
            }
            return ListView(padding: const EdgeInsets.all(12), children: items);
          },
        )),
        Container(padding: const EdgeInsets.all(8), color: const Color(0xFF151A2B), child: Row(children: [
          IconButton(icon: const Icon(Icons.photo, color: Colors.amber), onPressed: _pickAndSendImage),
          Expanded(child: TextField(controller: msgCtrl, style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: "Message...", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: const Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: Colors.amber, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: sendMsg)),
        ]))
      ])
    );
  }
}

class _PhotoViewScreen extends StatefulWidget {
  final String url; final bool viewOnce; final bool showSave;
  final VoidCallback? onSave; final VoidCallback? onViewed;
  const _PhotoViewScreen({required this.url, required this.viewOnce, this.showSave = false, this.onSave, this.onViewed});
  @override State<_PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<_PhotoViewScreen> {
  int sec = 3;
  @override void initState(){
    super.initState();
    if (widget.viewOnce) {
      widget.onViewed?.call();
      Timer.periodic(const Duration(seconds: 1), (t){
        if (!mounted) { t.cancel(); return; }
        if (sec <= 1) { t.cancel(); Navigator.pop(context); }
        else { setState(()=> sec--); }
      });
    }
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
        title: widget.viewOnce? Text("$sec sec", style: const TextStyle(color: Colors.white)) : null,
        actions: [ if (widget.showSave) IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: widget.onSave) ],
      ),
      body: Center(child: Image.network(widget.url)),
    );
  }
}
