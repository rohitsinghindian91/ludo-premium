import 'package:flutter/material.dart';

class ReferralChartScreen extends StatelessWidget {
  const ReferralChartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("3 Level Plan"), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text("HOW EARNING WORKS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _card("LEVEL 1", "₹100", "Direct Referral", Colors.green),
          _card("LEVEL 2", "₹50", "Your Team's Referral", Colors.blue),
          _card("LEVEL 3", "₹25", "2nd Team's Referral", Colors.orange),
          const SizedBox(height: 20),
          const Text("Note: Earning sirf tab milegi jab Upline ka Premium Active hoga. Expired hone pe earning band.", style: TextStyle(color: Colors.red)),
        ]),
      ),
    );
  }
  Widget _card(String level, String amount, String desc, Color color) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(level, style: TextStyle(fontWeight: FontWeight.bold, color: color)), Text(desc)]), Text(amount, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))])),
  }
}
