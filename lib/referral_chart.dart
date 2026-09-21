import 'package:flutter/material.dart';

class ReferralChartScreen extends StatelessWidget {
  const ReferralChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBBF24),
        title: const Text("HOW 3 LEVEL PLAN WORKS...", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.emoji_events, color: Colors.black)),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("LUDO PREMIUM", style: TextStyle(color: Colors.amber, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("3 LEVEL PLAN", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.circle, size: 12, color: Colors.greenAccent), SizedBox(width: 5), Text("LIVE PLAN", style: TextStyle(color: Colors.white70, fontSize: 12))])),
              ],
            ),
            const SizedBox(height: 25),
            RichText(text: const TextSpan(style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), children: [TextSpan(text: "Refer & Earn ", style: TextStyle(color: Colors.white)), TextSpan(text: "3 Level", style: TextStyle(color: Colors.amber)), TextSpan(text: " Tak", style: TextStyle(color: Colors.white))])),
            const SizedBox(height: 8),
            const Text("Premium active rakho, team banao, har active member se commission.", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            
            _levelCard(title: "YOU", sub: "Main Account • Earning Unlocked", badge: "PREMIUM ACTIVE", icon: Icons.emoji_events, price: null, isYou: true),
            const _Arrow(),
            _levelCard(title: "L1 - Direct Refer", sub: "Aapke direct invite kiye hue members", badge: "₹100 / USER", price: "₹100 per Active Member", commissionLabel: "Commission", color: Colors.greenAccent),
            const _Arrow(),
            _levelCard(title: "L2 - Team Refer", sub: "Aapke L1 ki team ke members", badge: "₹50 / USER", price: "₹50 per Active Member", commissionLabel: "Commission", color: Colors.lightBlueAccent),
            const _Arrow(),
            _levelCard(title: "L3 - Extended Team", sub: "Aapke L2 ki team ke members", badge: "₹25 / USER", price: "₹25 per Active Member", commissionLabel: "Commission", color: Colors.purpleAccent),

            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade800)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.green)), child: const Icon(Icons.info_outline, color: Colors.green, size: 20)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("IMPORTANT NOTE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Commission sirf tab milega jab aapka Premium Active hoga aur aapke team member ka bhi Premium Active hoga. Free user ko koi commission nahi.", style: TextStyle(color: Colors.white70, height: 1.4)),
                  ])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard({required String title, required String sub, String? badge, String? price, String? commissionLabel, Color? color, bool isYou = false, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: isYou ? Colors.amber.withOpacity(0.2) : Colors.white10, child: Icon(icon ?? Icons.group, color: isYou ? Colors.amber : color)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: isYou ? Colors.white : Colors.white, fontWeight: FontWeight.bold, fontSize: isYou ? 18 : 16)),
                Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
              if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (color ?? Colors.amber).withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(badge, style: TextStyle(color: color ?? Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(commissionLabel ?? "", style: const TextStyle(color: Colors.white54)),
              Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ])),
          ]
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Icon(Icons.arrow_downward, color: Colors.white24)));
  }
}