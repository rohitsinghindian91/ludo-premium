import 'package:flutter/material.dart';

class JaruriSuchnaScreen extends StatelessWidget {
  const JaruriSuchnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final points = [
      "18+ wale users hi is application ko use karein.",
      "Premium active hoga tabhi aapko commission milega.",
      "Commission sirf tabhi milega jab aapka premium active hai aur jisko aapne referral kiya usne premium liya hai. Sirf application referral karne se commission nahi milega.",
      "Premium active karne ke baad aapka premium sirf 1 month ke liye active hoga aur jese hi aapka premium khatm ho jaye to dobara 500 rs deke hi reactive kar sakte hai.",
      "Ludo game sirf premium users hi khel sakte hai.",
      "Aapka commission sirf Monday ko hi aayega. Every Monday wo commission aapko 11 baje ke baad us UPI ID me daal diya jayega jo aapne set ki hai.",
      "NOTE: Kisi bhi other application ki promotion karte ho ya kisi ke sath gali galoch karte ho, kisi ki personal information share karte ho to aapka ID banned kiya ja sakta hai.",
      "Kisi bhi anjaan ko apni personal information share na karein.",
      "Kisi bhi user ke sath peso ka len den na karein, wo aapki khud ki zimmedari hai.",
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Text("JRURI SUCHNA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: points.length,
        itemBuilder: (ctx, i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151A2B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${i + 1}. ", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                Expanded(
                  child: Text(points[i], style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
