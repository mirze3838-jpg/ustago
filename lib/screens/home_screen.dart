import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
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
import '../widgets/add_post_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  late int _currentIndex;
  String _selectedCity = 'Bakı';
  String? _currentUserRole;
  final TextEditingController _searchController = TextEditingController();
  int _adminSecretTap = 0;
  int _unreadNotifications = 3;
  int _ustaProfileGalleryTab = 0; // 0: Portfolio, 1: Shorts
  bool _isUstaBioExpanded = false;
  late final ShortsScreen _shortsTab;

  // Kateqoriyalar və Şəhərlər (Admin tərəfindən artırıla bilər, Firestore ilə canlı sinxronlaşır)
  List<Map<String, dynamic>> _categories = List.from(CategoryCityService.defaultCategories);
  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<Map<String, dynamic>>>? _catSub;
  StreamSubscription<List<String>>? _citySub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _loadUserRole();
    _initCategoryAndCityStreams();
    _shortsTab = ShortsScreen(
      onNavigateTab: (idx) {
        if (mounted) setState(() => _currentIndex = idx);
      },
      onOpenArtisanProfile: (artisanData) async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtisanDetailScreen(artisanData: artisanData),
          ),
        );
      },
    );
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
    final user = _authService.currentUser;
    bool hasRead = false;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final uData = doc.data();
          if (uData?['notificationsRead'] == true) {
            hasRead = true;
          }
          final String? fullName = uData?['fullName'];
          final String? phone = uData?['phone'];
          final String? category = uData?['category'];
          final String? photoBase64 = uData?['photoBase64'];
          // İstifadəçinin mövcud shorts və postlarını cari adı ilə arxa planda dərhal sinxronlaşdırırıq
          if (fullName != null && fullName.isNotEmpty) {
            _syncUserDataAcrossCollections(
              user.uid,
              newName: fullName,
              newPhone: phone,
              newTrade: category,
              newPhotoBase64: photoBase64,
            );
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _currentUserRole = role;
        if (hasRead) _unreadNotifications = 0;
      });
    }
  }

  /// İstifadəçinin adı, nömrəsi, fotosu və ya ixtisası dəyişdikdə bütün Shorts və Post bazasını sinxronlaşdırır
  Future<void> _syncUserDataAcrossCollections(
    String uid, {
    String? newName,
    String? newPhone,
    String? newTrade,
    String? newPhotoBase64,
  }) async {
    if (uid.isEmpty || uid == 'guest') return;
    try {
      // 1. Shorts kolleksiyasında istifadəçinin videolarını tap və yenilə
      final shortsSnap = await FirebaseFirestore.instance
          .collection('shorts')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in shortsSnap.docs) {
        final Map<String, dynamic> updates = {};

        if (newName != null && newName.trim().isNotEmpty) {
          updates['artisanName'] = newName.trim();
        }
        if (newPhone != null && newPhone.trim().isNotEmpty) {
          updates['phone'] = newPhone.trim();
        }
        if (newTrade != null && newTrade.trim().isNotEmpty) {
          updates['trade'] = newTrade.trim();
        }
        if (newPhotoBase64 != null) {
          updates['authorPhotoBase64'] = newPhotoBase64;
        }

        if (updates.isNotEmpty) {
          await doc.reference.set(updates, SetOptions(merge: true));
        }
      }

      // 2. Posts (portfolio) kolleksiyasında istifadəçinin postlarını tap və yenilə
      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in postsSnap.docs) {
        final Map<String, dynamic> updates = {};

        if (newName != null && newName.trim().isNotEmpty) {
          updates['authorName'] = newName.trim();
          updates['artisanName'] = newName.trim();
        }
        if (newPhone != null && newPhone.trim().isNotEmpty) {
          updates['phone'] = newPhone.trim();
        }
        if (newTrade != null && newTrade.trim().isNotEmpty) {
          updates['category'] = newTrade.trim();
        }

        if (updates.isNotEmpty) {
          await doc.reference.set(updates, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('Sync user data across collections error: $e');
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
        return _shortsTab;
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
                    'userId': data['userId'] ?? '',
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
    if (_unreadNotifications > 0) {
      setState(() {
        _unreadNotifications = 0;
      });
      final user = _authService.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'notificationsRead': true,
        }, SetOptions(merge: true));
      }
    }
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

  // DİNAMİK VƏ İŞIQLI SHORTS FALLBACK KARTI (Qaranlıq görünmür, dərhal parlaq və estetik açılır)
  Widget _buildShortsFallbackVisual({String? title, String? trade, String? artisanName}) {
    final tr = (trade ?? '').toLowerCase();
    List<Color> gradientColors;
    IconData tradeIcon;

    if (tr.contains('santexnik') || tr.contains('su')) {
      gradientColors = const [Color(0xFF0284C7), Color(0xFF0369A1)];
      tradeIcon = Icons.water_drop_rounded;
    } else if (tr.contains('elektrik') || tr.contains('işıq')) {
      gradientColors = const [Color(0xFFD97706), Color(0xFFB45309)];
      tradeIcon = Icons.bolt_rounded;
    } else if (tr.contains('tikinti') || tr.contains('hörgü') || tr.contains('bina')) {
      gradientColors = const [Color(0xFFEA580C), Color(0xFFC2410C)];
      tradeIcon = Icons.foundation_rounded;
    } else if (tr.contains('mebel') || tr.contains('dülgər')) {
      gradientColors = const [Color(0xFF92400E), Color(0xFF78350F)];
      tradeIcon = Icons.chair_rounded;
    } else if (tr.contains('rəngsaz') || tr.contains('boya')) {
      gradientColors = const [Color(0xFFDB2777), Color(0xFFBE185D)];
      tradeIcon = Icons.format_paint_rounded;
    } else if (tr.contains('kondisioner') || tr.contains('soyuducu')) {
      gradientColors = const [Color(0xFF0891B2), Color(0xFF0E7490)];
      tradeIcon = Icons.ac_unit_rounded;
    } else {
      gradientColors = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
      tradeIcon = Icons.handyman_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dekorativ parlaq işıq elementləri
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tradeIcon, color: Colors.white, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    trade ?? 'Shorts',
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DİNAMİK YÜKLƏNƏN SHORTS KARTI (Videonun başlıq şəkli ilə, qaranlıq görünmür)
  Widget _buildDynamicShortsCard(Map<String, dynamic> item, int index) {
    final String? thumbnailBase64 = item['thumbnailBase64'];
    final String? thumbnailUrl = item['thumbnailUrl'];
    final String trade = (item['trade'] ?? 'Tikinti').toString();
    final String artisanName = (item['artisanName'] ?? 'Usta').toString();
    final String title = (item['title'] ?? '').toString();

    // Video kadrı çıxarılana qədər parlaq və işıqlı fallback
    final Widget fallbackVisual = _buildShortsFallbackVisual(
      title: title,
      trade: trade,
      artisanName: artisanName,
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
      onTap: () async {
        final targetIndex = await Navigator.push<int>(
          context,
          MaterialPageRoute(
            builder: (_) => ShortsScreen(
              initialIndex: index,
              onNavigateTab: (idx) {
                Navigator.pop(context, idx);
              },
              onOpenArtisanProfile: (artisanData) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtisanDetailScreen(artisanData: artisanData),
                  ),
                );
              },
            ),
          ),
        );
        if (targetIndex != null && mounted) {
          setState(() => _currentIndex = targetIndex);
        }
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

                    // 5. Aşağıda Müəllif adı (Real-vaxtda istifadəçi bazasından oxunur və dərhal sinxronlaşır)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _AuthorNameText(
                        userId: (item['userId'] ?? '').toString(),
                        defaultName: (item['author'] ?? 'Usta').toString(),
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
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

  // Yeni İş / Şəkil və ya Shorts Video Paylaşmaq dialoqu (Yeni dizayn və sistemə 1:1 uyğun)
  Future<void> _showAddPostDialog(String uid, String authorName, String role, {int initialTab = 0, bool lockTab = false}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPostBottomSheet(
        uid: uid,
        authorName: authorName,
        role: role,
        categories: _categories,
        compressCoverImage: _compressCoverImage,
        initialTab: initialTab,
        lockTab: lockTab,
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
                                fallback: _buildShortsFallbackVisual(
                                  title: (data['title'] ?? '').toString(),
                                  trade: (data['category'] ?? data['trade'] ?? 'Usta İşi').toString(),
                                  artisanName: (data['authorName'] ?? '').toString(),
                                ),
                              );
                            }
                            return _buildShortsFallbackVisual(
                              title: (data['title'] ?? '').toString(),
                              trade: (data['category'] ?? data['trade'] ?? 'Usta İşi').toString(),
                              artisanName: (data['authorName'] ?? '').toString(),
                            );
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
                  _syncUserDataAcrossCollections(uid, newPhotoBase64: '');
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

        _syncUserDataAcrossCollections(uid, newPhotoBase64: base64String);

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
                final updatedName = nameController.text.trim();
                final updatedPhone = phoneController.text.trim();
                final updatedTrade = selectedRole == 'usta' ? selectedUstaCategory : '';

                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'fullName': updatedName,
                  'phone': updatedPhone,
                  'role': selectedRole,
                  'category': updatedTrade,
                  'city': fullCity,
                  'isWorking': selectedRole == 'usta' ? isWorkingStatus : false,
                  'bio': selectedRole == 'usta' ? bioController.text.trim() : (userData?['bio'] ?? ''),
                }, SetOptions(merge: true));

                // İstifadəçinin mövcud bütün Shorts videolarını və postlarını yeni ad və nömrə ilə sinxronlaşdır
                await _syncUserDataAcrossCollections(
                  uid,
                  newName: updatedName,
                  newPhone: updatedPhone,
                  newTrade: updatedTrade,
                );
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

        // Usta rolundakı istifadəçilər üçün yeni premium dizayn (Təqdim olunmuş dizayna tam uyğun)
        if (userRole == 'usta') {
          return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);
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

  /// Yeni Premium Usta Profil Səhifəsi (Təqdim olunmuş dizayn şəklinə 1:1 uyğun)
  Widget _buildModernUstaProfile(
    User user,
    Map<String, dynamic>? userData,
    bool isAdmin,
    ImageProvider? avatarImage,
    String displayName,
    String userRole,
  ) {
    final String phone = (userData?['phone'] ?? user.phoneNumber ?? '+994 50 123 45 67').toString();
    final String category = (userData?['category'] ?? userData?['trade'] ?? 'Tikinti və Təmir').toString();
    final String rating = (userData?['rating'] != null) ? userData!['rating'].toString() : '4.9';
    final String reviewCount = (userData?['reviewCount'] != null) ? userData!['reviewCount'].toString() : '324';
    final bool isWorking = userData?['isWorking'] == true;
    final String bio = (userData?['bio'] != null && (userData!['bio'] as String).trim().isNotEmpty)
        ? userData!['bio'] as String
        : 'Keyfiyyətli və peşəkar təmir xidməti. Təcrübə: 10+ il. Hər növ tikinti və təmir işləri.';
    final String? coverBase64 = userData?['coverBase64'] as String?;
    final String? coverUrl = userData?['coverUrl'] as String?;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Profilin Yuxarı Hissəsi: Geniş Cover Şəkli + Dalğalı Keçid + Ortada Dairəvi Avatar
          SizedBox(
            height: 255,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dalğalı Örtük Şəkli (Cover Photo with Curved Wave Bottom)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 205,
                  child: ClipPath(
                    clipper: _CoverWaveClipper(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(
                          builder: (context) {
                            if (coverBase64 != null && coverBase64.isNotEmpty) {
                              try {
                                return Image.memory(base64Decode(coverBase64), fit: BoxFit.cover);
                              } catch (_) {}
                            }
                            if (coverUrl != null && coverUrl.isNotEmpty) {
                              return Image.network(coverUrl, fit: BoxFit.cover);
                            }
                            // Dizayn şəklinə uyğun müasir tikinti və villa örtük şəkli
                            return Image.network(
                              'https://images.unsplash.com/photo-1541888946425-d0fbb18f15f7?q=80&w=1200&auto=format&fit=crop',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF1769D2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.home_repair_service_rounded, size: 64, color: Colors.white24),
                                ),
                              ),
                            );
                          },
                        ),
                        // Şəkil üzərində zərif qaralma örtüyü (düymələrin aydın görünməsi üçün)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Yuxarı Düymələr: Geri Qayıt (<), Paylaş və Ətraflı (...)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Geri düyməsi
                      InkWell(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            setState(() => _currentIndex = 0);
                          }
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      // Sağ düymələr: Paylaş və Ətraflı Seçimlər
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: phone));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$displayName profil məlumatları kopyalandı!'),
                                  backgroundColor: const Color(0xFF1769D2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showEditProfileDialog(user.uid, userData),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ortada Dairəvi Profil Fotosu (Ağ haşiyəli və Təsdiqlənmiş Mavi Nişanlı)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _showPhotoPicker(user.uid),
                            borderRadius: BorderRadius.circular(54),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? const Icon(Icons.person, size: 52, color: Color(0xFF1769D2))
                                  : null,
                            ),
                          ),
                        ),
                        // Avatarın sağ aşağı küncündə mavi təsdiq nişanı
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1769D2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Ustanın Adı və Mavi Təsdiq Nişanı
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Color(0xFF1769D2), size: 20),
            ],
          ),
          const SizedBox(height: 3),

          // Peşə və Fəaliyyət Sahəsi
          Center(
            child: Text(
              'Usta • $category',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Reytinq və Təsdiqlənmiş Usta Göstəricisi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 4),
              Text(
                rating,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($reviewCount rəy)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                height: 14,
                width: 1,
                color: const Color(0xFFCBD5E1),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              const Icon(Icons.verified_user_rounded, color: Color(0xFF1769D2), size: 17),
              const SizedBox(width: 5),
              const Text(
                'Təsdiqlənmiş usta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Əlaqə Kartı (Telefon Nömrəsi, Status, Zəng et və Mesaj yaz düymələri)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Telefon nömrəsi və Online/Oflayn statusu
                InkWell(
                  onTap: () => _makeCall(phone),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              phone.isNotEmpty ? phone : '+994 50 123 45 67',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () async {
                                final newStatus = !isWorking;
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'isWorking': newStatus,
                                }, SetOptions(merge: true));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(newStatus
                                          ? 'Status "Hal-hazırda məşğulam" olaraq dəyişdirildi!'
                                          : 'Status "Online (Sərbəstəm)" olaraq dəyişdirildi!'),
                                      backgroundColor: newStatus ? Colors.orange : Colors.green,
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isWorking ? 'Məşğul ' : 'Online ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(Dəyiş)',
                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2), size: 26),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Zəng et və Mesaj yaz düymələri
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makeCall(phone),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: const Text('Zəng et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1769D2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(phone),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF1769D2)),
                        label: const Text('Mesaj yaz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1769D2))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: const Color(0xFF1769D2),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Usta Haqqında Kartı
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF1769D2), size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Usta Haqqında',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isUstaBioExpanded = !_isUstaBioExpanded;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isUstaBioExpanded ? 'Daha az' : 'Daha çox',
                            style: const TextStyle(
                              color: Color(0xFF1769D2),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            _isUstaBioExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF1769D2),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showEditBioDialog(
                        user.uid,
                        userData?['bio'] ?? '',
                        'Keyfiyyətli və peşəkar təmir xidməti. Təcrübə: 10+ il. Hər növ tikinti və təmir işləri.',
                      ),
                      child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  bio,
                  maxLines: _isUstaBioExpanded ? null : 2,
                  overflow: _isUstaBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                // Xidmət sahələri (Tags / Chips)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildServiceChips(category, userData),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 5. Portfolio və Shorts Bölməsi (İki Ayrı Seçim: "Gördüyüm İşlər" & "Videolarım")
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Tab 0: Gördüyüm İşlər (Portfolio)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _ustaProfileGalleryTab = 0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _ustaProfileGalleryTab == 0 ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _ustaProfileGalleryTab == 0
                            ? Border.all(color: const Color(0xFFBFDBFE), width: 1.2)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 20,
                            color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Gördüyüm İşlər\n(Portfolio)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _ustaProfileGalleryTab == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Tab 1: Videolarım (Shorts)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _ustaProfileGalleryTab == 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _ustaProfileGalleryTab == 1
                            ? Border.all(color: const Color(0xFFBFDBFE), width: 1.2)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: _ustaProfileGalleryTab == 1 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Videolarım\n(Shorts)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _ustaProfileGalleryTab == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _ustaProfileGalleryTab == 1 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Seçilmiş Tab-a Uyğun 3 Sütunlu Grid Kontenti
          if (_ustaProfileGalleryTab == 0)
            _buildUstaPortfolioGrid(user.uid, displayName, userRole)
          else
            _buildUstaShortsGrid(user.uid, displayName, userRole),

          const SizedBox(height: 14),

          // Admin İdarəetmə Paneli (Əgər sistem administratorudursa)
          if (isAdmin || (user.email != null && user.email!.toLowerCase() == 'mirze3838@gmail.com') || (userData?['role'] == 'admin')) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 12),
          ],

          // 6. Aşağı Menyu (Mağazam / Elanlarım, Bildirişlər, Dəstək, Çıxış et)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Mağazam / Elanlarım
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_outlined, color: Color(0xFF1769D2), size: 20),
                  ),
                  title: const Text('Mağazam / Elanlarım', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2), size: 24),
                  onTap: () {
                    setState(() => _currentIndex = 2);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),

                // Bildirişlər
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1769D2), size: 20),
                  ),
                  title: const Text('Bildirişlər', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_unreadNotifications',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2), size: 24),
                    ],
                  ),
                  onTap: _showNotificationsSheet,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),

                // Dəstək
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.headset_mic_outlined, color: Color(0xFF1769D2), size: 20),
                  ),
                  title: const Text('Dəstək', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2), size: 24),
                  onTap: _showHelpSupportSheet,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Çıxış et Kartı (Yumşaq qırmızı zəminli)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE4E6)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text(
                'Çıxış et',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Çıxış təsdiqi'),
                    content: const Text('Hesabınızdan çıxmaq istədiyinizə əminsiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Bəli, çıx', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _authService.signOut();
                  if (mounted) {
                    setState(() => _currentUserRole = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hesabdan çıxış edildi.')),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Ustanın ixtisasına uyğun peşəkar xidmət teqləri (şəkildəki kimi zərif mavi həb formalı)
  List<Widget> _buildServiceChips(String category, Map<String, dynamic>? userData) {
    List<Map<String, dynamic>> skills;
    final catLower = category.toLowerCase();

    if (catLower.contains('santexnik')) {
      skills = [
        {'name': 'Santexnika', 'icon': Icons.plumbing_rounded},
        {'name': 'Kombi / Radiator', 'icon': Icons.hvac_rounded},
        {'name': 'Borular', 'icon': Icons.water_drop_rounded},
        {'name': 'Quraşdırma', 'icon': Icons.build_rounded},
      ];
    } else if (catLower.contains('elektrik')) {
      skills = [
        {'name': 'Elektrik', 'icon': Icons.bolt_rounded},
        {'name': 'Şit yığılması', 'icon': Icons.electrical_services_rounded},
        {'name': 'Çilçıraq', 'icon': Icons.lightbulb_rounded},
        {'name': 'Xətt çəkilişi', 'icon': Icons.cable_rounded},
      ];
    } else if (catLower.contains('malyar') || catLower.contains('rəng')) {
      skills = [
        {'name': 'Rəngləmə', 'icon': Icons.format_paint_rounded},
        {'name': 'Şpatlyovka', 'icon': Icons.brush_rounded},
        {'name': 'Divar kağızı', 'icon': Icons.wallpaper_rounded},
        {'name': 'Dekor', 'icon': Icons.auto_awesome_rounded},
      ];
    } else {
      // Şəkildəki nümunə: Tikinti, Təmir, Rəngləmə, Dizayn
      skills = [
        {'name': 'Tikinti', 'icon': Icons.home_repair_service_rounded},
        {'name': 'Təmir', 'icon': Icons.build_rounded},
        {'name': 'Rəngləmə', 'icon': Icons.format_paint_rounded},
        {'name': 'Dizayn', 'icon': Icons.dashboard_customize_rounded},
      ];
    }

    return skills.map((s) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s['icon'] as IconData, size: 14, color: const Color(0xFF1769D2)),
            const SizedBox(width: 5),
            Text(
              s['name'] as String,
              style: const TextStyle(
                color: Color(0xFF1769D2),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Gördüyüm İşlər (Portfolio) — 3 sütunlu fotoşəkillər şəbəkəsi (yeni dizayn)
  Widget _buildUstaPortfolioGrid(String uid, String authorName, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        // Yalnız həqiqi FOTO paylaşımlarını seçirik (video olmayan və şəkil olan)
        final photoDocs = docs.where((d) {
          final data = d.data();
          final bool isVid = data['isVideo'] == true ||
              (data['videoUrl'] != null && data['videoUrl'].toString().trim().isNotEmpty);
          if (isVid) return false;
          final hasImg = (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty) ||
              (data['imagesBase64'] != null && (data['imagesBase64'] as List).isNotEmpty) ||
              (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().isNotEmpty);
          return hasImg;
        }).toList();

        if (photoDocs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, size: 30, color: Color(0xFF1769D2)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Portfolio boşdur',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'İş fotoşəkillərini əlavə edərək müştərilərə işini göstər.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                    label: const Text('İlk İşini Paylaş', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddPostDialog(uid, authorName, role, initialTab: 0, lockTab: true),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlıq + düymə
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${photoDocs.length} iş şəkli',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _showAddPostDialog(uid, authorName, role, initialTab: 0, lockTab: true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1769D2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Əlavə Et',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: photoDocs.length,
                itemBuilder: (context, index) {
                  final doc = photoDocs[index];
                  final data = doc.data();
                  String? base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
                  if ((base64Img == null || base64Img.isEmpty) && data['imagesBase64'] is List && (data['imagesBase64'] as List).isNotEmpty) {
                    base64Img = (data['imagesBase64'] as List).first.toString();
                  }

                  // Şəkil varsa tap işləsin, yoxsa heç nə etməsin
                  final bool hasImage = (base64Img != null && base64Img.isNotEmpty) ||
                      (data['thumbnailUrl']?.toString().isNotEmpty == true &&
                          !data['thumbnailUrl'].toString().contains('unsplash.com'));

                  return GestureDetector(
                    onTap: hasImage ? () => _showPostDetailModal(doc.id, data) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Builder(
                          builder: (context) {
                            if (base64Img != null && base64Img.isNotEmpty) {
                              try {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(base64Decode(base64Img), fit: BoxFit.cover),
                                    // Üzərindən yüngül kölgə
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } catch (_) {}
                            }
                            final thumbUrl = data['thumbnailUrl']?.toString();
                            if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(thumbUrl, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            // Şəkil yoxdur → boş placeholder (klikə reaksiya vermiri)
                            return Container(
                              color: const Color(0xFFF1F5F9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 28),
                                  SizedBox(height: 4),
                                  Text('Şəkil yoxdur', style: TextStyle(fontSize: 9, color: Color(0xFFCBD5E1))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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

  /// Videolarım (Shorts) — 3 sütunlu videolar şəbəkəsi
  Widget _buildUstaShortsGrid(String uid, String authorName, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shorts')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.video_collection_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                const Text(
                  'Hələlik heç bir Shorts video yoxdur',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Qısa videolarınızı yükləyərək iş prosesinizi canlı göstərin və müştəriləri cəlb edin!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.video_call_rounded, color: Colors.white, size: 18),
                  label: const Text('İlk Videonu Paylaş', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddPostDialog(uid, authorName, role, initialTab: 1, lockTab: true),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${docs.length} Shorts video',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  InkWell(
                    onTap: () => _showAddPostDialog(uid, authorName, role, initialTab: 1, lockTab: true),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.video_call_rounded, size: 18, color: Color(0xFF1769D2)),
                          SizedBox(width: 4),
                          Text(
                            'Video Əlavə Et',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final videoUrl = (data['videoUrl'] ?? '').toString();
                  final coverBase64 = data['thumbnailBase64']?.toString();

                  return InkWell(
                    onTap: () {
                      if (videoUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenVideoViewer(
                              videoUrl: videoUrl,
                              title: data['title'] ?? 'Usta İşi',
                              category: data['trade'] ?? 'Shorts',
                              postId: doc.id,
                              coverBase64: coverBase64,
                              isOwner: true,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (coverBase64 != null && coverBase64.isNotEmpty)
                              Image.memory(base64Decode(coverBase64), fit: BoxFit.cover)
                            else if (videoUrl.isNotEmpty)
                              _ShortsVideoThumbnail(
                                key: ValueKey('short_thumb_${doc.id}'),
                                videoUrl: videoUrl,
                                fallback: _buildShortsFallbackVisual(
                                  title: (data['title'] ?? 'Shorts').toString(),
                                  trade: (data['trade'] ?? 'Usta İşi').toString(),
                                  artisanName: (data['artisanName'] ?? '').toString(),
                                ),
                              )
                            else
                              _buildShortsFallbackVisual(
                                title: (data['title'] ?? 'Shorts').toString(),
                                trade: (data['trade'] ?? 'Usta İşi').toString(),
                                artisanName: (data['artisanName'] ?? '').toString(),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                            const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              right: 6,
                              child: Text(
                                (data['title'] ?? 'Shorts').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

/// Profil örtük şəklinin alt hissəsini müasir dalğalı formada kəsən Clipper
class _CoverWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    final p1 = Offset(size.width * 0.25, size.height - 10);
    final p2 = Offset(size.width * 0.5, size.height - 35);
    path.quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    final p3 = Offset(size.width * 0.75, size.height - 60);
    final p4 = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(p3.dx, p3.dy, p4.dx, p4.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


/// Mobildə RAM və GPU Video Decoder limitini qoruyan Növbə sistemi
class _ThumbnailQueue {
  static int _running = 0;
  static const int _maxConcurrent = 1; // Eyni anda yalnız 1 video üçün kadr çıxarılır
  static final List<Completer<void>> _queue = [];

  static Future<void> acquire() async {
    if (_running < _maxConcurrent) {
      _running++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  static void release() {
    _running--;
    if (_queue.isNotEmpty) {
      _running++;
      final next = _queue.removeAt(0);
      next.complete();
    }
  }
}

/// Videonun öz içindən kadr çıxararaq kartın üz qabığında göstərən vidcet
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
    String url = widget.videoUrl.trim();
    if (url.isEmpty) return;

    // Əgər tmpfiles köhnə formatdırsa, birbaşa MP4 stream linkini həll et:
    if (url.contains('tmpfiles.org')) {
      if (!url.contains('/dl/') || url.split('/').length < 7) {
        try {
          final pageUrl = url.replaceFirst('/dl/', '/');
          final res = await http.get(Uri.parse(pageUrl)).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200) {
            final m = RegExp(r'href="([^"]+/dl/[^"]+)"').firstMatch(res.body);
            if (m != null) {
              url = m.group(1)!;
            }
          }
        } catch (_) {}
      }
    }

    // Telefonun donmaması üçün növbəni gözləyirik
    await _ThumbnailQueue.acquire();

    try {
      if (!mounted) return;

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;

      // Timeout: 6 saniyə (donub ilişib qalmasın)
      await controller.initialize().timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          debugPrint('Thumbnail timeout: $url');
        },
      );

      if (!mounted) {
        controller.dispose();
        _controller = null;
        return;
      }

      if (!controller.value.isInitialized) {
        controller.dispose();
        _controller = null;
        return;
      }

      await controller.setVolume(0);

      // İlk kadrı sabitləyirik
      final duration = controller.value.duration;
      final seekTarget = duration > const Duration(milliseconds: 200)
          ? const Duration(milliseconds: 200)
          : Duration.zero;

      if (seekTarget > Duration.zero) {
        await controller.seekTo(seekTarget);
      }
      try {
        await controller.play();
        await Future.delayed(const Duration(milliseconds: 40));
        await controller.pause();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Thumbnail extraction error: $e');
    } finally {
      // Növbədəki növbəti videoya icazə veririk
      _ThumbnailQueue.release();
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
        duration: const Duration(milliseconds: 250),
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
                  // rotationCorrection 90/270° olduqda aspectRatio swap edilir (portrait düzəlişi)
                  aspectRatio: () {
                    final raw = c.value.aspectRatio > 0 ? c.value.aspectRatio : 9.0 / 16.0;
                    final rot = c.value.rotationCorrection;
                    return (rot == 90 || rot == 270) ? 1.0 / raw : raw;
                  }(),
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

/// Shorts kartlarında müəllifin adını birbaşa 'users' sənədindən canlı dinləyən vidcet
/// Beləliklə profil adı dəyişən kimi ana səhifədə də dərhal (0.01s) canlı yenilənir
class _AuthorNameText extends StatelessWidget {
  final String userId;
  final String defaultName;
  final TextStyle? style;

  const _AuthorNameText({
    super.key,
    required this.userId,
    required this.defaultName,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty || userId == 'guest') {
      return Text(
        defaultName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final liveName = snapshot.data?.data()?['fullName']?.toString().trim();
        final name = (liveName != null && liveName.isNotEmpty) ? liveName : defaultName;
        return Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

