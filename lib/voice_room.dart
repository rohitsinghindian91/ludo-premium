const SizedBox(height: 12),
SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(
  onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceLobbyScreen())); },
  icon: const Icon(Icons.mic, color: Colors.white),
  label: const Text("VOICE CHAT ROOM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
)),
