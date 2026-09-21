import 'package:flutter/material.dart';

class ReferralChartScreen extends StatelessWidget {
  const ReferralChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HOW 3 LEVEL PLAN WORKS?"), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(12)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("3 LEVEL INCOME PLAN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 15),
              Text("L1 = ₹100 (Direct Referral)\nL2 = ₹50 (Level 2)\nL3 = ₹25 (Level 3)", style: TextStyle(fontSize: 16)),
              SizedBox(height: 15),
              Text("Note: Only Active Premium users ko hi income milegi.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}