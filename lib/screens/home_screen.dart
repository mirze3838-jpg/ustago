import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/video_upload_service.dart';
import '../services/category_city_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'admin_screen.dart';
import 'shorts_screen.dart';
import 'market_screen.dart';
import 'artisan_detail_screen.dart';
import 'category_artisans_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  String _selectedCity = 'Bakı';
  String? _currentUserRole;
  final TextEditingController _searchController = TextEditingController();
  int _adminSecretTap = 0;
  int _unreadNotifications = 3;

  // Kateqoriyalar və Şəhərlər (Admin tərəfindən artırıla bilər, Firestore ilə canlı sinxronlaşır)
  List<Map<String, dynamic>> _categories = List.from(CategoryCityService.defaultCategories);
  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<Map<String, dynamic>>>? _catSub;
  StreamSubscription<List<String>>? _citySub;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initCategoryAndCityStreams();
  }

  void _initCategoryAndCityStreams() {
    _catSub = CategoryCityService.getCategoriesStream().listen((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _citySub = CategoryCityService.getCitiesStream().listen((cities) {
      if (mounted) {
        setState(() {
          _cities = cities;
          if (!_cities.contains(_selectedCity) && _cities.isNotEmpty) {
            _selectedCity = _cities.first;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _citySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  // Nümunə Shorts videoları
  final List<Map<String, String>> _shortsList = [
    {
      'title': 'Kafel-metlax ustasının işi 🔥',
      'views': '128K',
      'image': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Santexnik məsləhəti 💡',
      'views': '95K',
      'image': 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Elektrik işləri necə edilir? ⚡',
      'views': '72K',
      'image': 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Kondisioner quraşdırılması ❄️',
      'views': '64K',
      'image': 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=400&q=80',
    },
  ];

  // Populyar Ustalar
  final List<Map<String, String>> _popularArtisans = [
    {
      'name': 'Rəşad Usta',
      'rating': '4.9',
      'reviews': '524',
      'phone': '+994 50 123 45 67',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
    },
    {
      'name': 'Tural Usta',
      'rating': '4.8',
      'reviews': '412',
      'phone': '+994 55 987 65 43',
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    },
    {
      'name': 'Elvin Usta',
      'rating': '4.9',
      'reviews': '376',
      'phone': '+994 70 555 44 33',
      'image': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=200&q=80',
    },
  ];

  /// Şəkili Firestore 1MB limitinə uyğun sıxışdırır (maks ~700KB)
  Future<Uint8List> _compressCoverImage(Uint8List bytes) async {
    // Əgər 700KB-dan azdırsa, əlavə sıxmaya ehtiyac yoxdur
    if (bytes.length <= 700000) return bytes;
    try {
      // dart:ui ilə şəkili 600px enə qədər kiçildirik
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd != null && bd.lengthInBytes < bytes.length) {
        return bd.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Cover compress error: $e');
    }
    // Sıxma alınmadısa orijinalı qaytarırıq
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ShortsScreen();
      case 2:
        return const MarketScreen();
      case 3:
        return _buildMessagesTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildMessagesTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mesajlar və Dəstək', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Rəsmi Dəstək Kartı
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1769D2),
                child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
              ),
              title: const Text('UstaGo Rəsmi Dəstək', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: const Text('Sualınız və ya təklifiniz var? 7/24 əlaqə üçün toxunun.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF1769D2)),
              onTap: _showSupportDialog,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Məlumatlandırma kartı (Ustalarla birbaşa əlaqə bələdçisi)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ustalarla Ən Sürətli Əlaqə',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'UstaGo platformasında hər bir ustanın profilində birbaşa "Zəng Et" və "WhatsApp" düymələri yerləşdirilib. Bu sayədə usta ilə gözləmədən, ən sürətli şəkildə əlaqə saxlayıb qiymət və vaxt təyin edə bilərsiniz.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Usta Axtarışına Keç'),
                    onPressed: () => setState(() => _currentIndex = 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dəstək Dialoqu (WhatsApp, Zəng, Email)
  void _showSupportDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1769D2).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFF1769D2), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'UstaGo Dəstək Xidməti',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Suallarınızı operativ cavablandırırıq',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Bizimlə birbaşa əlaqə vasitələri:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade200),
              ),
              tileColor: Colors.green.shade50.withOpacity(0.5),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat, color: Colors.white, size: 20),
              ),
              title: const Text('WhatsApp Dəstək Xətti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Aktiv (7/24 Dəstək)', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.green),
              onTap: () {
                Navigator.pop(ctx);
                _openWhatsApp('+994501234567');
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              tileColor: Colors.blue.shade50.withOpacity(0.5),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1769D2),
                child: Icon(Icons.phone, color: Colors.white, size: 20),
              ),
              title: const Text('Qaynar Xəttə Zəng Et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('+994 50 123 45 67', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1769D2)),
              onTap: () {
                Navigator.pop(ctx);
                _makeCall('+994501234567');
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              tileColor: Colors.grey.shade50,
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.email, color: Colors.white, size: 20),
              ),
              title: const Text('E-mail ilə Əlaqə', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('mirze3838@gmail.com', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('mailto:mirze3838@gmail.com?subject=UstaGo%20K%C3%B6m%C9%99k');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Bütün Kateqoriyalar Modal Pəncərəsi
  void _showAllCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _categories.where((c) {
              final title = (c['title'] as String).replaceAll('\n', ' ').toLowerCase();
              return title.contains(filter.toLowerCase());
            }).toList();

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.grid_view_rounded, color: Color(0xFF1769D2), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Bütün Kateqoriyalar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setSheetState(() => filter = v),
                    decoration: InputDecoration(
                      hintText: 'Kateqoriya axtarın (məs: Santexnik, Mebel...)',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Uyğun kateqoriya tapılmadı', style: TextStyle(color: Colors.grey)),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final cat = filtered[i];
                              final isOther = cat['id'] == 'def_diger';
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CategoryArtisansScreen(
                                        categoryTitle: isOther ? 'Bütün Ustalar' : cat['title'],
                                        categoryIcon: cat['icon'] as IconData? ?? Icons.handyman,
                                        categoryColor: cat['color'] as Color? ?? const Color(0xFF1769D2),
                                        categoryBgColor: cat['bgColor'] as Color? ?? const Color(0xFFEFF6FF),
                                        selectedCity: _selectedCity,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (cat['bgColor'] as Color? ?? const Color(0xFFEFF6FF)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: (cat['color'] as Color? ?? const Color(0xFF1769D2)).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData? ?? Icons.handyman,
                                        color: cat['color'] as Color? ?? const Color(0xFF1769D2),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (cat['title'] as String).replaceAll('\n', ' '),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Kömək və Dəstək Modal Pəncərəsi (FAQ, Təlimat və Əlaqə)
  void _showHelpSupportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.help_center_rounded, color: Color(0xFF1769D2), size: 26),
                      SizedBox(width: 8),
                      Text(
                        'Kömək və Dəstək',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // FAQ 1
              ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.question_answer_outlined, color: Color(0xFF1769D2)),
                title: const Text('UstaGo xidmətləri ödənişlidirmi?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                children: const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Xeyr! UstaGo həm müştərilər, həm də ustalar üçün tamamilə PULSUZDUR. Qeydiyyatdan keçmək, usta axtarmaq, Shorts video paylaşmaq və zəng etmək ödənişsizdir.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),

              // FAQ 2
              ExpansionTile(
                leading: const Icon(Icons.video_library_outlined, color: Color(0xFF1769D2)),
                title: const Text('Portfolioma video necə əlavə edim?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                children: const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Profil bölməsinə keçin, "İşlərim və Portfoliom" başlığının yanındakı "Yeni Paylaş" düyməsinə toxunun. "Shorts Video Paylaş" rejimini seçərək gördüyünüz işin videosunu yükləyin. Video avtomatik həm profilinizdə, həm də ana səhifədəki Shorts bölməsində yayımlanacaq.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),

              // FAQ 3
              ExpansionTile(
                leading: const Icon(Icons.verified_outlined, color: Color(0xFF1769D2)),
                title: const Text('Usta kimi necə təsdiqlənə bilərəm?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                children: const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Qeydiyyat zamanı şəhər, rayon və peşə məlumatlarınızı dəqiq qeyd edin. Portfolionuza real iş nümunələri əlavə edin. Məlumatlarınız yoxlandıqdan sonra profilinizə Mavi Təsdiq nişanı verilir.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text(
                'Birbaşa Dəstək Xətti:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openWhatsApp('+994501234567');
                      },
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _makeCall('+994501234567');
                      },
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Zəng Et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    _adminSecretTap++;
                    if (_adminSecretTap >= 5) {
                      _adminSecretTap = 0;
                      Navigator.pop(ctx);
                      _showAdminAccessDialog();
                    }
                  },
                  child: Text(
                    'UstaGo v1.0.0 (Bütün hüquqlar qorunur)',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '994${cleanPhone.substring(1)}';
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        // 1. Mavi Üst Başlıq və Axtarış Paneli (Header)
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),

        // Axtarış aktiv olduqda Canlı Nəticələr Bloku (Şəhər, Rayon, Usta adı və İxtisasa görə)
        if (_searchController.text.trim().isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1769D2).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'usta')
                    .snapshots(),
                builder: (context, uSnap) {
                  final q = _searchController.text.trim().toLowerCase();
                  final docs = uSnap.data?.docs ?? [];
                  final matchingUstas = docs.where((d) {
                    final data = d.data();
                    final city = (data['city'] ?? '').toString().toLowerCase();
                    final name = (data['fullName'] ?? '').toString().toLowerCase();
                    final cat = (data['category'] ?? '').toString().toLowerCase();
                    final bio = (data['bio'] ?? '').toString().toLowerCase();
                    return city.contains(q) || name.contains(q) || cat.contains(q) || bio.contains(q);
                  }).map((d) {
                    final m = Map<String, dynamic>.from(d.data());
                    m['id'] = d.id;
                    m['uid'] = d.id;
                    return m;
                  }).toList();

                  final matchingCats = _categories.where((c) {
                    final title = (c['title'] as String).toLowerCase();
                    return title.contains(q);
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.search, color: Color(0xFF1769D2), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '"${_searchController.text.trim()}" axtarış nəticələri',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Text('Təmizlə', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (matchingUstas.isEmpty && matchingCats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 36),
                                const SizedBox(height: 6),
                                Text(
                                  '"$q" üzrə usta və ya kateqoriya tapılmadı',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Fərqli şəhər (məs: Yasamal, Gəncə, Bakı) və ya peşə daxil edin',
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 1. TAPILAN USTALAR SİYAHISI (Şəhər, Rayon, İxtisas və Əlaqə ilə)
                      if (matchingUstas.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF1769D2)),
                            const SizedBox(width: 6),
                            Text(
                              'Tapılan Ustalar (${matchingUstas.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: matchingUstas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final u = matchingUstas[idx];
                            final uName = (u['fullName'] ?? 'Usta').toString();
                            final uTrade = (u['category'] ?? 'Usta').toString();
                            final uCity = (u['city'] ?? 'Bakı').toString();
                            final uPhone = (u['phone'] ?? '').toString();
                            final uPhoto = u['photoBase64'] as String?;

                            ImageProvider? avatarImg;
                            if (uPhoto != null && uPhoto.isNotEmpty) {
                              try {
                                avatarImg = MemoryImage(base64Decode(uPhoto));
                              } catch (_) {}
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtisanDetailScreen(artisanData: u),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                                      backgroundImage: avatarImg,
                                      child: avatarImg == null
                                          ? Text(
                                              uName.isNotEmpty ? uName[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  uName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified, color: Color(0xFF1769D2), size: 15),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                uTrade,
                                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.location_on, size: 11, color: Colors.red),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      uCity,
                                                      style: TextStyle(
                                                        color: Colors.red.shade800,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
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
                                    if (uPhone.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.call, color: Color(0xFF00C853), size: 20),
                                        tooltip: 'Zəng et',
                                        onPressed: () => _makeCall(uPhone),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                        tooltip: 'WhatsApp',
                                        onPressed: () => _openWhatsApp(uPhone),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2. UYĞUN KATEQORİYALAR
                      if (matchingCats.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.category_rounded, size: 16, color: Color(0xFF1769D2)),
                            const SizedBox(width: 6),
                            const Text(
                              'Uyğun Kateqoriyalar',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: matchingCats.map((c) {
                            return ActionChip(
                              avatar: Icon(c['icon'], size: 16, color: c['color']),
                              label: Text((c['title'] as String).replaceAll('\n', ' ')),
                              backgroundColor: c['bgColor'],
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryArtisansScreen(
                                      categoryTitle: c['title'],
                                      categoryIcon: c['icon'],
                                      categoryColor: c['color'],
                                      categoryBgColor: c['bgColor'],
                                      selectedCity: _selectedCity,
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],

        // 2. Kateqoriyalar Bölməsi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF1769D2),
              title: 'Kateqoriyalar',
              actionTitle: 'Hamısına bax',
              onTap: _showAllCategoriesSheet,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = _categories[index];
                return _buildCategoryItem(cat);
              },
              childCount: _categories.length,
            ),
          ),
        ),

        // 3. Shorts Videolar Bölməsi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.play_circle_fill,
              iconColor: Colors.red,
              title: 'Shorts',
              actionTitle: 'Hamısını izlə',
              onTap: () => setState(() => _currentIndex = 1),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 230,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('shorts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Səhifə yenilənərkən heç bir köhnə stok şəkil sıçrayışı olmasın - səliqəli müasir skelet yüklənməsi
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.2), size: 36),
                        ),
                      );
                    },
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final List<Map<String, dynamic>> dynamicShorts = [];

                for (var d in docs) {
                  final data = d.data();
                  dynamicShorts.add({
                    'id': d.id,
                    'title': data['title'] ?? 'Usta İşi',
                    'author': data['artisanName'] ?? 'Usta',
                    'trade': data['trade'] ?? 'Usta',
                    'videoUrl': data['videoUrl'] ?? '',
                    'thumbnailBase64': data['thumbnailBase64'],
                    'thumbnailUrl': data['thumbnailUrl'],
                  });
                }

                if (dynamicShorts.isEmpty) {
                  return const Center(
                    child: Text(
                      'Hələ ki Shorts video paylaşılmayıb',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: dynamicShorts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildDynamicShortsCard(dynamicShorts[index], index);
                  },
                );
              },
            ),
          ),
        ),

        // 4. Populyar Ustalar Bölməsi (Canlı Firestore bazasından, seçilən şəhər öncəlikli)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFB300),
              title: 'Populyar Ustalar',
              actionTitle: 'Hamısına bax',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryArtisansScreen(
                      categoryTitle: 'Bütün Ustalar',
                      categoryIcon: Icons.people_alt_rounded,
                      categoryColor: const Color(0xFF1769D2),
                      categoryBgColor: const Color(0xFFEFF6FF),
                      selectedCity: _selectedCity,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'usta')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              List<Map<String, dynamic>> list = [];
              if (docs.isNotEmpty) {
                list = docs.map((d) {
                  final m = Map<String, dynamic>.from(d.data());
                  m['id'] = d.id;
                  m['uid'] = d.id;
                  return m;
                }).toList();

                // Seçilmiş şəhərə uyğun olan ustalar ön sıralarda çıxır
                list.sort((a, b) {
                  final aCity = (a['city'] ?? '').toString().toLowerCase();
                  final bCity = (b['city'] ?? '').toString().toLowerCase();
                  final sc = _selectedCity.toLowerCase();
                  final aMatches = aCity.contains(sc);
                  final bMatches = bCity.contains(sc);
                  if (aMatches && !bMatches) return -1;
                  if (!aMatches && bMatches) return 1;
                  return 0;
                });
              } else {
                list = _popularArtisans.map((a) => Map<String, dynamic>.from(a)).toList();
              }

              return SizedBox(
                height: 155,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildArtisanCard(list[index]);
                  },
                ),
              );
            },
          ),
        ),

        // Boşluq (Aşağı naviqasiya üçün)
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  // Bildirişlər pəncərəsi
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tutacaq
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active, color: Color(0xFF1769D2), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Bildirişlər',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      if (_unreadNotifications > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_unreadNotifications yeni',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_unreadNotifications > 0)
                    TextButton(
                      onPressed: () {
                        setState(() => _unreadNotifications = 0);
                        setSheetState(() {});
                      },
                      child: const Text('Hamısını oxu', style: TextStyle(color: Color(0xFF1769D2), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _buildNotificationItem(
                      icon: Icons.celebration,
                      iconBg: Colors.amber.shade100,
                      iconColor: Colors.amber.shade900,
                      title: 'UstaGo-ya Xoş Gəlmisiniz! 🎉',
                      body: 'Azərbaycanın peşəkar usta və xidmət platformasındasınız. Rahatlıqla usta tapın və ya sifariş qəbul edin.',
                      time: 'İndi',
                      isUnread: _unreadNotifications >= 1,
                    ),
                    _buildNotificationItem(
                      icon: Icons.verified_user,
                      iconBg: Colors.blue.shade100,
                      iconColor: const Color(0xFF1769D2),
                      title: 'Profil Təhlükəsizliyi 🛡️',
                      body: 'Hesabınız uğurla aktivləşdirilib. Profilinizdə gördüyünüz işlərin foto və videolarını paylaşa bilərsiniz.',
                      time: '2 saat əvvəl',
                      isUnread: _unreadNotifications >= 2,
                    ),
                    _buildNotificationItem(
                      icon: Icons.tips_and_updates,
                      iconBg: Colors.green.shade100,
                      iconColor: Colors.green.shade800,
                      title: 'Yeni İmkan: Usta Haqqında Məlumat 💡',
                      body: 'Artıq profilinizdə "Usta Haqqında" məlumatınızı istədiyiniz vaxt redaktə edib yeniləyə bilərsiniz!',
                      time: 'Dünən',
                      isUnread: _unreadNotifications >= 3,
                    ),
                    _buildNotificationItem(
                      icon: Icons.video_collection,
                      iconBg: Colors.purple.shade100,
                      iconColor: Colors.purple.shade800,
                      title: 'Shorts Video Bölməsi 🎬',
                      body: 'İşlərinizin qısa videolarını yükləyin, minlərlə müştəri işinizi görsün!',
                      time: '3 gün əvvəl',
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUnread ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. MAVİ BAŞLIQ (Dizayndakı kimi qövsli kart)
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1769D2),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Loqo və tətbiq adı
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UstaGo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Hər iş üçün doğru usta!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bildiriş zəngi
                  Material(
                    color: Colors.transparent,
                    child: IconButton(
                      tooltip: 'Bildirişlər',
                      onPressed: _showNotificationsSheet,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 26,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                          ),
                          if (_unreadNotifications > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_unreadNotifications',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Axtarış Paneli və Şəhər Seçimi (Dizayndakı kimi ağ qutu)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF64748B), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Usta, şəhər, rayon və ya xidmət axtarın...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchController.text.trim().isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 8),
                    // Şəhər seçimi (Admin tərəfindən artırılan şəhərlər daxil olmaqla)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _cities.contains(_selectedCity) ? _selectedCity : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1769D2), size: 18),
                        items: _cities.map((String city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF1769D2), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  city,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCity = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BÖLMƏ BAŞLIĞI
  Widget _buildSectionTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String actionTitle,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                actionTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1769D2)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1769D2)),
            ],
          ),
        ),
      ],
    );
  }

  // KATEQORİYA KARTI (Dizayndakı rəngli ikonlar - Toxunanda həmin kateqoriyanın ustaları açılır)
  Widget _buildCategoryItem(Map<String, dynamic> cat) {
    final bool isOther = cat['id'] == 'def_diger';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (isOther) {
          _showAllCategoriesSheet();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryArtisansScreen(
              categoryTitle: cat['title'],
              categoryIcon: cat['icon'],
              categoryColor: cat['color'],
              categoryBgColor: cat['bgColor'],
              selectedCity: _selectedCity,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cat['bgColor'],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (cat['color'] as Color).withOpacity(0.15)),
              ),
              child: Center(
                child: Icon(cat['icon'], color: cat['color'], size: 30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cat['title'],
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // Kateqoriyaya uyğun parlaq real kadr / başlıq şəkli
  String _getCategoryPlaceholderImage(String? trade) {
    final t = (trade ?? '').toLowerCase();
    if (t.contains('santexnik') || t.contains('su')) {
      return 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&w=400&q=80';
    } else if (t.contains('elektrik') || t.contains('şit') || t.contains('naqil')) {
      return 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=400&q=80';
    } else if (t.contains('kondisioner') || t.contains('kombi') || t.contains('soyuducu')) {
      return 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=400&q=80';
    } else if (t.contains('mebel') || t.contains('dülgər')) {
      return 'https://images.unsplash.com/photo-1538688525198-9b88f6f53126?auto=format&fit=crop&w=400&q=80';
    } else if (t.contains('avto') || t.contains('avtomobil')) {
      return 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=400&q=80';
    } else if (t.contains('rəngsaz') || t.contains('malyar') || t.contains('boya')) {
      return 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?auto=format&fit=crop&w=400&q=80';
    }
    // Default Tikinti və təmir üçün gözəl real kadr
    return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=400&q=80';
  }

  // DİNAMİK YÜKLƏNƏN SHORTS KARTI (Videonun başlıq şəkli ilə, qaranlıq görünmür)
  Widget _buildDynamicShortsCard(Map<String, dynamic> item, int index) {
    final String? thumbnailBase64 = item['thumbnailBase64'];
    final String? thumbnailUrl = item['thumbnailUrl'];
    final String trade = (item['trade'] ?? 'Tikinti').toString();

    // Video kadrı yüklənənə qədər zərif tünd fon (köhnə stok şəkillər heç vaxt görünmür)
    final Widget fallbackVisual = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white38,
            size: 28,
          ),
        ),
      ),
    );

    Widget coverWidget;
    if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
      try {
        coverWidget = Image.memory(
          base64Decode(thumbnailBase64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => fallbackVisual,
        );
      } catch (_) {
        coverWidget = fallbackVisual;
      }
    } else if (thumbnailUrl != null && thumbnailUrl.isNotEmpty && !thumbnailUrl.contains('unsplash.com')) {
      coverWidget = Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return fallbackVisual;
        },
        errorBuilder: (_, __, ___) => fallbackVisual,
      );
    } else {
      // İstifadəçi əllə şəkil qoymayıbsa, BİRBAŞA VİDEONUN ÖZÜNÜN İÇİNDƏN KADR ÇIXARILIR VƏ GÖSTƏRİLİR!
      final videoUrl = (item['videoUrl'] ?? '').toString();
      if (videoUrl.isNotEmpty) {
        coverWidget = _ShortsVideoThumbnail(
          key: ValueKey(item['id'] ?? videoUrl),
          videoUrl: videoUrl,
          fallback: fallbackVisual,
        );
      } else {
        coverWidget = fallbackVisual;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShortsScreen(initialIndex: index),
          ),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. VİDEONUN REAL BAŞLIQ FOTOSU (Qaranlıq görünməsin deyə)
                    coverWidget,

                    // 2. Yalnız aşağıda zərif qradiyent (şəkli qaraltmır)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 72,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // 3. Mərkəzdə Play ikonu (Mavi dairəsiz, təmiz ağ play)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),

                    // 5. Aşağıda Müəllif adı
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Text(
                        item['author'] ?? 'Usta',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item['title'] ?? 'Usta Videosu',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  // SHORTS KARTI
  Widget _buildShortsCard(Map<String, String> item) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _currentIndex = 1),
      child: SizedBox(
        width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                  ),
                  // Qaranlıq qradiyent
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Mərkəzdə Play ikonu
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  // Aşağıda Baxış sayı
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          item['views']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['title']!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    ),
    );
  }

  // POPULYAR USTA KARTI (Şəhər, Rayon və Zəng et düyməsi ilə)
  Widget _buildArtisanCard(Map<String, dynamic> artisan) {
    final String name = (artisan['fullName'] ?? artisan['name'] ?? 'Usta').toString();
    final String phone = (artisan['phone'] ?? '').toString();
    final String city = (artisan['city'] ?? 'Bakı').toString();
    final String? photoBase64 = artisan['photoBase64'] as String?;
    final String? image = artisan['image'] as String?;
    final String rating = (artisan['rating'] ?? '4.9').toString();
    final String reviews = (artisan['reviews'] ?? artisan['reviewsCount'] ?? '10').toString();

    ImageProvider? avatarImg;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(photoBase64));
      } catch (_) {}
    } else if (image != null && image.isNotEmpty) {
      avatarImg = NetworkImage(image);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtisanDetailScreen(
              artisanData: artisan,
            ),
          ),
        );
      },
      child: Container(
        width: 145,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
              backgroundImage: avatarImg,
              child: avatarImg == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                    )
                  : null,
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 10, color: Colors.red),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, color: Colors.amber, size: 11),
                Text(
                  rating,
                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (phone.isNotEmpty) {
                    _makeCall(phone);
                  }
                },
                icon: const Icon(Icons.call, size: 12, color: Colors.white),
                label: const Text('Zəng et', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AŞAĞI NAVİQASİYA (Dizayndakı kimi 5 tab)
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1769D2),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Ana səhifə',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Shorts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront_rounded),
            label: 'Alış-Satış',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat_bubble_outline),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            label: 'Mesajlar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  void _showAdminAccessDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.security, color: Color(0xFF1769D2)),
            SizedBox(width: 8),
            Text('Admin Girişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin panelinə daxil olmaq üçün təhlükəsizlik şifrəsini daxil edin:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Admin Şifrəsi',
                prefixIcon: Icon(Icons.lock),
                hintText: 'Şifrə: ustago2026',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1769D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin == 'ustago2026' || pin == '7777' || _currentUserRole == 'admin') {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yanlış admin şifrəsi!'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Daxil ol', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Yeni İş / Şəkil və ya Shorts Video Paylaşmaq dialoqu
  Future<void> _showAddPostDialog(String uid, String authorName, String role) async {
    final titleController = TextEditingController();
    final videoLinkController = TextEditingController();
    String selectedCat = 'Tikinti';
    Uint8List? selectedImageBytes;
    XFile? pickedVideo;
    Uint8List? pickedVideoBytes;
    XFile? pickedCover;
    Uint8List? pickedCoverBytes;
    bool isVideoPost = false;
    bool isUploading = false;
    double uploadProgress = 0.0;
    String uploadStatusText = '0%';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Yeni İş Paylaş (Qalereya & Shorts)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gördüyünüz işin fotosunu və ya qısa videosunu paylaşın. Videolar birbaşa Shorts bölməsinə də əlavə olunacaq!',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Foto / Video seçimi keçidi
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => isVideoPost = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isVideoPost ? const Color(0xFF1769D2) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library, color: !isVideoPost ? Colors.white : Colors.black87, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Foto Paylaş',
                                style: TextStyle(
                                  color: !isVideoPost ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => isVideoPost = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isVideoPost ? Colors.red.shade700 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library, color: isVideoPost ? Colors.white : Colors.black87, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Video / Shorts',
                                style: TextStyle(
                                  color: isVideoPost ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Əgər ŞƏKİL seçilibsə
                if (!isVideoPost) ...[
                  Center(
                    child: InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 75,
                        );
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setModalState(() {
                            selectedImageBytes = bytes;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: selectedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate_rounded, size: 44, color: Color(0xFF1769D2)),
                                  SizedBox(height: 8),
                                  Text(
                                    'İşin Şəklini Seçin',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                  ),
                                  SizedBox(height: 4),
                                  Text('Qalereyadan yükləmək üçün toxunun', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Əgər VİDEO seçilibsə
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        if (pickedVideo != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video seçildi: ${pickedVideo!.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: () => setModalState(() {
                                  pickedVideo = null;
                                  pickedVideoBytes = null;
                                }),
                              ),
                            ],
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.video_file),
                            label: const Text('Qalereyadan Video Seç'),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final video = await picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                final bytes = await video.readAsBytes();
                                setModalState(() {
                                  pickedVideo = video;
                                  pickedVideoBytes = bytes;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text('və ya birbaşa video linki yapışdırın:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: videoLinkController,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'https://... (MP4, YouTube və s.)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link, size: 18),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Videonun Üz Qabığı Şəkli (Thumbnail / Başlıq fotosu)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: pickedCoverBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(pickedCoverBytes!, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1769D2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickedCoverBytes != null ? 'Başlıq şəkli seçildi' : 'Videonun Başlıq Şəkli (Kover)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                pickedCoverBytes != null ? pickedCover!.name : 'Videoda qaranlıq qalmamaq üçün kover fotosu seçin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                            if (img != null) {
                              final rawBytes = await img.readAsBytes();
                              // Firestore 1MB limit üçün şəkli sıxışdırırıq
                              final compressed = await _compressCoverImage(rawBytes);
                              setModalState(() {
                                pickedCover = img;
                                pickedCoverBytes = compressed;
                              });
                            }
                          },
                          child: Text(pickedCoverBytes != null ? 'Dəyiş' : 'Seç'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Təsvir
                TextField(
                  controller: titleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'İş haqqında qısa məlumat *',
                    hintText: 'Məsələn: Yasamalda 3 otaqlı evin tam kafel-metlax işləri...',
                  ),
                ),
                const SizedBox(height: 12),

                // Kateqoriya
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: const InputDecoration(
                    labelText: 'Kateqoriya',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((c) {
                    final title = (c['title'] as String).replaceAll('\n', ' ');
                    return DropdownMenuItem(value: title, child: Text(title));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 20),

                // Paylaş düyməsi və ya Yüklənmə Faizi
                if (isUploading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: uploadProgress > 0 ? uploadProgress : null,
                            minHeight: 10,
                            backgroundColor: Colors.blue.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1769D2)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Video Yüklənir: $uploadStatusText',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1769D2)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Zəhmət olmasa gözləyin, video bulud bazasına köçürülür...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVideoPost ? Colors.red.shade700 : const Color(0xFF1769D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim().isEmpty ? 'Usta İşi' : titleController.text.trim();

                        if (!isVideoPost && selectedImageBytes == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zəhmət olmasa şəkil seçin!')),
                          );
                          return;
                        }

                        if (isVideoPost && pickedVideo == null && videoLinkController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zəhmət olmasa video seçin və ya link daxil edin!')),
                          );
                          return;
                        }

                        setModalState(() => isUploading = true);

                        try {
                          if (isVideoPost) {
                            String finalVideoUrl = videoLinkController.text.trim();

                            if (pickedVideo != null && pickedVideoBytes != null) {
                              try {
                                setModalState(() {
                                  uploadStatusText = 'Bulud bazasına yüklənir...';
                                  uploadProgress = 0.2;
                                });

                                final uploadedUrl = await VideoUploadService.uploadVideo(
                                  videoBytes: pickedVideoBytes!,
                                  fileName: pickedVideo!.name,
                                  onProgress: (p) {
                                    setModalState(() {
                                      uploadProgress = p;
                                      uploadStatusText = '${(p * 100).toStringAsFixed(0)}%';
                                    });
                                  },
                                );

                                finalVideoUrl = uploadedUrl;
                              } catch (e) {
                                debugPrint('Video upload error: $e');
                                if (finalVideoUrl.isEmpty) {
                                  setModalState(() => isUploading = false);
                                  if (mounted) {
                                    final errStr = e.toString();
                                    final friendlyMsg = errStr.contains('403') || errStr.contains('Forbidden')
                                        ? 'Video serverinə bağlantı xətası (CORS). Zəhmət olmasa video linki daxil edin və ya APK tətbiqindən istifadə edin.'
                                        : 'Video yükləmə xətası: $e\nZəhmət olmasa internet bağlantısını yoxlayın və ya video linki daxil edin.';

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(friendlyMsg),
                                        backgroundColor: Colors.orange.shade900,
                                        duration: const Duration(seconds: 7),
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }
                            }

                            final String coverBase64 = pickedCoverBytes != null ? base64Encode(pickedCoverBytes!) : '';

                            String? uPhoto;
                            try {
                              final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                              if (uDoc.exists) {
                                uPhoto = uDoc.data()?['photoBase64'];
                              }
                            } catch (_) {}

                            // 1. Profil postlarına əlavə et
                            await FirebaseFirestore.instance.collection('posts').add({
                              'userId': uid,
                              'authorName': authorName,
                              'authorRole': role,
                              'title': title,
                              'category': selectedCat,
                              'videoUrl': finalVideoUrl,
                              'imageBase64': coverBase64,
                              'thumbnailBase64': coverBase64,
                              'thumbnailUrl': '',
                              'isVideo': true,
                              'createdAt': FieldValue.serverTimestamp(),
                              'likes': 0,
                            });

                            // 2. Shorts bölməsinə əlavə et
                            await FirebaseFirestore.instance.collection('shorts').add({
                              'userId': uid,
                              'title': title,
                              'videoUrl': finalVideoUrl,
                              'thumbnailBase64': coverBase64,
                              'thumbnailUrl': '',
                              'authorPhotoBase64': uPhoto ?? '',
                              'artisanName': authorName,
                              'trade': selectedCat,
                              'phone': '+994 50 000 00 00',
                              'likes': 0,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            final base64String = base64Encode(selectedImageBytes!);

                            await FirebaseFirestore.instance.collection('posts').add({
                              'userId': uid,
                              'authorName': authorName,
                              'authorRole': role,
                              'title': title,
                              'category': selectedCat,
                              'imageBase64': base64String,
                              'isVideo': false,
                              'createdAt': FieldValue.serverTimestamp(),
                              'likes': 0,
                            });
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isVideoPost ? 'Shorts video uğurla paylaşıldı! 🎉' : 'İşiniz uğurla paylaşıldı! 🎉'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isUploading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: Text(
                        isVideoPost ? 'Shorts Kimi Paylaş' : 'Paylaş',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Paylaşılan işin böyük təsviri və silinməsi
  void _showPostDetailModal(String postId, Map<String, dynamic> post) {
    final String videoUrl = (post['videoUrl'] ?? '').toString().trim();
    final bool isVideo = post['isVideo'] == true || videoUrl.isNotEmpty;
    final String? imgBase64 = (post['imageBase64'] ?? post['thumbnailBase64']) as String?;

    // 1. Əgər VİDEO postudursa: tam ekran video baxışı
    if (isVideo && videoUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenVideoViewer(
            videoUrl: videoUrl,
            title: post['title'] ?? '',
            category: post['category'] ?? 'Usta İşi',
            postId: postId,
            coverBase64: imgBase64,
            isOwner: true,
          ),
        ),
      );
      return;
    }

    // 2. Əgər FOTO postudursa (və ya şəkilli paylaşımdırsa): tam ekran foto baxış səhifəsinə keçirik
    if (imgBase64 != null && imgBase64.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Zoom və Pan dəstəkli tam ekran foto
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.memory(
                      base64Decode(imgBase64),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Yuxarı naviqasiya (Geri və Sil düyməsi)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  title: const Text('Şəkli Sil'),
                                  content: const Text('Bu şəkli qalereyanızdan silmək istəyirsiniz?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Xeyr')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Bəli, Sil', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Paylaşım silindi.')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Aşağı başlıq və kateqoriya
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (post['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1769D2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              post['category'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          post['title'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
  }

  // Profil daxilində İnstagram tərzi Qalereya
  Widget _buildInstagramGallery(String uid, String authorName, String role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.grid_on_rounded, size: 20, color: Color(0xFF1769D2)),
                SizedBox(width: 8),
                Text(
                  'İşlərim və Portfoliom',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Yeni Paylaş'),
              onPressed: () => _showAddPostDialog(uid, authorName, role),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'Hələlik heç bir iş paylaşılmayıb',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gördüyünüz işlərin foto və nümunələrini əlavə edərək müştəri toplayın!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2)),
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      label: const Text('İlk İşini Paylaş', style: TextStyle(color: Colors.white)),
                      onPressed: () => _showAddPostDialog(uid, authorName, role),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
                final bool isVideo = data['isVideo'] == true || (data['videoUrl'] != null && (data['videoUrl'] as String).isNotEmpty);

                return InkWell(
                  onTap: () => _showPostDetailModal(doc.id, data),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(
                          builder: (context) {
                            if (base64Img != null && base64Img.isNotEmpty) {
                              return Image.memory(base64Decode(base64Img), fit: BoxFit.cover);
                            }
                            final thumbUrl = data['thumbnailUrl']?.toString();
                            if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                              return Image.network(thumbUrl, fit: BoxFit.cover);
                            }
                            final videoUrl = (data['videoUrl'] ?? '').toString();
                            if (videoUrl.isNotEmpty) {
                              return _ShortsVideoThumbnail(
                                key: ValueKey('post_thumb_${doc.id}'),
                                videoUrl: videoUrl,
                                fallback: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36),
                                      if ((data['title'] ?? '').toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          data['title'].toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Container(
                              color: const Color(0xFF1E293B),
                              child: const Center(
                                child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 32),
                              ),
                            );
                          },
                        ),
                        if (isVideo)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.play_arrow, color: Colors.white, size: 10),
                                  SizedBox(width: 2),
                                  Text('Shorts', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
  Future<void> _showPhotoPicker(String uid) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1769D2)),
              title: const Text('Qalereyadan seç'),
              onTap: () async {
                Navigator.pop(ctx);
                await _updateProfileImage(uid, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF1769D2)),
              title: const Text('Kamera ilə çək'),
              onTap: () async {
                Navigator.pop(ctx);
                await _updateProfileImage(uid, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Şəkli sil', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'photoBase64': '',
                  }, SetOptions(merge: true));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profil şəkli silindi.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfileImage(String uid, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = base64Encode(bytes);

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'photoBase64': base64String,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil şəkli uğurla yeniləndi!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Profil məlumatlarını redaktə etmək üçün dialoq
  void _showEditProfileDialog(String uid, Map<String, dynamic>? userData) {
    final nameController = TextEditingController(text: userData?['fullName'] ?? '');
    final phoneController = TextEditingController(text: userData?['phone'] ?? '');
    final bioController = TextEditingController(text: userData?['bio'] ?? '');
    String selectedRole = userData?['role'] ?? 'usta';
    String selectedUstaCategory = userData?['category'] ?? 'Tikinti';
    bool isWorkingStatus = userData?['isWorking'] == true;

    final rawCity = (userData?['city'] ?? 'Bakı').toString();
    String selectedCityVal = 'Bakı';
    String districtText = '';
    if (rawCity.contains(',')) {
      final parts = rawCity.split(',');
      selectedCityVal = parts[0].trim();
      districtText = parts.sublist(1).join(',').trim();
    } else {
      selectedCityVal = rawCity.trim();
    }
    if (!_cities.contains(selectedCityVal) && _cities.isNotEmpty) {
      selectedCityVal = _cities.first;
    }
    final districtController = TextEditingController(text: districtText);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Profil Məlumatlarını Redaktə Et', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Ad və Soyad', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobil Nömrə', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 12),

                // Hesab Növü (Rol)
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Hesab Növü', prefixIcon: Icon(Icons.badge_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'usta', child: Text('Usta kimi')),
                    DropdownMenuItem(value: 'customer', child: Text('Müştəri kimi')),
                    DropdownMenuItem(value: 'seller', child: Text('Satıcı / Mağaza')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),

                // Şəhər və Rayon / Ərazi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _cities.contains(selectedCityVal) ? selectedCityVal : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
                        decoration: const InputDecoration(labelText: 'Şəhər', prefixIcon: Icon(Icons.location_city, color: Color(0xFF1769D2))),
                        items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCityVal = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: districtController,
                        decoration: const InputDecoration(
                          labelText: 'Rayon / Ərazi',
                          hintText: 'Məs: Yasamal, Xətai',
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Əgər Usta seçilibsə, İxtisas (Kateqoriya)
                if (selectedRole == 'usta') ...[
                  DropdownButtonFormField<String>(
                    value: selectedUstaCategory,
                    decoration: const InputDecoration(labelText: 'Usta İxtisası / Kateqoriya', prefixIcon: Icon(Icons.construction)),
                    items: _categories.map((c) {
                      final title = (c['title'] as String).replaceAll('\n', ' ');
                      return DropdownMenuItem(value: title, child: Text(title));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedUstaCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Usta Haqqında Məlumat (Bio / Təcrübə)
                  TextField(
                    controller: bioController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Usta Haqqında Məlumat',
                      hintText: 'Təcrübəniz, gördüyünüz işlər və xidmət şərtləriniz...',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hal-hazırda işləyir / Sərbəstdir Switch-i
                  Container(
                    decoration: BoxDecoration(
                      color: isWorkingStatus ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWorkingStatus ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      title: Text(
                        isWorkingStatus ? 'Hal-hazırda işləyirəm' : 'Sərbəstəm (İşləmirəm)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isWorkingStatus ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                        ),
                      ),
                      value: isWorkingStatus,
                      activeColor: const Color(0xFFE11D48),
                      onChanged: (val) => setDialogState(() => isWorkingStatus = val),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ləğv et'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2)),
              onPressed: () async {
                final String district = districtController.text.trim();
                final String fullCity = district.isNotEmpty ? '$selectedCityVal, $district' : selectedCityVal;

                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'fullName': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'role': selectedRole,
                  'category': selectedRole == 'usta' ? selectedUstaCategory : '',
                  'city': fullCity,
                  'isWorking': selectedRole == 'usta' ? isWorkingStatus : false,
                  'bio': selectedRole == 'usta' ? bioController.text.trim() : (userData?['bio'] ?? ''),
                }, SetOptions(merge: true));
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Məlumatlar yadda saxlanıldı!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Yadda saxla', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Ustanın Haqqında məlumatını tez dəyişməsi üçün xüsusi dialoq
  void _showEditBioDialog(String uid, String currentBio, String defaultBio) {
    final controller = TextEditingController(text: currentBio.trim().isNotEmpty ? currentBio : defaultBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: Color(0xFF1769D2), size: 26),
            SizedBox(width: 8),
            Text('Haqqımda Məlumatı Dəyiş', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gördüyünüz işlər, təcrübəniz və müştərilərə xidmət şərtləriniz haqqında məlumat yazın:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Məsələn: 10 illik təcrübə, kafel-metlax və santexnika işlərinin keyfiyyətli görülməsi...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1769D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newBio = controller.text.trim();
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'bio': newBio,
                }, SetOptions(merge: true));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Haqqımda məlumatı uğurla yeniləndi!'),
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
            child: const Text('Yadda saxla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = _authService.currentUser;
    final bool isAdmin = _currentUserRole == 'admin';

    // 1. Əgər istifadəçi daxil olmayıbsa (Qonaq rejimindədirsə)
    if (user == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
              child: const Icon(Icons.person_outline, size: 50, color: Color(0xFF1769D2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Qonaq İstifadəçi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usta çağırmaq, sifariş vermək və ya usta/satıcı kimi qeydiyyatdan keçmək üçün hesabınıza daxil olun.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769D2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Daxil Ol / Qeydiyyat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Kömək və Dəstək'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showHelpSupportSheet,
          ),
        ],
      );
    }

    // 2. Əgər istifadəçi daxil olubsa (Canlı Firestore datası ilə)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data();
        final String? photoBase64 = userData?['photoBase64'];
        final String? photoUrl = user.photoURL;
        final String displayName = userData?['fullName'] ?? user.displayName ?? user.email ?? 'İstifadəçi';
        final String userRole = userData?['role'] ?? _currentUserRole ?? 'customer';

        ImageProvider? avatarImage;
        if (photoBase64 != null && photoBase64.isNotEmpty) {
          try {
            avatarImage = MemoryImage(base64Decode(photoBase64));
          } catch (_) {}
        } else if (photoUrl != null && photoUrl.isNotEmpty) {
          avatarImage = NetworkImage(photoUrl);
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, size: 54, color: Color(0xFF1769D2))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _showPhotoPicker(user.uid),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                user.email ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.amber.shade100 : const Color(0xFF1769D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAdmin
                      ? 'Sistem Administratoru'
                      : (userRole == 'seller'
                          ? 'Satıcı (Mağaza Sahibi)'
                          : (userRole == 'usta' ? '${userData?['category'] ?? 'Tikinti'} Ustası' : 'Müştəri')),
                  style: TextStyle(
                    color: isAdmin ? Colors.amber.shade900 : const Color(0xFF1769D2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Əgər Ustadırsa: Canlı İş Statusu (Hal-hazırda işləyir / Sərbəstdir)
            if (userRole == 'usta') ...[
              Container(
                decoration: BoxDecoration(
                  color: (userData?['isWorking'] == true) ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (userData?['isWorking'] == true) ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                    width: 1.5,
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (userData?['isWorking'] == true) ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (userData?['isWorking'] == true) ? Icons.business_center : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    (userData?['isWorking'] == true) ? 'Hal-hazırda işləyirəm (Məşğulam)' : 'Sərbəstəm (İşləmirəm)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: (userData?['isWorking'] == true) ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                    ),
                  ),
                  subtitle: Text(
                    (userData?['isWorking'] == true)
                        ? 'Kateqoriyalarda müştərilər sizin məşğul olduğunuzu görəcəklər'
                        : 'Kateqoriyalarda müştərilər sizin sifariş qəbul etdiyinizi görəcəklər',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: userData?['isWorking'] == true,
                  activeColor: const Color(0xFFE11D48),
                  onChanged: (bool val) async {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'isWorking': val,
                    }, SetOptions(merge: true));
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Yalnız sistem rəhbəri (mirze3838@gmail.com və ya admin rolu olan) üçün Admin Paneli
            if (isAdmin || (user.email != null && user.email!.toLowerCase() == 'mirze3838@gmail.com') || (userData?['role'] == 'admin')) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: ListTile(
                  leading: const Icon(Icons.security, color: Colors.amber, size: 26),
                  title: const Text('Admin İdarəetmə Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Ustaları təsdiqlə və sistemi idarə et'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.amber),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Usta Haqqında (Təcrübə və Xidmət) kartı — istədikdə birbaşa buradan redaktə edə bilər
            if (userRole == 'usta') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.badge_outlined, color: Color(0xFF1769D2), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Usta Haqqında Məlumat',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _showEditBioDialog(
                            user.uid,
                            userData?['bio'] ?? '',
                            'Hörmətli müştərilər, ${(userData?['category'] ?? 'Tikinti')} sahəsində çoxillik təcrübəyə malik peşəkar usta olaraq yüksək keyfiyyətli xidmət təklif edirəm. Bütün işlər zəmanətlə və vaxtında təhvil verilir.',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1769D2).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.edit, size: 14, color: Color(0xFF1769D2)),
                                SizedBox(width: 4),
                                Text(
                                  'Dəyiş',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (userData?['bio'] != null && (userData?['bio'] as String).trim().isNotEmpty)
                          ? userData!['bio']
                          : 'Hörmətli müştərilər, ${(userData?['category'] ?? 'Tikinti')} sahəsində çoxillik təcrübəyə malik peşəkar usta olaraq yüksək keyfiyyətli xidmət təklif edirəm. Bütün işlər zəmanətlə və vaxtında təhvil verilir.',
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // İnstagram tərzi Portfólio / İşlərim bölməsi
            _buildInstagramGallery(user.uid, displayName, userRole),
            const SizedBox(height: 20),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil məlumatlarını redaktə et'),
              subtitle: const Text('Ad, nömrə, ixtisas və haqqında məlumat'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showEditProfileDialog(user.uid, userData),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Mənim Mağazam / Elanlarım'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                setState(() => _currentIndex = 2);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Bildirişlər'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_unreadNotifications > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: _showNotificationsSheet,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Kömək və Dəstək'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showHelpSupportSheet,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıxış et', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                await _authService.signOut();
                if (mounted) {
                  setState(() {
                    _currentUserRole = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hesabdan çıxış edildi.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// Videonun öz içindən (0.7s) kadr çıxararaq kartın üz qabığında göstərən vidcet
class _ShortsVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final Widget fallback;

  const _ShortsVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.fallback,
  });

  @override
  State<_ShortsVideoThumbnail> createState() => _ShortsVideoThumbnailState();
}

class _ShortsVideoThumbnailState extends State<_ShortsVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ShortsVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _initThumbnail();
    }
  }

  Future<void> _initThumbnail() async {
    // Web-də Flutter video_player brauzerin native <video> elementini işlədir —
    // cross-origin video göstərmək üçün CORS tələb olunmur (yalnız piksel oxumaq üçün lazımdır)
    String url = widget.videoUrl.trim();
    if (url.isEmpty) return;

    // Əgər tmpfiles köhnə formatdırsa, birbaşa MP4 stream linkini həll et:
    if (url.contains('tmpfiles.org')) {
      if (!url.contains('/dl/') || url.split('/').length < 7) {
        try {
          final pageUrl = url.replaceFirst('/dl/', '/');
          final res = await http.get(Uri.parse(pageUrl)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final m = RegExp(r'href="([^"]+/dl/[^"]+)"').firstMatch(res.body);
            if (m != null) {
              url = m.group(1)!;
            }
          }
        } catch (_) {}
      }
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;

      // Timeout: web üçün 10s, mobil üçün 15s
      final timeoutDur = kIsWeb ? const Duration(seconds: 10) : const Duration(seconds: 15);
      await controller.initialize().timeout(
        timeoutDur,
        onTimeout: () {
          debugPrint('Thumbnail initialize timeout: $url');
        },
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      if (!controller.value.isInitialized) return;

      await controller.setVolume(0);

      // Videonun ilk kadrını dərhal çəkirik
      final duration = controller.value.duration;
      final seekTarget = duration > const Duration(milliseconds: 300)
          ? const Duration(milliseconds: 300)
          : Duration.zero;

      if (seekTarget > Duration.zero) {
        await controller.seekTo(seekTarget);
      }
      try {
        await controller.play();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.pause();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail extraction error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _isInitialized && _controller != null && _controller!.value.isInitialized;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ready
            ? SizedBox.expand(
                key: const ValueKey('video_ready'),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1080,
                    height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1920,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : SizedBox.expand(
                key: const ValueKey('video_fallback'),
                child: widget.fallback,
              ),
      ),
    );
  }
}

// Hesabdan və qalereyadan videolara birbaşa tam ekran baxış (Shorts bölməsinə keçmədən)
class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String category;
  final String postId;
  final String? coverBase64;
  final bool isOwner;

  const FullScreenVideoViewer({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.category,
    this.postId = '',
    this.coverBase64,
    this.isOwner = true,
  });

  @override
  State<FullScreenVideoViewer> createState() => FullScreenVideoViewerState();
}

class FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _hasError = false;
  bool _isMuted = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  Future<void> _initVideo() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      final timeout = kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 25);
      await controller.initialize().timeout(timeout, onTimeout: () {
        debugPrint('Video timeout: $url');
      });

      if (!mounted) {
        controller.dispose();
        return;
      }

      if (!controller.value.isInitialized) {
        if (mounted) setState(() => _hasError = true);
        return;
      }

      controller.setLooping(true);
      controller.addListener(_videoListener);

      // Web-də brauzerlər səsli autoplay-i bloklayır, ona görə default olaraq muted başlayırıq
      if (kIsWeb) {
        await controller.setVolume(0);
        _isMuted = true;
      } else {
        await controller.setVolume(1.0);
        _isMuted = false;
      }

      await controller.play();

      if (mounted) {
        setState(() {
          _isInit = true;
          _hasError = false;
          _isPlaying = true;
        });
        _startHideControlsTimer();
      }
    } catch (err) {
      debugPrint('Post video error: $err');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !_isInit) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    await c.setVolume(_isMuted ? 0 : 1.0);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _deletePostAndShorts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Videonu Sil'),
        content: const Text('Bu videonu qalereyanızdan və bazadan tamamilə silmək istəyirsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Xeyr')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Bəli, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(widget.postId).delete();
      } catch (_) {}
      try {
        final shQ = await FirebaseFirestore.instance
            .collection('shorts')
            .where('videoUrl', isEqualTo: widget.videoUrl)
            .get();
        for (final d in shQ.docs) {
          await d.reference.delete();
        }
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uğurla silindi.')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) {
            _startHideControlsTimer();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 0. Arxa fonda üz qabığı
            if (widget.coverBase64 != null && widget.coverBase64!.isNotEmpty)
              Center(
                child: Image.memory(
                  base64Decode(widget.coverBase64!),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            // 1. Video (Əsl en-boy nisbəti qorunur, IgnorePointer ilə klikləri udmur)
            if (_isInit && c != null)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 9 / 16,
                  child: IgnorePointer(
                    child: VideoPlayer(c),
                  ),
                ),
              )
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, color: Colors.amber, size: 72),
                      const SizedBox(height: 14),
                      const Text(
                        'Video brauzerdə birbaşa açılmadı',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Videonun faylını xarici pəncərədə bir toxunuşla izləyə bilərsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          if (widget.videoUrl.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(widget.videoUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Videonu Brauzerdə Aç'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1769D2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _isInit = false;
                              });
                              _initVideo();
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Yenidən Cəhd Et'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (widget.isOwner && widget.postId.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: _deletePostAndShorts,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Bu Videonu Sil'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text(
                      'Video yüklənir...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // 2. Mərkəzi böyük Play / Pause düyməsi
            if (_isInit && c != null && (_showControls || !c.value.isPlaying))
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: Icon(
                      c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),

            // 3. Web üçün Səs açma xəbərdarlıq pəncərəsi (Əgər muted-dirsə)
            if (_isInit && _isMuted)
              Positioned(
                top: 70,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.volume_off, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Səsi Aç',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Yuxarı naviqasiya (Geri, Səs və Sil düymələri)
            if (_showControls || _hasError || !_isInit)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Row(
                        children: [
                          if (_isInit && c != null)
                            CircleAvatar(
                              backgroundColor: _isMuted ? Colors.amber.shade800 : Colors.black54,
                              child: IconButton(
                                tooltip: _isMuted ? 'Səsi Aç' : 'Səsi Kapat',
                                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                                onPressed: _toggleMute,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (widget.videoUrl.isNotEmpty)
                            CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                tooltip: 'Brauzerdə Aç',
                                icon: const Icon(Icons.open_in_new, color: Colors.white),
                                onPressed: () async {
                                  final uri = Uri.parse(widget.videoUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ),
                          if (widget.isOwner && widget.postId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                tooltip: 'Videonu Sil',
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: _deletePostAndShorts,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Aşağı idarəetmə paneli və başlıq
            if (_showControls || _hasError || !_isInit)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.92)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Vaxt xətti (Progress slider)
                      if (_isInit && c != null) ...[
                        VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF1769D2),
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(c.value.position),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              _formatDuration(c.value.duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Kateqoriya və Başlıq
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.category.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1769D2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.category,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
