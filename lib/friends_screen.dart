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
    var me = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).get();
    myName = me.data()?["name"]?? "You";
    myIdNo = me.data()?["voiceRoomNo"]?.toString()?? "";
    var p = await FirebaseFirestore.instance.collection("friend_requests").where("to", isEqualTo: widget.mobile).where("status", isEqualTo: "pending").get();
    var f = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").get();
    List<Map<String, dynamic>> temp = [];
    for(var doc in f.docs){
      String fm = doc.data()["mobile"];
      var userDoc = await FirebaseFirestore.instance.collection("users").doc(fm).get();
      String fname = userDoc.data()?["name"]?? "Friend";
      String fid = userDoc.data()?["voiceRoomNo"]?.toString()?? "";
      temp.add({"mobile": fm, "name": fname, "idNo": fid});
    }
    setState((){ pending = p.docs; friendsWithName = temp; loading = false; });
  }

  // ID NUMBER se search - 7 digit ka permanent ID (voice room number)
  // Mobile number kisi ko nahi dikhega, sirf ID se dhoondo aur add karo
  Future<void> searchUser() async {
    String s = searchCtrl.text.trim();
    if(s.length!=7) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("7 digit ka ID number dalo"))); return; }
    if(s==myIdNo) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ye tumhari apni ID hai"))); return; }
    var q = await FirebaseFirestore.instance.collection("users").where("voiceRoomNo", isEqualTo: s).limit(1).get();
    if(q.docs.isEmpty){ setState(()=> searchResult=[]); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Is ID ka koi user nahi mila"))); return; }
    var doc = q.docs.first;
    if(doc.id==widget.mobile){ setState(()=> searchResult=[]); return; }
    setState(()=> searchResult=[doc]);
  }

  Future<void> sendRequest(String toMobile) async {
    var q = await FirebaseFirestore.instance.collection("friend_requests").where("from", isEqualTo: widget.mobile).where("to", isEqualTo: toMobile).where("status", isEqualTo: "pending").get();
    if(q.docs.isNotEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se bhej rakhi hai"))); return; }
    var fr = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").doc(toMobile).get();
    if(fr.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se friend hai"))); return; }
    await FirebaseFirestore.instance.collection("friend_requests").add({"from": widget.mobile, "to": toMobile, "fromName": myName, "status": "pending", "time": FieldValue.serverTimestamp()});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request bhej di")));
  }

  Future<void> acceptRequest(DocumentSnapshot req) async {
    var data = req.data() as Map<String,dynamic>;
    String from = data["from"]; String to = data["to"];
    await FirebaseFirestore.instance.collection("users").doc(to).collection("friends").doc(from).set({"mobile": from, "addedAt": FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection("users").doc(from).collection("friends").doc(to).set({"mobile": to, "addedAt": FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "accepted"});
    loadAll();
  }

  Future<void> rejectRequest(DocumentSnapshot req) async {
    await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "rejected"});
    loadAll();
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Colors.amber, title: Text("FRIENDS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
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

// ============ PRIVATE CHAT: text + photo (view-once/normal) + 2 min delete for everyone ============
class PrivateChatScreen extends StatefulWidget {
  final String myMobile; final String friendMobile; final String friendName; final String myName;
  const PrivateChatScreen({super.key, required this.myMobile, required this.friendMobile, required this.friendName, required this.myName});
  @override State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final msgCtrl = TextEditingController();

  String getChatId(){ List<String> s=[widget.myMobile, widget.friendMobile]; s.sort(); return s.join("_"); }

  CollectionReference<Map<String,dynamic>> get msgCol =>
      FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages");

  void _toast(String s){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2))); }

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
    String text = msgCtrl.text.trim(); msgCtrl.clear();
    await msgCol.add({
      "from": widget.myMobile, "fromName": widget.myName, "to": widget.friendMobile,
      "type": "text", "msg": text, "viewedBy": {}, "time": FieldValue.serverTimestamp(),
    });
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
    if (yes == true) { await msgCol.doc(docId).delete(); _toast("Delete ho gaya"); }
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
          child: content,
        ),
      ),
    );
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: const Color(0xFF151A2B), title: Text(widget.friendName, style: const TextStyle(color: Colors.white))),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: msgCol.orderBy("time", descending: false).snapshots(),
          builder: (context, snap){
            if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("Error: ${snap.error}", style: const TextStyle(color: Colors.white54))));
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
            final docs = snap.data?.docs?? [];
            if (docs.isEmpty) return const Center(child: Text("Abhi koi message nahi — pehla message bhejo 👋", style: TextStyle(color: Colors.white54)));
            return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (c,i) => _bubble(docs[i]));
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
