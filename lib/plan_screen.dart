import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("3 LEVEL PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.workspace_premium, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("LUDO PREMIUM", style: TextStyle(color: Colors.amber, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const Text("3 LEVEL PLAN", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                  child: Row(children: const [
                    Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text("LIVE PLAN", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))
                  ]),
                )
              ],
            ),
            const SizedBox(height: 25),
            RichText(text: const TextSpan(children: [
              TextSpan(text: "Refer & Earn ", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              TextSpan(text: "3 Level", style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.w900)),
              TextSpan(text: " Tak", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            ])),
            const SizedBox(height: 8),
            const Text("Premium active rakho, team banao, har active member se commission.", style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 2), color: Colors.amber.withOpacity(0.2)),
                        child: const Center(child: Text("👑", style: TextStyle(fontSize: 28))),
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.verified, size: 14, color: Colors.white))),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text("YOU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Text("• PREMIUM ACTIVE", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                    ]),
                    const Text("Main Account • Earning Unlocked", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ])),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.amber.withOpacity(0.5))), child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 20)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Column(children: [Container(width: 2, height: 20, color: Colors.green.withOpacity(0.5)), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.green.withOpacity(0.5))), child: const Icon(Icons.arrow_downward, size: 16, color: Colors.greenAccent))])),

            _levelCard(
              colors: [Colors.purple, Colors.pink, Colors.blue, Colors.orange, Colors.teal],
              letters: ["A","B","C","D","E"],
              badge: "₹100 / USER", badgeColor: Colors.greenAccent,
              title1: "L1 - ", title2: "Direct Refer", title2Color: Colors.greenAccent,
              subtitle: "Aapke direct invite kiye hue members",
              commission: "₹100 per Active Member",
            ),
            const SizedBox(height: 12),
            Center(child: Column(children: [Container(width: 2, height: 20, color: Colors.blue.withOpacity(0.5)), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.blue.withOpacity(0.5))), child: const Icon(Icons.arrow_downward, size: 16, color: Colors.blueAccent))])),

            _levelCard(
              colors: [Colors.purple, Colors.blue, Colors.orange, Colors.green, Colors.orange, Colors.teal, Colors.purple],
              letters: ["1","2","3","4","5","6","7"],
              badge: "₹50 / USER", badgeColor: Colors.lightBlueAccent,
              title1: "L2 - ", title2: "Team Refer", title2Color: Colors.lightBlueAccent,
              subtitle: "Aapke L1 ki team ke members",
              commission: "₹50 per Active Member",
            ),
            const SizedBox(height: 12),
            Center(child: Column(children: [Container(width: 2, height: 20, color: Colors.purple.withOpacity(0.5)), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.purple.withOpacity(0.5))), child: const Icon(Icons.arrow_downward, size: 16, color: Colors.purpleAccent))])),

            _levelCard(
              isDots: true,
              badge: "₹25 / USER", badgeColor: Colors.purpleAccent,
              title1: "L3 - ", title2: "Extended Team", title2Color: Colors.purpleAccent,
              subtitle: "Aapke L2 ki team ke members",
              commission: "₹25 per Active Member",
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.info_outline, color: Colors.greenAccent, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("IMPORTANT NOTE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    RichText(text: const TextSpan(style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), children: [
                      TextSpan(text: "Commission sirf tab milega jab "),
                      TextSpan(text: "aapka Premium Active hoga", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      TextSpan(text: " aur aapke team member ka bhi "),
                      TextSpan(text: "Premium Active hoga.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      TextSpan(text: " Free user ko koi commission nahi."),
                    ])),
                  ])),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _levelCard({
    List<Color>? colors,
    List<String>? letters,
    bool isDots = false,
    required String badge,
    required Color badgeColor,
    required String title1,
    required String title2,
    required Color title2Color,
    required String subtitle,
    required String commission,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: isDots
                   ? Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(8, (i) => Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: Colors.white12)), child: const Center(child: Icon(Icons.circle, size: 8, color: Colors.white24))))..add(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Text("+MORE", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)))),
                      )
                    : SizedBox(
                        height: 36,
                        child: Stack(
                          children: [
                            for (int i = 0; i < (letters?.length?? 0); i++)
                              Positioned(
                                left: i * 28.0,
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: colors![i % colors.length], shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1E293B), width: 2)),
                                  child: Center(child: Text(letters![i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                                ),
                              ),
                            Positioned(left: (letters!.length * 28.0), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1E293B), width: 2)), child: const Center(child: Text("+∞", style: TextStyle(color: Colors.white70, fontSize: 10))))),
                          ],
                        ),
                      ),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)), child: Text(badge, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: title2Color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.people_outline, color: title2Color, size: 18)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(children: [TextSpan(text: title1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), TextSpan(text: title2, style: TextStyle(color: title2Color, fontWeight: FontWeight.bold, fontSize: 15))])),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Commission", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(commission, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          )
        ],
      ),
    );
  }
}