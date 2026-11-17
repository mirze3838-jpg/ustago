import 'payment_screens.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/category_city_service.dart';

/// Baza64 şəkil çevirici köməkçi funksiya
Uint8List? decodeBase64Safe(String? b64) {
  if (b64 == null || b64.trim().isEmpty) return null;
  try {
    String clean = b64.trim();
    if (clean.contains(',')) clean = clean.split(',').last;
    return base64Decode(clean);
  } catch (_) {
    return null;
  }
}

/// Zəng açmaq köməkçi funksiyası
Future<void> makePhoneCall(String phone) async {
  final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (clean.isEmpty) return;
  final uri = Uri.parse('tel:$clean');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// WhatsApp açmaq köməkçi funksiyası
Future<void> openWhatsApp(String phone, {String? text}) async {
  String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.startsWith('0')) clean = '994${clean.substring(1)}';
  if (!clean.startsWith('994') && clean.length == 9) clean = '994$clean';
  final message = Uri.encodeComponent(text ?? 'Salam, UstaGo-dakı elanınızla bağlı yazıram.');
  final uri = Uri.parse('https://wa.me/$clean?text=$message');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    makePhoneCall(phone);
  }
}

// =============================================================================
// 1. TƏK ELAN DETAL SƏHİFƏSİ (ProductDetailScreen)
// İstifadəçi nümunə şəkilləri: media_1794900771645_eb8f1059.jpg
// =============================================================================
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onBack;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.onBack,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Map<String, dynamic> _prod;
  bool _isFavorite = false;
  int _viewsCount = 0;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _prod = Map<String, dynamic>.from(widget.product);
    _viewsCount = (_prod['views'] is int)
        ? _prod['views'] as int
        : int.tryParse(_prod['views']?.toString() ?? '') ?? 42;

    _incrementViewCount();
  }

  void _incrementViewCount() {
    final docId = _prod['id']?.toString();
    if (docId != null && docId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('market_stores')
          .doc(docId)
          .update({'views': FieldValue.increment(1)})
          .catchError((_) {});
      setState(() => _viewsCount++);
    }
  }

  void _showVipSheet() {
    final bool alreadyVip = _prod['isVip'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                alreadyVip ? 'Bu Elan Artıq VIP-dir' : 'Elanı VIP Et (İndi Pulsuz)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                alreadyVip
                    ? 'Elanınız hazırda VIP statusundadır və Alış-Satış bölməsinin ən üstündə nümayiş olunur.'
                    : 'Aksiya çərçivəsində elanınızı 30 günlük tamamilə pulsuz VIP vitrininə qaldırın!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 18),
              _buildBenefitRow(Icons.star_rounded, const Color(0xFFF59E0B), 'Xüsusi VIP Vitrini', 'Alış-satış bölməsinin ən üstündəki VIP lentində daimi nümayiş olunur.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.brush_rounded, const Color(0xFFEA580C), 'Qızılı Fərqləndirici Haşiyə', 'Axtarışda və kateqoriyalarda digər elanlardan seçilən parlaq dizayn.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.bolt_rounded, const Color(0xFF10B981), 'İndi Pulsuz Aktivləşdirmə', 'Heç bir ödəniş tələb olunmur, bir toxunuşla dərhal aktivləşir.'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: Icon(alreadyVip ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 20),
                  label: Text(
                    alreadyVip ? 'VIP Müddətini Yenilə (30 gün)' : 'İndi Pulsuz VIP Et',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final docId = _prod['id']?.toString();
                    if (docId != null && docId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                        'isVip': true,
                        'vipUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                      }).catchError((_) {});
                    }
                    setState(() {
                      _prod['isVip'] = true;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                        const SnackBar(duration: Duration(milliseconds: 1300), 
                          content: Text('Təbriklər! Elanınız pulsuz 30 günlük VIP statusu qazandı! 👑'),
                          backgroundColor: Color(0xFFD97706),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBumpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Elanı İrəli Çək (İndi Pulsuz)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elanınızın dərc olunma tarixini yeniləyərək bütün siyahının ən önünə keçirin!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildBenefitRow(Icons.arrow_upward_rounded, const Color(0xFF10B981), '1-ci Sıraya Qalxma', 'Elanınız bütün alıcılar üçün ən üstdə və yeni kimi görünür.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.schedule_rounded, const Color(0xFF1769D2), 'Tarix Yenilənməsi', 'Dərc olunma tarixi "İndicə yerləşdirildi" kimi qeyd olunur.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.volunteer_activism_rounded, const Color(0xFF8B5CF6), 'Tamamilə Pulsuz', 'Aksiya müddətində heç bir ödənişsiz dərhal istifadə edin.'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text('İndi İrəli Çək', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final docId = _prod['id']?.toString();
                    if (docId != null && docId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                        'bumpedAt': FieldValue.serverTimestamp(),
                        'createdAt': FieldValue.serverTimestamp(),
                      }).catchError((_) {});
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                        const SnackBar(duration: Duration(milliseconds: 1300), 
                          content: Text('Elanınız uğurla ən ön sıraya qaldırıldı! 🚀'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, Color color, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareProduct() {
    final title = _prod['title']?.toString() ?? 'UstaGo Elanı';
    final price = _prod['price']?.toString() ?? '';
    final city = _prod['city']?.toString() ?? 'Bakı';
    final shareText = '$title - $price ($city)\nUstaGo Alış-Satış platformasında baxın:\nhttps://ustago-app.github.io/ustago/';
    try {
      Share.share(shareText, subject: title);
    } catch (_) {
      Clipboard.setData(ClipboardData(text: shareText));
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Elan linki kopyalandı!')));
    }
  }

  void _navigateToStore() {
    final storeName = (_prod['store'] ?? _prod['storeName'] ?? '').toString();
    final ownerId = (_prod['ownerId'] ?? _prod['userId'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreDetailScreen(
          store: {
            'title': storeName.isNotEmpty ? storeName : 'Satıcı Mağazası',
            'ownerId': ownerId,
            'userId': ownerId,
            'phone': _prod['phone'] ?? '',
            'whatsapp': _prod['whatsapp'] ?? _prod['phone'] ?? '',
            'address': _prod['address'] ?? _prod['city'] ?? 'Bakı',
            'city': _prod['city'] ?? 'Bakı',
            'category': _prod['category'] ?? 'Tikinti Malları',
            'description': 'Bu satıcının və ya mağazanın UstaGo-dakı bütün aktiv elanları.',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? imgBytes = decodeBase64Safe(_prod['imageBase64']?.toString());
    final String title = _prod['title']?.toString() ?? 'Məhsul Elanı';
    final String price = _prod['price']?.toString() ?? '0 AZN';
    final String unit = _prod['unit']?.toString() ?? '1 ədəd';
    final String category = _prod['category']?.toString() ?? 'İnşaat malları';
    final String city = _prod['city']?.toString() ?? 'Bakı';
    final String address = _prod['address']?.toString() ?? '';
    final String description = _prod['description']?.toString() ?? '';
    final String storeName = (_prod['store'] ?? _prod['storeName'] ?? '').toString();
    final String phone = _prod['phone']?.toString() ?? '';
    final String whatsapp = (_prod['whatsapp']?.toString().isNotEmpty == true) ? _prod['whatsapp'].toString() : phone;
    final bool isVip = _prod['isVip'] == true;

    // Elan nömrəsi (7 rəqəmli fərdi nömrə)
    final String docId = _prod['id']?.toString() ?? _prod['sampleId']?.toString() ?? title;
    final String adNumber = '${docId.hashCode.abs() % 9000000 + 1000000}';

    // Tarix
    String formattedDate = '17.11.2026';
    int daysLeft = 30;
    bool isExpired = false;
    if (_prod['createdAt'] is Timestamp) {
      final dt = (_prod['createdAt'] as Timestamp).toDate();
      final passed = DateTime.now().difference(dt).inDays;
      daysLeft = (30 - passed).clamp(0, 30);
      isExpired = passed >= 30;
    }
    if (_prod['createdAt'] is Timestamp) {
      final dt = (_prod['createdAt'] as Timestamp).toDate();
      formattedDate = '${dt.day}.${dt.month}.${dt.year}';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 1. Şəkil / Karusel Banner Başlığı
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.92),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.92),
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isFavorite = !_isFavorite),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.92),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A), size: 20),
                    onPressed: _shareProduct,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if ((_prod['imageUrl'] ?? '').toString().startsWith('http'))
                    Image.network(
                      _prod['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => imgBytes != null
                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                          : const SizedBox.shrink(),
                    )
                  else if (imgBytes != null)
                    Image.memory(imgBytes, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF1769D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 68, color: Colors.white70),
                            const SizedBox(height: 8),
                            Text(category, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  // Şəkil sayı və VIP indikatoru
                  Positioned(
                    bottom: 12,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('1/1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  if (isVip)
                    Positioned(
                      bottom: 12,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFD97706)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('VIP ELAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Məzmun Bloku
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Müddəti bitmiş elan xəbərdarlığı
                  if (isExpired)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Bu elanın 30 günlük nümayiş müddəti bitib. Elanı yeniləyərək yenidən aktiv edin.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final docId = _prod['id']?.toString();
                              if (docId != null && docId.isNotEmpty) {
                                await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'bumpedAt': FieldValue.serverTimestamp(),
                                });
                                setState(() {
                                  _prod['createdAt'] = Timestamp.now();
                                });
                                ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                  const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Elanın müddəti 30 gün uzadıldı və ən ön sıraya keçirildi! 🚀')),
                                );
                              }
                            },
                            child: const Text('30 gün uzat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Qiymət
                  Text(
                    price.contains('AZN') ? price : '$price AZN',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Başlıq
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Xüsusiyyətlər
                  _buildAttributeRow('Kateqoriya:', category),
                  const SizedBox(height: 8),
                  _buildAttributeRow('Alt kateqoriya / Vahid:', unit),
                  const SizedBox(height: 8),
                  _buildAttributeRow('Şəhər:', city),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAttributeRow('Dəqiq Ünvan:', address),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Təsvir
                  if (description.isNotEmpty) ...[
                    Text(
                      _isDescriptionExpanded || description.length <= 150
                          ? description
                          : '${description.substring(0, 150)}...',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                    ),
                    if (description.length > 150) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Text(
                          _isDescriptionExpanded ? 'Bağla' : 'Davamını oxu',
                          style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                  ],

                  // Satıcı / Mağaza Kartı (Nümunə Şəkil 4-ə tam uyğun)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _navigateToStore,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storeName.isNotEmpty ? storeName : 'Satıcı Mağazası',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: const [
                                    Text(
                                      'İstifadəçinin bütün elanları',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1769D2),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF1769D2)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Statistika (Baxış sayı, Elan nömrəsi, Tarix)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow('Baxış sayı:', '$_viewsCount'),
                        const SizedBox(height: 6),
                        _buildStatRow('Elan nömrəsi:', adNumber),
                        const SizedBox(height: 6),
                        _buildStatRow('Tarix:', formattedDate),
                        const SizedBox(height: 6),
                        _buildStatRow('Müddət:', isExpired ? 'Müddəti bitib' : '$daysLeft gün qalıb (Maks. 30 gün)'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // VIP və İrəli Çək Düymələri (Nümunə Şəkil 4-ə tam uyğun)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 20),
                          label: const Text(
                            'VIP et',
                            style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _showVipSheet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.trending_up_rounded, color: Color(0xFF059669), size: 20),
                          label: const Text(
                            'İrəli çək',
                            style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: _showBumpSheet,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // Alt düymələr üçün boşluq
                ],
              ),
            ),
          ),
        ],
      ),

      // 3. Alt Sabit Əlaqə Paneli (Zəng et + Mesaj yaz)
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.phone_rounded, size: 20),
                label: const Text('Zəng et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => makePhoneCall(phone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                label: const Text('Mesaj yaz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => openWhatsApp(whatsapp, text: 'Salam, UstaGo-dakı "$title" ($price) elanınızla bağlı yazıram.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1769D2), fontSize: 13.5)),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5)),
      ],
    );
  }
}

// =============================================================================
// 2. MAĞAZA SƏHİFƏSİ VƏ BÜTÜN ELANLAR (StoreDetailScreen)
// İstifadəçi nümunə şəkli: media_1794900328711_d26abe05.jpg ("Global Avto")
// =============================================================================
class StoreDetailScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreDetailScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final Uint8List? logoBytes = decodeBase64Safe(store['logoBase64']?.toString());
    final String title = store['title']?.toString() ?? 'Mağaza';
    final String description = store['description']?.toString() ?? '';
    final String address = store['address']?.toString() ?? store['city']?.toString() ?? 'Bakı';
    final String phone = store['phone']?.toString() ?? '';
    final String whatsapp = (store['whatsapp']?.toString().isNotEmpty == true) ? store['whatsapp'].toString() : phone;
    final String ownerId = (store['ownerId'] ?? store['userId'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ana Səhifə',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Paylaş',
            onPressed: () {
              final text = '$title Mağazası UstaGo-da:\nhttps://ustago-app.github.io/ustago/';
              try {
                Share.share(text, subject: title);
              } catch (_) {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Mağaza linki kopyalandı!')));
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Mağaza Profil Başlığı (Şəkil 1-ə tam uyğun)
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: (store['logoUrl'] ?? '').toString().startsWith('http')
                            ? ClipOval(
                                child: Image.network(
                                  store['logoUrl'].toString(),
                                  fit: BoxFit.cover,
                                  width: 68,
                                  height: 68,
                                  errorBuilder: (_, __, ___) => logoBytes != null
                                      ? Image.memory(logoBytes, fit: BoxFit.cover, width: 68, height: 68)
                                      : const Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 36),
                                ),
                              )
                            : (logoBytes != null
                                ? ClipOval(child: Image.memory(logoBytes, fit: BoxFit.cover, width: 68, height: 68))
                                : const Icon(Icons.storefront_rounded, color: Color(0xFF1769D2), size: 36)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1769D2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                icon: const Icon(Icons.phone_rounded, size: 16),
                                label: const Text('Zəng et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                onPressed: () => makePhoneCall(phone),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _isDescriptionExpanded || description.length <= 120
                          ? description
                          : '${description.substring(0, 120)}...',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
                    ),
                    if (description.length > 120) ...[
                      const SizedBox(height: 3),
                      InkWell(
                        onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Text(
                          _isDescriptionExpanded ? 'Bağla' : 'Davamını oxu',
                          style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ],

                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Başlıq: "İstifadəçinin bütün elanları"
                  const Text(
                    'İstifadəçinin bütün elanları',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ),

          // 2. 2 Sütunlu Məhsul Gridi (Canlı Firestore datası)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('market_stores').snapshots(),
            builder: (context, snapshot) {
              final allDocs = snapshot.data?.docs ?? [];
              final List<Map<String, dynamic>> storeProducts = [];

              for (final d in allDocs) {
                final data = d.data();
                final isProduct = data['listingType'] == 'product';
                final isMatchOwner = ownerId.isNotEmpty && (data['ownerId'] == ownerId || data['userId'] == ownerId);
                final isMatchStoreName = title.isNotEmpty && (data['store'] == title || data['storeName'] == title);

                if (isProduct && (isMatchOwner || isMatchStoreName)) {
                  storeProducts.add({'id': d.id, ...data});
                }
              }

              // Tarixə görə sıralayırıq (VIP-lər ən üstdə)
              storeProducts.sort((a, b) {
                if (a['isVip'] == true && b['isVip'] != true) return -1;
                if (b['isVip'] == true && a['isVip'] != true) return 1;
                final ta = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch : 0;
                final tb = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch : 0;
                return tb.compareTo(ta);
              });

              if (storeProducts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text('Bu mağazada hələlik aktiv elan yoxdur', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        SizedBox(height: 4),
                        Text('Yeni məhsullar əlavə olunduqda burada görünəcək.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = storeProducts[index];
                      final pBytes = decodeBase64Safe(p['imageBase64']?.toString());
                      final pTitle = p['title']?.toString() ?? '';
                      final pPrice = p['price']?.toString() ?? '0 AZN';
                      final pCity = p['city']?.toString() ?? 'Bakı';
                      final bool pVip = p['isVip'] == true;

                      String pDate = 'Bu gün, 10:02';
                      if (p['createdAt'] is Timestamp) {
                        final dt = (p['createdAt'] as Timestamp).toDate();
                        pDate = '${dt.day}.${dt.month}.${dt.year}';
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: p),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: pVip ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                              width: pVip ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Şəkil sahəsi
                              Expanded(
                                flex: 5,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                      child: (p['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              p['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => pBytes != null
                                                  ? Image.memory(pBytes, fit: BoxFit.cover)
                                                  : Container(
                                                      color: const Color(0xFFEFF6FF),
                                                      child: const Center(
                                                        child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                                                      ),
                                                    ),
                                            )
                                          : (pBytes != null
                                              ? Image.memory(pBytes, fit: BoxFit.cover)
                                              : Container(
                                                  color: const Color(0xFFEFF6FF),
                                                  child: const Center(
                                                    child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                                                  ),
                                                )),
                                    ),
                                    // Mavi "Mağaza" pill-i (Şəkil 1-ə tam uyğun)
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1769D2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Mağaza',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    if (pVip)
                                      Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(3.5),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF59E0B),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Məlumat sahəsi
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        pPrice.contains('AZN') ? pPrice : '$pPrice AZN',
                                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        pTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.25),
                                      ),
                                      Text(
                                        '$pCity, $pDate',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: storeProducts.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
