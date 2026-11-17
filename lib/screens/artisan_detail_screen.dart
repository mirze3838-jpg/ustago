import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/category_city_service.dart';
import 'shorts_screen.dart';
import 'market_detail_screens.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> artisanData;

  const ArtisanDetailScreen({super.key, required this.artisanData});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  bool _isBioExpanded = false;
  int _selectedTabIndex = 0; // 0 = Vahid Qalereya (Grid), 1 = Rəylər

  static Uint8List? _decodeB64(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    try {
      String clean = b64.trim();
      if (clean.contains(',')) clean = clean.split(',').last;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  String _cleanTikTokHandle(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll('https://www.tiktok.com/', '').replaceAll('https://tiktok.com/', '').replaceAll('http://tiktok.com/', '');
    if (s.contains('?')) s = s.split('?').first;
    if (s.contains('/')) s = s.split('/').first;
    s = s.replaceAll('@', '').trim();
    return s;
  }

  String _cleanInstagramHandle(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll('https://www.instagram.com/', '').replaceAll('https://instagram.com/', '').replaceAll('http://instagram.com/', '');
    if (s.contains('?')) s = s.split('?').first;
    if (s.contains('/')) s = s.split('/').first;
    s = s.replaceAll('@', '').trim();
    return s;
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Əlaqə nömrəsi qeyd olunmayıb')),
        );
      }
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp nömrəsi qeyd olunmayıb')),
        );
      }
      return;
    }
    if (clean.startsWith('0')) clean = '994${clean.substring(1)}';
    final Uri uri = Uri.parse('https://wa.me/$clean?text=Salam%20$name,%20UstaGo-dan%20əlaqə%20saxlayıram.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openExternalLink(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAddReviewDialog(String artisanUid, String artisanName) async {
    int rating = 5;
    final commentController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    String resolvedName = 'Müştəri';
    String resolvedPhotoBase64 = '';
    if (currentUser != null) {
      resolvedName = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Müştəri';
      try {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final uData = uDoc.data();
        if (uData != null) {
          final fn = (uData['fullName'] ?? uData['name'] ?? '').toString().trim();
          if (fn.isNotEmpty) resolvedName = fn;
          resolvedPhotoBase64 = (uData['photoBase64'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.rate_review_rounded, color: Color(0xFF1769D2), size: 24),
              SizedBox(width: 8),
              Text('Rəy və Qiymətləndirmə', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$artisanName tərəfindən görülən işi qiymətləndirin:',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Rəyiniz',
                    hintText: 'İşin keyfiyyəti və davranış haqqında yazın...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ləğv et', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final comment = commentController.text.trim();
                final reviewerName = resolvedName.trim().isEmpty ? 'Müştəri' : resolvedName.trim();

                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zəhmət olmasa rəy mətnini daxil edin')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                try {
                  final reviewsRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(artisanUid)
                      .collection('reviews');

                  await reviewsRef.add({
                    'rating': rating,
                    'comment': comment,
                    'reviewerName': reviewerName,
                    'reviewerPhotoBase64': resolvedPhotoBase64,
                    'reviewerId': currentUser?.uid ?? 'anonymous',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  final allReviews = await reviewsRef.get();
                  double sum = 0;
                  for (var doc in allReviews.docs) {
                    sum += (doc.data()['rating'] as num?)?.toDouble() ?? 5.0;
                  }
                  final double avg = allReviews.docs.isEmpty ? 5.0 : sum / allReviews.docs.length;
                  final int count = allReviews.docs.length;

                  await FirebaseFirestore.instance.collection('users').doc(artisanUid).set({
                    'rating': double.parse(avg.toStringAsFixed(1)),
                    'reviewCount': count,
                  }, SetOptions(merge: true));

                  if (mounted) {
                    setState(() => _selectedTabIndex = 1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rəyiniz uğurla əlavə edildi! Təşəkkür edirik.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Göndər'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imgBase64, String title) {
    final bytes = _decodeB64(imgBase64);
    if (bytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 32,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 4),
            Text(
              count,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCircle({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: bgColor,
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildServiceChips(String category, Map<String, dynamic> data) {
    List<String> rawSkills = [];
    if (data['specialties'] is List && (data['specialties'] as List).isNotEmpty) {
      rawSkills = (data['specialties'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (data['specialtyIds'] is List && (data['specialtyIds'] as List).isNotEmpty) {
      for (final id in (data['specialtyIds'] as List)) {
        final sp = CategoryCityService.findSpecialtyById(id.toString());
        if (sp != null) rawSkills.add(sp['title']!);
      }
    }
    if (rawSkills.isEmpty && category.isNotEmpty) {
      if (category.contains(',')) {
        rawSkills = category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else {
        rawSkills = [category];
      }
    }
    if (rawSkills.isEmpty) {
      rawSkills = ['Tikinti', 'Təmir', 'Rəngləmə', 'Dizayn'];
    }

    IconData getSkillIcon(String title) {
      final t = title.toLowerCase();
      if (t.contains('santexnik') || t.contains('boru')) return Icons.plumbing_rounded;
      if (t.contains('elektrik') || t.contains('işıq')) return Icons.bolt_rounded;
      if (t.contains('kafel') || t.contains('metlax')) return Icons.grid_view_rounded;
      if (t.contains('malyar') || t.contains('rəng')) return Icons.format_paint_rounded;
      if (t.contains('alçıpan') || t.contains('alcipan')) return Icons.architecture_rounded;
      if (t.contains('mebel') || t.contains('dülgər')) return Icons.chair_rounded;
      if (t.contains('qapı') || t.contains('pəncərə')) return Icons.door_front_door_rounded;
      if (t.contains('dam') || t.contains('fasad') || t.contains('beton')) return Icons.roofing_rounded;
      if (t.contains('kondisioner') || t.contains('soyuducu')) return Icons.ac_unit_rounded;
      if (t.contains('kombi') || t.contains('istilik')) return Icons.hvac_rounded;
      return Icons.handyman_rounded;
    }

    return rawSkills.take(4).map((s) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(getSkillIcon(s), size: 16, color: const Color(0xFF1769D2)),
            const SizedBox(width: 6),
            Text(
              s,
              style: const TextStyle(color: Color(0xFF1769D2), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showServicesModal(String category, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Göstərilən Xidmətlər', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildServiceChips(category, data),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showContactModal(String phone, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$name ilə Əlaqə', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              phone.isNotEmpty ? phone : 'Nömrə qeyd olunmayıb',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1769D2)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_rounded),
                    label: const Text('Zəng et', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _makeCall(phone);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openWhatsApp(phone, name);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showLocationModal(Map<String, dynamic> data) {
    final city = (data['city'] ?? 'Bakı').toString();
    final district = (data['district'] ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final fullLoc = [city, district, address].where((s) => s.trim().isNotEmpty).join(', ');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFFEF3C7),
              child: Icon(Icons.location_on_rounded, color: Color(0xFFF59E0B), size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Fəaliyyət Ərazisi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              fullLoc.isNotEmpty ? fullLoc : 'Bakı',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showUserStoreModal(String targetUid, String authorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('market_stores').snapshots(),
          builder: (streamCtx, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final userDocs = allDocs.where((d) {
              final data = d.data();
              return data['ownerId'] == targetUid || data['userId'] == targetUid;
            }).toList();

            final storeDocs = userDocs.where((d) => (d.data()['listingType'] ?? 'store') == 'store').toList();
            final productDocs = userDocs.where((d) => d.data()['listingType'] == 'product').toList();

            final hasStore = storeDocs.isNotEmpty;
            final storeData = hasStore ? storeDocs.first.data() : null;
            final storeId = hasStore ? storeDocs.first.id : null;

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$authorName - Mağaza',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: !hasStore
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF94A3B8)),
                                SizedBox(height: 12),
                                Text(
                                  'Mağaza elanı yoxdur',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Bu istifadəçinin hələlik aktiv mağaza elanı yoxdur.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StoreDetailScreen(store: {'id': storeId, ...?storeData}),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.white,
                                      child: (storeData?['logoUrl'] ?? '').toString().startsWith('http')
                                          ? ClipOval(
                                              child: Image.network(storeData!['logoUrl'].toString(), fit: BoxFit.cover, width: 52, height: 52),
                                            )
                                          : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (storeData?['title'] ?? 'Mağaza').toString(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Mağaza səhifəsinə keçid et →',
                                            style: TextStyle(fontSize: 12.5, color: Color(0xFF1769D2), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Məhsullar (${productDocs.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            const SizedBox(height: 8),
                            ...productDocs.map((pDoc) {
                              final p = pDoc.data();
                              final pBytes = _decodeB64(p['imageBase64']?.toString());
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: const Color(0xFFF1F5F9),
                                    child: (p['imageUrl'] ?? '').toString().startsWith('http')
                                        ? Image.network(p['imageUrl'].toString(), fit: BoxFit.cover)
                                        : (pBytes != null ? Image.memory(pBytes, fit: BoxFit.cover) : const Icon(Icons.inventory_2_outlined)),
                                  ),
                                ),
                                title: Text((p['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text((p['price'] ?? '').toString(), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(product: {'id': pDoc.id, ...p}),
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showUserListingsModal(String targetUid, String authorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('market_stores').snapshots(),
          builder: (streamCtx, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final listings = allDocs.where((d) {
              final data = d.data();
              final isOwnerMatch = data['ownerId'] == targetUid || data['userId'] == targetUid;
              return isOwnerMatch && data['listingType'] == 'product';
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFFEA580C)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$authorName - Elanlar (${listings.length})',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: listings.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.campaign_outlined, size: 48, color: Color(0xFF94A3B8)),
                                SizedBox(height: 12),
                                Text('Elan yoxdur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text(
                                  'Bu istifadəçinin hələlik aktiv alış-satış elanı yoxdur.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: listings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final doc = listings[idx];
                            final data = doc.data();
                            final pBytes = _decodeB64(data['imageBase64']?.toString());
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  this.context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(product: {'id': doc.id, ...data}),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        color: const Color(0xFFF1F5F9),
                                        child: (data['imageUrl'] ?? '').toString().startsWith('http')
                                            ? Image.network(data['imageUrl'].toString(), fit: BoxFit.cover)
                                            : (pBytes != null ? Image.memory(pBytes, fit: BoxFit.cover) : const Icon(Icons.shopping_bag_outlined)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text((data['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text((data['price'] ?? '').toString(), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnifiedMediaGrid(String uId, String displayName) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uId).snapshots(),
      builder: (context, postSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('shorts').where('userId', isEqualTo: uId).snapshots(),
          builder: (context, shortSnap) {
            final List<Map<String, dynamic>> items = [];

            for (final d in (postSnap.data?.docs ?? [])) {
              final data = d.data();
              final bool isVid = data['isVideo'] == true || (data['videoUrl'] ?? '').toString().trim().isNotEmpty;
              items.add({'id': d.id, 'source': isVid ? 'short' : 'post', ...data});
            }

            for (final d in (shortSnap.data?.docs ?? [])) {
              items.add({'id': d.id, 'source': 'short', ...d.data()});
            }

            items.sort((a, b) {
              final ta = a['createdAt'];
              final tb = b['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });

            if (items.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.photo_library_outlined, size: 42, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'Hələlik iş və ya video paylaşılmayıb',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isVideo = item['source'] == 'short';
                final String? imgB64 = (item['imageBase64'] ?? item['thumbnailBase64'])?.toString();
                final Uint8List? imgBytes = _decodeB64(imgB64);

                return InkWell(
                  onTap: () {
                    if (isVideo) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShortsScreen(targetUserId: uId),
                        ),
                      );
                    } else if (imgB64 != null && imgB64.isNotEmpty) {
                      _showFullScreenImage(context, imgB64, (item['description'] ?? item['title'] ?? '').toString());
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgBytes != null)
                        Image.memory(imgBytes, fit: BoxFit.cover)
                      else if (isVideo)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF1769D2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                        ),
                      if (isVideo)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsTab(String userId, String displayName, String ratingStr) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ratingStr,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text('${docs.length} müştəri rəyi', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('Rəy yaz', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddReviewDialog(userId, displayName),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Hələlik rəy yazılmayıb. İlk rəyi siz yazın!', style: TextStyle(color: Color(0xFF64748B))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final r = docs[idx].data();
                    final revName = (r['reviewerName'] ?? 'Müştəri').toString();
                    final revComment = (r['comment'] ?? '').toString();
                    final revRating = (r['rating'] as num?)?.toInt() ?? 5;
                    final revId = (r['reviewerId'] ?? '').toString();
                    final revPhotoB64 = (r['reviewerPhotoBase64'] ?? '').toString();
                    final directBytes = _decodeB64(revPhotoB64);

                    Widget buildAvatar(Uint8List? bytes) {
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFEFF6FF),
                        backgroundImage: bytes != null ? MemoryImage(bytes) : null,
                        child: bytes == null
                            ? Text(
                                revName.isNotEmpty ? revName[0].toUpperCase() : 'M',
                                style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 13),
                              )
                            : null,
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (directBytes != null)
                                      buildAvatar(directBytes)
                                    else if (revId.isNotEmpty && revId != 'anonymous')
                                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                        future: FirebaseFirestore.instance.collection('users').doc(revId).get(),
                                        builder: (ctx, uSnap) {
                                          final fetchedBytes = _decodeB64(uSnap.data?.data()?['photoBase64']?.toString());
                                          return buildAvatar(fetchedBytes);
                                        },
                                      )
                                    else
                                      buildAvatar(null),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        revName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < revRating ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(revComment, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35)),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = (widget.artisanData['uid'] ?? widget.artisanData['userId'] ?? widget.artisanData['id'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userId.isNotEmpty
            ? FirebaseFirestore.instance.collection('users').doc(userId).snapshots()
            : const Stream.empty(),
        builder: (context, userSnap) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(widget.artisanData);
          if (userSnap.hasData && userSnap.data!.data() != null) {
            data.addAll(userSnap.data!.data()!);
          }

          final String displayName = (data['fullName'] ?? data['name'] ?? 'Usta').toString();
          final String phone = (data['phone'] ?? '').toString().trim();
          final String category = (data['category'] ?? data['trade'] ?? '').toString();
          final String rating = (data['rating'] != null) ? data['rating'].toString() : '5.0';
          final String userRole = (data['role'] ?? 'usta').toString().toLowerCase().trim();
          final bool isWorking = data['isWorking'] == true;

          String defaultRoleTitle = 'Tikinti və Təmir Ustası';
          if (userRole == 'fehle' || userRole == 'fəhlə' || userRole == 'worker') {
            defaultRoleTitle = 'Fəhlə (Köməkçi işlər)';
          } else if (userRole == 'satici' || userRole == 'satıcı' || userRole == 'seller') {
            defaultRoleTitle = 'Tikinti Malları Satıcısı';
          } else if (userRole == 'musteri' || userRole == 'müştəri' || userRole == 'customer') {
            defaultRoleTitle = 'Müştəri';
          }

          List<String> userSpecialties = [];
          if (data['specialties'] is List && (data['specialties'] as List).isNotEmpty) {
            userSpecialties = (data['specialties'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          } else if (data['specialtyIds'] is List && (data['specialtyIds'] as List).isNotEmpty) {
            for (final id in (data['specialtyIds'] as List)) {
              final sp = CategoryCityService.findSpecialtyById(id.toString());
              if (sp != null) userSpecialties.add(sp['title']!);
            }
          }
          if (userSpecialties.isEmpty && category.isNotEmpty && category != 'null' && category != 'Tikinti və Təmir') {
            if (category.contains(',')) {
              userSpecialties = category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            } else {
              userSpecialties = [category];
            }
          }

          final String displaySpecialtiesText = userSpecialties.isNotEmpty
              ? userSpecialties.take(4).join(', ')
              : (category.isNotEmpty && category != 'null' ? category : defaultRoleTitle);

          String defaultBio = 'Keyfiyyətli və peşəkar təmir xidməti. Təcrübə: 10+ il. Hər növ tikinti və təmir işləri.';
          if (userRole == 'fehle' || userRole == 'fəhlə' || userRole == 'worker') {
            defaultBio = 'Fiziki və köməkçi tikinti işləri, söküntü, daşıma və sahə təmizliyi xidmətləri.';
          } else if (userRole == 'satici' || userRole == 'satıcı' || userRole == 'seller') {
            defaultBio = 'Tikinti materialları, təmir alətləri və avadanlıqların sərfəli satışı.';
          } else if (userRole == 'musteri' || userRole == 'müştəri' || userRole == 'customer') {
            defaultBio = 'UstaGo istifadəçisi. Tikinti və təmir sifarişləri.';
          }

          final String bio = (data['bio'] != null && data['bio'].toString().trim().isNotEmpty)
              ? data['bio'].toString()
              : defaultBio;

          final String cleanTikTok = _cleanTikTokHandle((data['tiktokHandle'] ?? '').toString());
          final String cleanInstagram = _cleanInstagramHandle((data['instagramHandle'] ?? '').toString());
          final String websiteUrl = (data['websiteUrl'] ?? data['website'] ?? '').toString().trim();

          final Uint8List? avatarBytes = _decodeB64(data['photoBase64']?.toString());
          final ImageProvider? avatarImage = avatarBytes != null ? MemoryImage(avatarBytes) : null;

          final List<Map<String, dynamic>> activeLinks = [];
          if (cleanTikTok.isNotEmpty) {
            activeLinks.add({
              'label': 'tiktok.com/@$cleanTikTok',
              'icon': Icons.music_note_rounded,
              'color': const Color(0xFFFE2C55),
              'onTap': () => _openExternalLink('https://www.tiktok.com/@$cleanTikTok'),
            });
          }
          if (cleanInstagram.isNotEmpty) {
            activeLinks.add({
              'label': 'instagram.com/$cleanInstagram',
              'icon': Icons.camera_alt_rounded,
              'color': const Color(0xFFE1306C),
              'onTap': () => _openExternalLink('https://www.instagram.com/$cleanInstagram'),
            });
          }
          if (websiteUrl.isNotEmpty) {
            activeLinks.add({
              'label': websiteUrl.replaceAll('https://', '').replaceAll('http://', ''),
              'icon': Icons.language_rounded,
              'color': const Color(0xFF1769D2),
              'onTap': () => _openExternalLink(websiteUrl),
            });
          }

          return Column(
            children: [
              // 1. Instagram Stilində Yuxarı Başlıq
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWorking ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isWorking ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isWorking ? 'Məşğuldur' : 'Sərbəstdir',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
              ),

              // 2. Əsas Profil Məzmunu
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),

                    // Avatar + 3 Statistika Sütunu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3.0),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF00D2FF), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFFEFF6FF),
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? const Icon(Icons.person, size: 42, color: Color(0xFF1769D2))
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: userId).snapshots(),
                              builder: (context, postSnap) {
                                final postCount = postSnap.data?.docs.length ?? 0;
                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance.collection('shorts').where('userId', isEqualTo: userId).snapshots(),
                                  builder: (context, shortSnap) {
                                    final shortCount = shortSnap.data?.docs.length ?? 0;
                                    final totalCount = postCount + shortCount;
                                    final cleanRating = rating.replaceAll('★', '').trim();
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(count: '$totalCount', label: 'göndəri', icon: Icons.grid_on_rounded, iconColor: const Color(0xFF1769D2)),
                                        _buildStatItem(count: '$shortCount', label: 'video', icon: Icons.play_circle_outline_rounded, iconColor: const Color(0xFFFE2C55)),
                                        InkWell(
                                          onTap: () => setState(() => _selectedTabIndex = 1),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: _buildStatItem(count: cleanRating, label: 'reytinq', icon: Icons.star_rounded, iconColor: const Color(0xFFF59E0B)),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ad, İxtisaslar, Bio və Sosial Linklər
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF1769D2), size: 16),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displaySpecialtiesText,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bio,
                            maxLines: _isBioExpanded ? null : 3,
                            overflow: _isBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                          ),
                          InkWell(
                            onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _isBioExpanded ? 'Daha az' : 'Daha çox',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (activeLinks.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            for (final lk in activeLinks)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: InkWell(
                                  onTap: lk['onTap'] as VoidCallback,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(lk['icon'] as IconData, size: 14, color: lk['color'] as Color),
                                      const SizedBox(width: 4),
                                      Text(
                                        lk['label'] as String,
                                        style: TextStyle(color: lk['color'] as Color, fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_outward_rounded, size: 11, color: Color(0xFF94A3B8)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    // Ziyarətçi Əlaqə Düymələri (Zəng et, WhatsApp, Rəy yaz)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1769D2),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 16),
                              label: const Text('Zəng et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () => _makeCall(phone),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                              label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () => _openWhatsApp(phone, displayName),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.star_rounded, size: 16),
                            label: const Text('Rəy yaz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => _showAddReviewDialog(userId, displayName),
                          ),
                        ],
                      ),
                    ),

                    // 6 Dairəvi Hekayə / Önə Çıxarılanlar (UstaGo Highlights)
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildHighlightCircle(
                            icon: Icons.music_note_rounded,
                            iconColor: const Color(0xFFFE2C55),
                            bgColor: Colors.black,
                            borderColor: const Color(0xFFFE2C55),
                            label: 'Rəsmi TikTok',
                            onTap: () {
                              if (cleanTikTok.isNotEmpty) {
                                _openExternalLink('https://www.tiktok.com/@$cleanTikTok');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('İstifadəçi TikTok profilini əlavə etməyib')),
                                );
                              }
                            },
                          ),
                          _buildHighlightCircle(
                            icon: Icons.handyman_rounded,
                            iconColor: const Color(0xFF1769D2),
                            bgColor: const Color(0xFFEFF6FF),
                            borderColor: const Color(0xFF1769D2),
                            label: 'Xidmətlər',
                            onTap: () => _showServicesModal(category, data),
                          ),
                          _buildHighlightCircle(
                            icon: Icons.phone_in_talk_rounded,
                            iconColor: const Color(0xFF10B981),
                            bgColor: const Color(0xFFECFDF5),
                            borderColor: const Color(0xFF10B981),
                            label: 'Əlaqə',
                            onTap: () => _showContactModal(phone, displayName),
                          ),
                          _buildHighlightCircle(
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            bgColor: const Color(0xFFFEF3C7),
                            borderColor: const Color(0xFFF59E0B),
                            label: 'Məkan',
                            onTap: () => _showLocationModal(data),
                          ),
                          _buildHighlightCircle(
                            icon: Icons.storefront_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            bgColor: const Color(0xFFF5F3FF),
                            borderColor: const Color(0xFF8B5CF6),
                            label: 'Mağaza',
                            onTap: () => _showUserStoreModal(userId, displayName),
                          ),
                          _buildHighlightCircle(
                            icon: Icons.campaign_rounded,
                            iconColor: const Color(0xFFEA580C),
                            bgColor: const Color(0xFFFFF7ED),
                            borderColor: const Color(0xFFEA580C),
                            label: 'Elanlar',
                            onTap: () => _showUserListingsModal(userId, displayName),
                          ),
                        ],
                      ),
                    ),

                    // Tab Bar (İşlər vs Rəylər - Aydın yazı və say ilə)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: userId.isNotEmpty
                          ? FirebaseFirestore.instance.collection('users').doc(userId).collection('reviews').snapshots()
                          : const Stream.empty(),
                      builder: (context, revCountSnap) {
                        final int revCount = revCountSnap.data?.docs.length ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTabIndex = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.grid_on_rounded,
                                          color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'İşlər',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTabIndex = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _selectedTabIndex == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: _selectedTabIndex == 1 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Rəylər ($revCount)',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabIndex == 1 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    if (_selectedTabIndex == 0)
                      _buildUnifiedMediaGrid(userId, displayName)
                    else
                      _buildReviewsTab(userId, displayName, rating.replaceAll('★', '').trim()),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
