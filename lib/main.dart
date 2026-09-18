import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(MaterialApp(debugShowCheckedModeBanner: false, home: PayScreen()));

class PayScreen extends StatelessWidget {
  final upi = "Kumar131@fam";
  void pay() async {
    final uri = Uri.parse("upi://pay?pa=$upi&pn=Ludo Premium&am=500&cu=INR&tn=Premium 30 Days");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ludo Premium"), backgroundColor: Colors.green),
      body: Center(
        child: ElevatedButton(
          onPressed: pay,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: Size(250,60)),
          child: Text("500rs Pay - $upi", style: TextStyle(fontSize: 20, color: Colors.white)),
        ),
      ),
    );
  }
}