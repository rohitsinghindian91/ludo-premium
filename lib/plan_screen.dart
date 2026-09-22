import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  final String mobile;
  const PlanScreen({super.key, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(title: const Text("3 LEVEL PLAN CHART", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)), backgroundColor: Colors.amber),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber, Colors.orange.shade700]), borderRadius: BorderRadius.circular(16)),
              child: const Column(children: [
                Text("💰 LUDO PREMIUM EARNING PLAN 💰", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                SizedBox(height: 6),
                Text("₹500 Premium = 3 Level Income", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 16),
            _levelCard("LEVEL 1", "₹100", "Direct Referral", Icons.person, Colors.green, "Aap jisko direct invite karoge, uske premium se aapko ₹100"),
            const SizedBox(height: 12),
            _levelCard("LEVEL 2", "₹50", "Indirect Referral", Icons.people, Colors.blue, "Aapke Level 1 ka banda jisko invite karega, usse aapko ₹50"),
            const SizedBox(height: 12),
            _levelCard("LEVEL 3", "₹25", "Team Income", Icons.groups_3, Colors.purple, "Level 2 ka banda jisko invite karega, usse aapko ₹25"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF151A2B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.withOpacity(0.3))),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("📋 Rules:", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                Text("• Premium active hona zaruri hai commission ke liye", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("• 3 Level tak hi income milegi", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("• Direct wallet me add hoga", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("• UPI se withdraw kar sakte ho", style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(height: 8),
                Text("Example: 10 Direct + 10 L2 + 10 L3 = ₹1000 + ₹500 + ₹250 = ₹1750", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard(String level, String amount, String title, IconData icon, Color color, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF151A2B), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(level, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ])),
        ],
      ),
    );
  }
}