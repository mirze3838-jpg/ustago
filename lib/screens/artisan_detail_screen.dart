import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = '994${clean.substring(1)}';
    final Uri uri = Uri.parse('https://wa.me/$clean?text=Salam%20$name,%20UstaGo-dan%20əlaqə%20saxlayıram.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.artisanData['fullName'] ?? widget.artisanData['name'] ?? 'Usta';
    final phone = widget.artisanData['phone'] ?? '';
    final category = widget.artisanData['category'] ?? widget.artisanData['trade'] ?? 'Tikinti';
    final isVerified = widget.artisanData['isVerified'] == true;
    final photoBase64 = widget.artisanData['photoBase64'] as String?;
    final userId = widget.artisanData['uid'] ?? widget.artisanData['userId'] ?? widget.artisanData['id'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('$name - Anket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profil kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                // Profil şəkli
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                  backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                      ? MemoryImage(base64Decode(photoBase64))
                      : null,
                  child: (photoBase64 == null || photoBase64.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF1769D2), size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$category Ustası',
                    style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 4),
                    Text('5.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(width: 4),
                    Text('(Yoxlanılmış Usta)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 20),

                // Əlaqə düymələri (Zəng və WhatsApp)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty ? () => _makeCall(phone) : null,
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Zəng Et', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty ? () => _openWhatsApp(phone, name) : null,
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Xidmət və Təcrübə haqqında
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF1769D2), size: 20),
                    SizedBox(width: 8),
                    Text('Usta Haqqında', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.artisanData['bio'] ??
                      'Hörmətli müştərilər, $category sahəsində çoxillik təcrübəyə malik peşəkar usta olaraq yüksək keyfiyyətli xidmət təklif edirəm. Bütün işlər zəmanətlə və vaxtında təhvil verilir.',
                  style: const TextStyle(color: Color(0xFF334155), height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (phone.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone_iphone, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Əlaqə nömrəsi: $phone', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Ustanın Gördüyü İşlər və Portfeli (Firestore-dan bu ustanın paylaşımları)
          if (userId != null) ...[
            Row(
              children: const [
                Icon(Icons.photo_library_rounded, color: Color(0xFF1769D2), size: 20),
                SizedBox(width: 8),
                Text('Ustanın Gördüyü İşlər & Portfeli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: userId.toString())
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'Usta hələ ki əlavə iş şəkli yükləməyib.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final post = docs[index].data();
                    final img = post['imageBase64'] as String?;
                    final isVid = post['isVideo'] == true;
                    final title = post['title'] ?? 'Görülən iş';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: (img != null && img.isNotEmpty)
                                  ? Image.memory(base64Decode(img), width: double.infinity, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.black87,
                                      child: Center(
                                        child: Icon(
                                          isVid ? Icons.play_circle_fill : Icons.image,
                                          color: isVid ? Colors.red : Colors.white70,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
