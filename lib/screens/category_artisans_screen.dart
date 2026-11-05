import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class CategoryArtisansScreen extends StatefulWidget {
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;
  final Color categoryBgColor;

  const CategoryArtisansScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryIcon,
    required this.categoryColor,
    required this.categoryBgColor,
  });

  @override
  State<CategoryArtisansScreen> createState() => _CategoryArtisansScreenState();
}

class _CategoryArtisansScreenState extends State<CategoryArtisansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _cleanTitle => widget.categoryTitle.replaceAll('\n', ' ');

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=Salam%20$name,%20UstaGo-dan%20əlaqə%20saxlayıram.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '$_cleanTitle Ustaları',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1769D2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1769D2),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.engineering_rounded), text: 'Ustalar'),
            Tab(icon: Icon(Icons.photo_library_rounded), text: 'Görülən İşlər & Shorts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1-ci Tab: Qeydiyyatlı Ustalar
          _buildArtisansList(),

          // 2-ci Tab: Görülən İşlər və Videolar
          _buildPostsList(),
        ],
      ),
    );
  }

  // 1. USTALAR SİYAHISI
  Widget _buildArtisansList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'usta')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Həmin kateqoriyaya uyğun ustaları filtrləyirik (böyük/kiçik hərf və s. uyğunluğu)
        final matchingArtisans = allDocs.where((doc) {
          final data = doc.data();
          final ustaCat = (data['category'] ?? data['trade'] ?? '').toString().trim().toLowerCase();
          final targetCat = _cleanTitle.trim().toLowerCase();
          return ustaCat.contains(targetCat) || targetCat.contains(ustaCat) || ustaCat == 'hər sahə' || ustaCat.isEmpty;
        }).toList();

        if (matchingArtisans.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.categoryBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.categoryIcon, size: 54, color: widget.categoryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hələlik $_cleanTitle kateqoriyasında usta yoxdur',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Əgər bu sahə üzrə ustasınızsa, profilinizdən ixtisasınızı seçərək ilk siz qeydiyyatdan keçin!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matchingArtisans.length,
          itemBuilder: (context, index) {
            final data = matchingArtisans[index].data();
            final name = data['fullName'] ?? 'Usta';
            final phone = data['phone'] ?? '';
            final photoBase64 = data['photoBase64'] as String?;
            final ustaCat = data['category'] ?? _cleanTitle;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  // Profil fotosu
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: widget.categoryBgColor,
                    backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                        ? MemoryImage(base64Decode(photoBase64))
                        : null,
                    child: (photoBase64 == null || photoBase64.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: TextStyle(color: widget.categoryColor, fontWeight: FontWeight.bold, fontSize: 20),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // Məlumatlar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.categoryBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$ustaCat Ustası',
                            style: TextStyle(color: widget.categoryColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Əlaqə Düymələri (WhatsApp və Zəng)
                  if (phone.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 24),
                      tooltip: 'WhatsApp',
                      onPressed: () => _openWhatsApp(phone, name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1769D2), size: 24),
                      tooltip: 'Zəng Et',
                      onPressed: () => _makeCall(phone),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. GÖRÜLƏN İŞLƏR VƏ SHORTS VİDEOLARI
  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('category', isEqualTo: _cleanTitle)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library_outlined, size: 50, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    '$_cleanTitle kateqoriyasında hələ heç bir iş paylaşılmayıb',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ustalar gördükləri işləri və Shorts videolarını paylaşdıqda burada görünəcək!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final post = docs[index].data();
            final isVideo = post['isVideo'] == true;
            final title = post['title'] ?? 'Usta İşi';
            final authorName = post['authorName'] ?? 'Usta';
            final videoUrl = post['videoUrl'] as String?;
            final imageBase64 = post['imageBase64'] as String?;

            return InkWell(
              onTap: () {
                _showPostDetail(context, post);
              },
              child: Container(
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (!isVideo && imageBase64 != null && imageBase64.isNotEmpty)
                              Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                            else
                              Container(
                                color: Colors.black87,
                                child: Center(
                                  child: Icon(
                                    isVideo ? Icons.play_circle_fill : Icons.image,
                                    color: isVideo ? Colors.red : Colors.white70,
                                    size: 40,
                                  ),
                                ),
                              ),
                            if (isVideo)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Shorts', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authorName,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostDetail(BuildContext context, Map<String, dynamic> post) {
    final title = post['title'] ?? 'Usta İşi';
    final authorName = post['authorName'] ?? 'Usta';
    final isVideo = post['isVideo'] == true;
    final imageBase64 = post['imageBase64'] as String?;
    final videoUrl = post['videoUrl'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text('Usta: $authorName', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            if (!isVideo && imageBase64 != null && imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(base64Decode(imageBase64), width: double.infinity, height: 260, fit: BoxFit.cover),
              )
            else if (isVideo && videoUrl != null && videoUrl.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    const Icon(Icons.video_library, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Shorts Videosu', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Shorts Bölməsində İzlə', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
