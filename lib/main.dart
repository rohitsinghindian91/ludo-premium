        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)), child: Column(children: [
          const Text("Is UPI pe ₹500 bhejo:", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          SelectableText(myUpiId, style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Amount: ₹500", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ])),
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => payViaUpi(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("PAY VIA GPAY / PHONEPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => iHavePaid(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("I HAVE PAID ₹500", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 20),
        const Text("Note: Pay karne ke baad 'I HAVE PAID' dabao. Firebase > premium_requests me request ayegi.", style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
      ])),
    );
  }
}

class LudoBoard extends StatefulWidget { const LudoBoard({super.key}); @override State<LudoBoard> createState()=>_LudoBoardState(); }
class _LudoBoardState extends State<LudoBoard> {
  int dice=1; int pos=0; final rand=Random();
  void roll(){ setState((){ dice=rand.nextInt(6)+1; pos=(pos+dice)%36; }); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text("LUDO PREMIUM"), backgroundColor:Colors.amber), backgroundColor: const Color(0xFF0F172A),
      body:SingleChildScrollView(child: Column(children:[
        const SizedBox(height:15),
        Center(child: Container(width: 350, height: 350, padding: const EdgeInsets.all(5), decoration:BoxDecoration(color:Colors.white, border:Border.all(width:4, color:Colors.amber), borderRadius:BorderRadius.circular(15)), 
          child: GridView.builder(physics: const NeverScrollableScrollPhysics(), gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:6, crossAxisSpacing:3, mainAxisSpacing:3), itemCount:36, itemBuilder:(c,i){ bool here=i==pos; return Container(decoration:BoxDecoration(color:here?Colors.green: const Color(0xFFE0E0E0), borderRadius:BorderRadius.circular(8)), child: Center(child: here ? const Text("😎", style: TextStyle(fontSize:20)) : Text("$i", style:const TextStyle(fontSize:10)))); }))),
        const SizedBox(height:25), Text("$dice", style:const TextStyle(fontSize:60, color:Colors.white, fontWeight:FontWeight.bold)),
        const SizedBox(height:15), SizedBox(width:200, height:55, child: ElevatedButton(onPressed:roll, style:ElevatedButton.styleFrom(backgroundColor:Colors.amber, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))), child:const Text("ROLL DICE 🎲", style:TextStyle(color:Colors.black, fontWeight:FontWeight.bold, fontSize:18)))),
      ])),
    );
  }
}