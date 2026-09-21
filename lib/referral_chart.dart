import 'package:flutter/material.dart';
class ReferralChartScreen extends StatelessWidget {
  const ReferralChartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("3 Level Plan"), backgroundColor: Colors.amber),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("L1 = Rs 100 - Direct", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("L2 = Rs 50 - Team", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("L3 = Rs 25 - 2nd Team", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text("Note: Premium active par hi earning milegi.", style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}