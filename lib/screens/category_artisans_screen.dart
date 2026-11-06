import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/category_city_service.dart';
import 'artisan_detail_screen.dart';

class CategoryArtisansScreen extends StatefulWidget {
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;
  final Color categoryBgColor;
  final String selectedCity;

  const CategoryArtisansScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryIcon,
    required this.categoryColor,
    required this.categoryBgColor,
    this.selectedCity = 'Bakı',
  });

  @override
  State<CategoryArtisansScreen> createState() => _CategoryArtisansScreenState();
}

class _CategoryArtisansScreenState extends State<CategoryArtisansScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _activeCityFilter;
  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<String>>? _citySub;

  @override
  void initState() {
    super.initState();
    _activeCityFilter = widget.selectedCity;
    _citySub = CategoryCityService.getCitiesStream().listen((cities) {
      if (mounted) setState(() => _cities = cities);
    });
  }

  @override
  void dispose() {
    _citySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _cleanTitle => widget.categoryTitle.replaceAll('\n', ' ').trim();

  // Kateqoriyanın dəqiq uyğunluğunu yoxlayır
  bool _isMatchingCategory(String? ustaCategory) {
    final t = _cleanTitle.toLowerCase();
    if (ustaCategory == null || ustaCategory.trim().isEmpty) {
      return t.contains('tikinti');
    }

    final u = ustaCategory.trim().toLowerCase().replaceAll('\n', ' ');
    if (u == t || u.contains(t) || t.contains(u)) return true;

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
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // 1. ANA SƏHİFƏDƏKİ KİMİ MAVİ QÖVSLİ PROFESSIONAL BAŞLIQ
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1769D2),
                    Color(0xFF0D47A1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x331769D2),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    children: [
                      // Üst zolaq: Geri qayıt düyməsi və Kateqoriya adı
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(widget.categoryIcon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_cleanTitle Ustaları',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const Text(
                                  'Yoxlanılmış və peşəkar ustalar',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Axtarış Qutusu (Mavi başlıq içində ağ axtarış paneli)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 22),
                            hintText: '$_cleanTitle üzrə usta axtarın...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 1.1 ŞƏHƏR FİLTRİ (Çiplər)
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Bütün Şəhərlər', ..._cities].map((city) {
                  final bool isSelected = _activeCityFilter == city;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(city),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1769D2),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? const Color(0xFF1769D2) : Colors.grey.shade300),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _activeCityFilter = city);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 2. USTALAR SİYAHISI (Canlı Firestore datası)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'usta')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];

              // YALNIZ bu kateqoriyaya aid olan ustalar
              var matchingArtisans = allDocs.where((doc) {
                final data = doc.data();
                final cat = (data['category'] ?? data['trade'] ?? '').toString();
                return _isMatchingCategory(cat);
              }).toList();

              // Şəhər filtri
              if (_activeCityFilter != 'Bütün Şəhərlər') {
                matchingArtisans = matchingArtisans.where((doc) {
                  final data = doc.data();
                  final city = (data['city'] ?? 'Bakı').toString().toLowerCase();
                  return city.contains(_activeCityFilter.toLowerCase());
                }).toList();
              }

              // Əgər axtarış mətni varsa
              if (_searchQuery.isNotEmpty) {
                matchingArtisans = matchingArtisans.where((doc) {
                  final data = doc.data();
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();
              }

              if (matchingArtisans.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1769D2).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.categoryIcon, size: 54, color: const Color(0xFF1769D2)),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Axtarışa uyğun usta tapılmadı'
                                : 'Hələlik $_cleanTitle kateqoriyasında usta yoxdur',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Fərqli açar sözlə axtarmağı yoxlayın.'
                                : 'Əgər bu sahə üzrə ustasınızsa, profilinizdən bu kateqoriyanı seçərək ilk siz burada görünün!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = matchingArtisans[index];
                      final data = doc.data();
                      final uid = doc.id;
                      final name = data['fullName'] ?? 'Usta';
                      final phone = data['phone'] ?? '';
                      final photoBase64 = data['photoBase64'] as String?;
                      final ustaCat = data['category'] ?? _cleanTitle;
                      // Hal-hazırda işləyir və ya işləmir statusu (default: false - sərbəstdir)
                      final bool isWorking = data['isWorking'] == true;

                      final Map<String, dynamic> artisanFullData = {
                        ...data,
                        'uid': uid,
                        'id': uid,
                        'fullName': name,
                        'category': ustaCat,
                        'phone': phone,
                        'photoBase64': photoBase64,
                        'isWorking': isWorking,
                      };

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtisanDetailScreen(artisanData: artisanFullData),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Profil fotosu
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                                        backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                                            ? MemoryImage(base64Decode(photoBase64))
                                            : null,
                                        child: (photoBase64 == null || photoBase64.isEmpty)
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                style: const TextStyle(
                                                  color: Color(0xFF1769D2),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 22,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Usta Adı və İxtisası
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Color(0xFF0F172A),
                                                    ),
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
                                                color: const Color(0xFF1769D2).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '$ustaCat Ustası',
                                                style: const TextStyle(
                                                  color: Color(0xFF1769D2),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
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

                                      // Tez əlaqə düymələri (WhatsApp və Zəng)
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
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // AŞAĞI ZOLAĞ: "Anketə baxın" və DƏRHAL YANINDA "Hal-hazırda işləyir / Sərbəstdir" İŞARƏSİ
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 1. Anketə baxın linki
                                      Row(
                                        children: const [
                                          Icon(Icons.person_pin_rounded, color: Color(0xFF1769D2), size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Anketə baxın',
                                            style: TextStyle(
                                              color: Color(0xFF1769D2),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1769D2), size: 10),
                                        ],
                                      ),

                                      // 2. HAL-HAZIRDA İŞLƏYİR VƏ YA İŞLƏMİR İŞARƏSİ
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isWorking ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isWorking ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isWorking ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isWorking ? 'Hal-hazırda işləyir' : 'Sərbəstdir (İşləmir)',
                                              style: TextStyle(
                                                color: isWorking ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: matchingArtisans.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
