import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class PrivateChatScreen extends StatefulWidget {
  final String myMobile; final String friendMobile; final String friendName; final String myName;
  const PrivateChatScreen({super.key, required this.myMobile, required this.friendMobile, required this.friendName, required this.myName});
  @override State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final msgCtrl = TextEditingController();
  String getChatId(){ List<String> s=[widget.myMobile, widget.friendMobile]; s.sort(); return s.join("_"); }
  Future<void> sendMsg() async {
    if(msgCtrl.text.trim().isEmpty) return;
    String text=msgCtrl.text.trim(); msgCtrl.clear();
    await FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages").add({"from": widget.myMobile, "fromName": widget.myName, "to": widget.friendMobile, "msg": text, "time": FieldValue.serverTimestamp()});
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Color(0xFF151A2B), title: Text(widget.friendName, style: TextStyle(color: Colors.white))),
      body: Column(children: [
        Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages").orderBy("time", descending: false).snapshots(), builder: (context,snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); var docs=snap.data!.docs; return ListView.builder(padding: EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (c,i){ var d=docs[i].data(); bool isMe=d["from"]==widget.myMobile; return Align(alignment: isMe? Alignment.centerRight: Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical:4), padding: EdgeInsets.symmetric(horizontal:14, vertical:10), decoration: BoxDecoration(color: isMe? Colors.amber: Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Text(d["msg"]??"", style: TextStyle(color: isMe? Colors.black: Colors.white)))); }); })),
        Container(padding: EdgeInsets.all(8), color: Color(0xFF151A2B), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Message...", filled: true, fillColor: Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))), SizedBox(width:8), CircleAvatar(backgroundColor: Colors.amber, child: IconButton(icon: Icon(Icons.send, color: Colors.black), onPressed: sendMsg)) ]))
      ])
    );
  }
}
