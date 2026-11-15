import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TikTokEmbedView extends StatelessWidget {
  final String videoId;
  final String? embedUrl;
  final String? originalUrl;
  final String? title;
  final String? authorName;
  final String? thumbnailUrl;

  const TikTokEmbedView({
    super.key,
    required this.videoId,
    this.embedUrl,
    this.originalUrl,
    this.title,
    this.authorName,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    final targetUrl = originalUrl ?? (embedUrl ?? 'https://www.tiktok.com/@tiktok/video/$videoId');

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Arxa fon örtük şəkli
          if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            Image.network(
              thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackBackground(),
            )
          else
            _buildFallbackBackground(),

          // Qaranlıq qat
          Container(
            color: Colors.black.withOpacity(0.45),
          ),

          // Mərkəzi TikTok Play Düyməsi və İnteqrasiya
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(targetUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFE2C55), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFE2C55).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFE2C55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TikTok-da Canlı İzlə',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
