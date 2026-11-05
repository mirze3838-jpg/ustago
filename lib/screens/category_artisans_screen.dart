import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'artisan_detail_screen.dart';

class CategoryArtisansScreen extends StatelessWidget {
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

  String get _cleanTitle => categoryTitle.replaceAll('\n', ' ').trim();

  // Kateqoriyanın dəqiq uyğunluğunu yoxlayır
  bool _isMatchingCategory(String? ustaCategory) {
    final t = _cleanTitle.toLowerCase();
    if (ustaCategory == null || ustaCategory.trim().isEmpty) {
      // Kateqoriyası hələ seçilməmiş ustalar default olaraq Tikinti bölməsində göstərilir
      return t.contains('tikinti');
    }

    final u = ustaCategory.trim().toLowerCase().replaceAll('\n', ' ');

    // Dəqiq eynilik və ya bir-birini ehtiva etməsi
    if (u == t || u.contains(t) || t.contains(u)) return true;

    // Açar sözlərlə dəqiq uyğunluq
    const categoryKeywords = {
      'tikinti': ['tikinti', 'hörgü', 'suvaq', 'bünövrə', 'dam'],
      'santexnik': ['santexnik', 'boru', 'kran', 'su təchizatı'],
      'elektrik': ['elektrik', 'şit', 'naqil', 'işıqlandırma'],
      'təmir': ['təmir', 'quraşdırma', 'usta'],
      'avtomobil': ['avtomobil', 'avto', 'motor', 'dəmirçi'],
      'mebel': ['mebel', 'quraşdırılması', 'yığılması'],
      'kondisioner': ['kondisioner', 'soyuducu', 'freon', 'kombi'],
      'dülgər': ['dülgər', 'dulger', 'qapı', 'taxta'],
      'rəngsaz': ['rəngsaz', 'rengsaz', 'malyar', 'oboy', 'boya'],
    };

    for (var entry in categoryKeywords.entries) {
      if (t.contains(entry.key)) {
        return entry.value.any((kw) => u.contains(kw));
      }
    }

    return false;
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '994${cleanPhone.substring(1)}';
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
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'usta')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          // YALNIZ və YALNIZ bu kateqoriyaya aid olan ustalar
          final matchingArtisans = allDocs.where((doc) {
            final data = doc.data();
            final cat = (data['category'] ?? data['trade'] ?? '').toString();
            return _isMatchingCategory(cat);
          }).toList();

          if (matchingArtisans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: categoryBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(categoryIcon, size: 54, color: categoryColor),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Hələlik $_cleanTitle kateqoriyasında usta yoxdur',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bu sahə üzrə ustasınızsa, qeydiyyatdan keçərkən bu kateqoriyanı seçərək ilk siz burada görünün!',
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
              final doc = matchingArtisans[index];
              final data = doc.data();
              final uid = doc.id;
              final name = data['fullName'] ?? 'Usta';
              final phone = data['phone'] ?? '';
              final photoBase64 = data['photoBase64'] as String?;
              final ustaCat = data['category'] ?? _cleanTitle;

              final Map<String, dynamic> artisanFullData = {
                ...data,
                'uid': uid,
                'id': uid,
                'fullName': name,
                'category': ustaCat,
                'phone': phone,
                'photoBase64': photoBase64,
              };

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Ustanın anketinə / səhifəsinə baxış
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtisanDetailScreen(artisanData: artisanFullData),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Profil fotosu
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: categoryBgColor,
                        backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                            ? MemoryImage(base64Decode(photoBase64))
                            : null,
                        child: (photoBase64 == null || photoBase64.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(color: categoryColor, fontWeight: FontWeight.bold, fontSize: 22),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // Usta Məlumatları
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Color(0xFF1769D2), size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$ustaCat Ustası',
                                style: TextStyle(color: categoryColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: const [
                                Text(
                                  'Anketə baxın',
                                  style: TextStyle(color: Color(0xFF1769D2), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1769D2), size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Əlaqə Düymələri (WhatsApp və Zəng)
                      if (phone.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 26),
                          tooltip: 'WhatsApp',
                          onPressed: () => _openWhatsApp(phone, name),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF1769D2), size: 26),
                          tooltip: 'Zəng Et',
                          onPressed: () => _makeCall(phone),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
