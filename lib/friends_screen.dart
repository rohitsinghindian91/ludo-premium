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
  List<DocumentSnapshot> friends = [];
  List<DocumentSnapshot> searchResult = [];
  bool loading = true;

  @override void initState() {
    super.initState();
    tabCtrl = TabController(length: 3, vsync: this);
    loadAll();
  }

  Future<void> loadAll() async {
    setState((){ loading = true; });
    var p = await FirebaseFirestore.instance.collection("friend_requests").where("to", isEqualTo: widget.mobile).where("status", isEqualTo: "pending").get();
    var f = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").get();
    setState((){ pending = p.docs; friends = f.docs; loading = false; });
  }

  Future<void> searchUser() async {
    String s = searchCtrl.text.trim();
    if(s.length!= 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("10 digit mobile dalo")));
      return;
    }
    if(s == widget.mobile){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Khud ko add nahi kar sakte")));
      return;
    }
    var doc = await FirebaseFirestore.instance.collection("users").doc(s).get();
    if(!doc.exists){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User nahi mila")));
      setState(()=> searchResult = []);
      return;
    }
    setState(()=> searchResult = [doc]);
  }

  Future<void> sendRequest(String toMobile) async {
    var q = await FirebaseFirestore.instance.collection("friend_requests").where("from", isEqualTo: widget.mobile).where("to", isEqualTo: toMobile).where("status", isEqualTo: "pending").get();
    if(q.docs.isNotEmpty){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se request bheji hui hai")));
      return;
    }
    var fr = await FirebaseFirestore.instance.collection("users").doc(widget.mobile).collection("friends").doc(toMobile).get();
    if(fr.exists){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pehle se friend hai")));
      return;
    }
    await FirebaseFirestore.instance.collection("friend_requests").add({
      "from": widget.mobile,
      "to": toMobile,
      "status": "pending",
      "time": FieldValue.serverTimestamp()
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request bhej di $toMobile ko")));
  }

  Future<void> acceptRequest(DocumentSnapshot req) async {
    var data = req.data() as Map<String,dynamic>;
    String from = data["from"];
    String to = data["to"];
    await FirebaseFirestore.instance.collection("users").doc(to).collection("friends").doc(from).set({
      "mobile": from,
      "addedAt": FieldValue.serverTimestamp()
    });
    await FirebaseFirestore.instance.collection("users").doc(from).collection("friends").doc(to).set({
      "mobile": to,
      "addedAt": FieldValue.serverTimestamp()
    });
    await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "accepted"});
    loadAll();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Friend ban gaye $from ke")));
  }

  Future<void> rejectRequest(DocumentSnapshot req) async {
    await FirebaseFirestore.instance.collection("friend_requests").doc(req.id).update({"status": "rejected"});
    loadAll();
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Text("FRIENDS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: tabCtrl,
          labelColor: Colors.black,
          tabs: [Tab(text: "ADD"), Tab(text: "REQUESTS (${pending.length})"), Tab(text: "MY FRIENDS (${friends.length})")]
        )
      ),
      body: loading? Center(child: CircularProgressIndicator(color: Colors.amber)) :
      TabBarView(
        controller: tabCtrl,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: searchCtrl, keyboardType: TextInputType.phone, maxLength: 10, style: TextStyle(color: Colors.white), decoration: InputDecoration(counterText: "", labelText: "Mobile Number Search", filled: true, fillColor: Color(0xFF151A2B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    SizedBox(width: 8),
                    ElevatedButton(onPressed: searchUser, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: Text("SEARCH", style: TextStyle(color: Colors.black)))
                  ]
                ),
                SizedBox(height: 20),
                Expanded(
                  child: searchResult.isEmpty? Center(child: Text("Koi user search karo", style: TextStyle(color: Colors.white54))) :
                  ListView.builder(
                    itemCount: searchResult.length,
                    itemBuilder: (c,i){
                      var d = searchResult[i].data() as Map<String,dynamic>;
                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: Colors.amber, child: Text(d["mobile"].toString().substring(0,2), style: TextStyle(color: Colors.black))),
                            SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d["mobile"], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(d["isPremium"]==true?"Premium":"Free", style: TextStyle(color: Colors.white54, fontSize: 11))])),
                            ElevatedButton(onPressed: ()=> sendRequest(d["mobile"]), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text("ADD"))
                          ]
                        )
                      );
                    }
                  )
                )
              ]
            )
          ),
          pending.isEmpty? Center(child: Text("Koi request nahi", style: TextStyle(color: Colors.white54))) :
          ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: pending.length,
            itemBuilder: (c,i){
              var data = pending[i].data() as Map<String,dynamic>;
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                    SizedBox(width: 12),
                    Expanded(child: Text("${data["from"]} ne request bheji", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ElevatedButton(onPressed: ()=> acceptRequest(pending[i]), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(60,36)), child: Text("Accept", style: TextStyle(fontSize: 11))),
                    SizedBox(width: 6),
                    ElevatedButton(onPressed: ()=> rejectRequest(pending[i]), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: Size(60,36)), child: Text("Reject", style: TextStyle(fontSize: 11)))
                  ]
                )
              );
            }
          ),
          friends.isEmpty? Center(child: Text("Abhi koi friend nahi, ADD se banao", style: TextStyle(color: Colors.white54))) :
          ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: friends.length,
            itemBuilder: (c,i){
              var data = friends[i].data() as Map<String,dynamic>;
              String fm = data["mobile"];
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Color(0xFF151A2B), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: Colors.green, child: Text(fm.substring(0,2), style: TextStyle(color: Colors.white))),
                    SizedBox(width: 12),
                    Expanded(child: Text(fm, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    IconButton(icon: Icon(Icons.chat, color: Colors.amber), onPressed: (){
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(myMobile: widget.mobile, friendMobile: fm)));
                    })
                  ]
                )
              );
            }
          )
        ]
      )
    );
  }
}

class PrivateChatScreen extends StatefulWidget {
  final String myMobile;
  final String friendMobile;
  const PrivateChatScreen({super.key, required this.myMobile, required this.friendMobile});
  @override State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final msgCtrl = TextEditingController();
  String getChatId(){ List<String> s = [widget.myMobile, widget.friendMobile]; s.sort(); return s.join("_"); }
  Future<void> sendMsg() async {
    if(msgCtrl.text.trim().isEmpty) return;
    String text = msgCtrl.text.trim(); msgCtrl.clear();
    await FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages").add({
      "from": widget.myMobile,
      "to": widget.friendMobile,
      "msg": text,
      "time": FieldValue.serverTimestamp()
    });
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      appBar: AppBar(backgroundColor: Color(0xFF151A2B), title: Text(widget.friendMobile, style: TextStyle(color: Colors.white)), iconTheme: IconThemeData(color: Colors.white)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection("friend_chats").doc(getChatId()).collection("messages").orderBy("time", descending: false).snapshots(),
              builder: (context, snapshot){
                if(!snapshot.hasData) return Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if(docs.isEmpty) return Center(child: Text("Koi message nahi, pehla bhejo", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (c,i){
                    var d = docs[i].data();
                    bool isMe = d["from"] == widget.myMobile;
                    return Align(
                      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: isMe? Colors.amber : Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                        child: Text(d["msg"]?? "", style: TextStyle(color: isMe? Colors.black : Colors.white))
                      )
                    );
                  }
                );
              }
            )
          ),
          Container(
            padding: EdgeInsets.all(8),
            color: Color(0xFF151A2B),
            child: Row(
              children: [
                Expanded(child: TextField(controller: msgCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Message likho...", hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF0A0E1A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
                SizedBox(width: 8),
                CircleAvatar(backgroundColor: Colors.amber, child: IconButton(icon: Icon(Icons.send, color: Colors.black), onPressed: sendMsg))
              ]
            )
          )
        ]
      )
    );
  }
}