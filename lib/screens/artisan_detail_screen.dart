import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> artisanData;

  const ArtisanDetailScreen({super.key, required this.artisanData});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.artisanData['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.artisanData['fullName'] ?? 'Usta';
    final phone = widget.artisanData['phone'] ?? 'Qeyd olunmayıb';
    final role = widget.artisanData['role'] == 'usta' ? 'Peşəkar Usta' : 'Fəhlə / Köməkçi';
    final isVerified = widget.artisanData['isVerified'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profil kartı
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                  child: const Icon(Icons.handyman, size: 48, color: Color(0xFF1769D2)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(role, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 4),
                    Text('4.9 (120 rəy)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Əlaqə düymələri (Zəng və WhatsApp)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name ilə əlaqə: $phone')),
                    );
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Zəng et'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('WhatsApp açılır: $phone')),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1 DƏQİQƏLİK TANITIM VİDEOSU
          const Text(
            'Ustanın Tanıtım və İş Videosu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (_videoController != null && _isVideoInitialized) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_videoController!),
                    VideoProgressIndicator(_videoController!, allowScrubbing: true),
                    Center(
                      child: IconButton(
                        iconSize: 50,
                        color: Colors.white,
                        icon: Icon(
                          _videoController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                        ),
                        onPressed: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (widget.artisanData['videoUrl'] != null &&
              (widget.artisanData['videoUrl'] as String).isNotEmpty) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.videocam_off, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Usta hələ ki video əlavə etməyib.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Haqqında məlumat
          const Text('Xidmət haqqında', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'Hər növ təmir və quraşdırma işlərini zəmanətlə və vaxtında təhvil verirəm. Keyfiyyətli materiallar və müasir avadanlıqlarla işləyirəm.',
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
