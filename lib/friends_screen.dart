import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
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
  late TabController tabCtrl;
  final searchCtrl = TextEditingController();
  List<DocumentSnapshot> pending = [];
  List<Map<String, dynamic>> friendsWithName = [];
  List<DocumentSnapshot> searchResult = [];
  bool loading = true;
  String myName = "";
  String myIdNo = "";

  @override void initState() { super.initState(); tabCtrl = TabController(length: 3, vsync: this); loadAll(); }

  Future<void> loadAll() async {
    setState((){ loading = true; });
    try {
      var me = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
      myName = me.data()?["name"]?? "You";
      myIdNo = me.data()?["voiceRoomNo"]?.toString()?? "";
      // FIX: composite index se bachne ke liye sirf "to" par query, status ka filter code me
      var p = await FirebaseFirestore.instance.collection("friend_requests").where("to", isEqualTo: widget.mobile).get();
      var pendingDocs = p.docs.where((d) => (d.data() as Map<String, dynamic>)["status"] == "pending").toList();
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
      setState((){ pending = pendingDocs; friendsWithName = temp; loading = false; });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sabhi chats clear ho gayi ✅")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fail: $e")));
    }
  }

  // ID NUMBER se search - 7 digit ka permanent ID (voice room number)
  // Mobile number kisi ko nahi dikhega, sirf ID se dhoondo aur add karo
  Future<void> searchUser() async {
    String s = searchCtrl.text.trim();
    if(s.length!=7) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("7 digit ka ID number dalo"))); return; }
    if(s==myIdNo) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ye tumhari apni ID hai"))); return; }
    try {
      var q = await FirebaseFirestore.instance.collection("users").where("voiceRoomNo", isEqualTo: s).limit(1).get();
      if(q.docs.isEmpty){ setState(()=> searchResult=[]); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Is ID ka koi user nahi mila"))); return; }
      var doc = q.docs.first;
      if(doc.id==widget.mobile){ setState(()=> searchResult=[]); return; }
      setState(()=> searchResult=[doc]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search fail: $e")));
    }
  }

  Future<void> sendRequest(String toMobile) async {
    try {
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

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Colors.amber, title: Text("FRIENDS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: Icon(Icons.delete_sweep, color: Colors.black), tooltip: "Sabhi chats clear karo",
            onPressed: _clearAllChats),
        ],
        bottom: TabBar(controller: tabCtrl, labelColor: Colors.black, tabs: [Tab(text: "ADD"), Tab(text: "REQUESTS (${pending.length})"), Tab(text: "MY FRIENDS (${friendsWithName.length})")])),
      body: loading? Center(child: CircularProgressIndicator(color: Colors.amber)):
      TabBarView(controller: tabCtrl, children: [
        Padding(padding: EdgeInsets.all(16), child: Column(children: [
          if(myIdNo.isNotEmpty)
            Container(margin: EdgeInsets.only(bottom:12), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.4))),
              child: Row(children: [Icon(Icons.badge, color: Colors.amber), SizedBox(width:8), Text("Tumhari ID: $myIdNo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(width:4), Expanded(child: Text("(dosto ko ye ID do)", style: TextStyle(color: Colors.white54, fontSize: 11)))])),
          Row(children: [Expanded(child: TextField(controller: searchCtrl, keyboardType: TextInputType.number, maxLength: 7, style: TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: "", labelText: "ID Number se Search (7 digit)", labelStyle: TextStyle(color: Colors.white54, fontSize: 12), filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))), SizedBox(width:8), ElevatedButton(onPressed: searchUser, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text("SEARCH", style: TextStyle(color: Colors.black))) ]),
          SizedBox(height:8),
          Text("Mobile number kisi ko nahi dikhega - sirf ID se add karo", style: TextStyle(color: Colors.white38, fontSize: 11)),
          SizedBox(height:12),
          Expanded(child: searchResult.isEmpty? Center(child: Text("ID dalke SEARCH dabao", style: TextStyle(color: Colors.white54))): ListView.builder(itemCount: searchResult.length, itemBuilder: (c,i){ var d=searchResult[i].data() as Map; String name = d["name"]?? "User"; String fid = d["voiceRoomNo"]?.toString()?? ""; String toMobile = searchResult[i].id; return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [CircleAvatar(backgroundColor: Colors.amber, child: Text(name.substring(0,1).toUpperCase(), style: TextStyle(color: Colors.black))), SizedBox(width:12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: $fid", style: TextStyle(color: Colors.white54, fontSize: 11))])), ElevatedButton(onPressed: ()=>sendRequest(toMobile), child: Text("ADD"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)) ])); }))
        ])),
        pending.isEmpty? Center(child: Text("Koi request nahi", style: TextStyle(color: Colors.white54))): ListView.builder(padding: EdgeInsets.all(12), itemCount: pending.length, itemBuilder: (c,i){ var data=pending[i].data() as Map; String fromName = data["fromName"]?? "Kisi ne"; return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text("$fromName ne request bheji", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), ElevatedButton(onPressed: ()=>acceptRequest(pending[i]), child: Text("Accept"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)), SizedBox(width:6), ElevatedButton(onPressed: ()=>rejectRequest(pending[i]), child: Text("Reject"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)) ])); }),
        friendsWithName.isEmpty? Center(child: Text("Koi friend nahi", style: TextStyle(color: Colors.white54))): ListView.builder(padding: EdgeInsets.all(12), itemCount: friendsWithName.length, itemBuilder: (c,i){ var data=friendsWithName[i]; String fname = data["name"]; String fm = data["mobile"]; String fid = data["idNo"]?? ""; return Container(margin: EdgeInsets.only(bottom:10), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)), child: Row(children: [CircleAvatar(backgroundColor: Colors.green, child: Text(fname.substring(0,1).toUpperCase(), style: TextStyle(color: Colors.white))), SizedBox(width:12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fname, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("ID: $fid", style: TextStyle(color: Colors.white54, fontSize: 11))])), IconButton(icon: Icon(Icons.chat, color: Colors.amber), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> PrivateChatScreen(myMobile: widget.mobile, friendMobile: fm, friendName: fname, myName: myName))); }) ])); })
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
  DateTime? _clearedAt; // is time se pehle ke msgs sirf mere liye hidden (Firestore se delete NAHI hote)

  String getChatId(){ List<String> s=[widget.myMobile, widget.friendMobile]; s.sort(); return s.join("_"); }

  CollectionReference<Map<String,dynamic>> get msgCol =>
      FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages");

  @override
  void initState() {
    super.initState();
    _loadClearedAt();
  }

  // Maine kab chat clear ki thi - us time se pehle ke msgs mujhe nahi dikhenge
  // (Firestore se delete NAHI hota - admin panel me sab dikhta rahega)
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

  // TIME FORMAT: 10:45 PM
  String _fmtTime(Timestamp? t){
    if (t == null) return "";
    final dt = t.toDate();
    int h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = h >= 12? "PM" : "AM";
    h = h % 12; if (h == 0) h = 12;
    return "$h:$m $ap";
  }

  // DATE LABEL: Today / Yesterday / 28 Sep 2026
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

  // DATE CHIP: ek din ki chat ke upar ek patti
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

  // CHAT CLEAR (sirf mere liye) - Firestore se delete NAHI hota, admin panel me sab safe
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
      _toast("Chat clear ho gayi ✅");
    } catch (e) { _toast("Fail: $e"); }
  }

  // Cloudinary par photo upload
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

  // Photo bhejo - view-once (3 sec) ya normal
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

  // 2 minute ke andar hi delete for everyone milega
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
    // SOFT DELETE - dono ke inbox se gayab, lekin Firestore me doc rehta hai (admin panel me dikhega)
    if (yes == true) {
      await msgCol.doc(docId).set({"hiddenFor": {widget.myMobile: true, widget.friendMobile: true}}, SetOptions(merge: true));
      _toast("Delete ho gaya");
    }
  }

  // Normal photo gallery me save karo (gal package)
  Future<void> _savePhoto(String url) async {
    try {
      _toast("Save ho rahi hai...");
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      final res = await http.get(Uri.parse(url));
      await Gal.putImageBytes(Uint8List.fromList(res.bodyBytes), name: "chat_${DateTime.now().millisecondsSinceEpoch}");
      _toast("Gallery me save ho gayi ✅");
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
        content = const Text("Dekh liya 👀", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic));
      } else {
        content = GestureDetector(
          onTap: () => _openPhoto(doc),
          child: Stack(alignment: Alignment.topRight, children: [
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
      appBar: AppBar(backgroundColor: const Color(0xFF151A2B), title: Text(widget.friendName, style: const TextStyle(color: Colors.white)),
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
            // mere liye hidden/clear kiye gaye msgs mat dikhao (Firestore se delete NAHI hote - admin ko dikhte rahenge)
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
            if (docs.isEmpty) return const Center(child: Text("Abhi koi message nahi — pehla message bhejo 👋", style: TextStyle(color: Colors.white54)));
            // DATE HEADER: ek din ki chat ke upar ek baar - Today / Yesterday / date
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

// Photo dekhne wali screen - view-once 3 sec me band, normal me Save button
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
