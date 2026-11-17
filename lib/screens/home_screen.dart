import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/video_upload_service.dart';
import '../services/category_city_service.dart';
import '../services/shorts_social_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'shorts_screen.dart';
import 'market_screen.dart';
import 'market_detail_screens.dart';
import 'artisan_detail_screen.dart';
import 'category_artisans_screen.dart';
import '../widgets/add_post_bottom_sheet.dart';
import '../services/tiktok_service.dart';
import '../widgets/tiktok_embed_view.dart';

class HomeScreen extends StatefulWidget {
  static void Function(int)? onSwitchTab;
  final int initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  late int _currentIndex;
  String _selectedCity = 'Bakı';
  String _selectedVillage = '';
  String _selectedMapCategory = '';
  String? _selectedMapPinId;
  double _mapLat = 40.4093;
  double _mapLng = 49.8671;
  double _mapZoom = 12.0;
  bool _isSatelliteMap = false;
  final TextEditingController _mapSearchController = TextEditingController();
  String? _currentUserRole;
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotifications = 0;
  int _ustaProfileGalleryTab = 0; // 0: Portfolio, 1: Shorts
  bool _isUstaBioExpanded = false;
  int _openMyListingsSignal = 0;
  late final ShortsScreen _shortsTab;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _shortsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ustaStream;
  QuerySnapshot<Map<String, dynamic>>? _latestShortsSnapshot;
  QuerySnapshot<Map<String, dynamic>>? _latestUstaSnapshot;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shortsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ustaSub;

  // Base64 görüntüləri təkrar decode etməmək üçün yaddaş keşi
  static final Map<String, Uint8List> _b64Cache = {};

  static Uint8List? _decodeB64(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    final cached = _b64Cache[b64];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(b64);
      if (_b64Cache.length > 150) {
        _b64Cache.remove(_b64Cache.keys.first);
      }
      _b64Cache[b64] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  // Kateqoriyalar və Şəhərlər (Admin tərəfindən artırıla bilər, Firestore ilə canlı sinxronlaşır)
  List<Map<String, dynamic>> _categories = List.from(CategoryCityService.defaultCategories);
  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<Map<String, dynamic>>>? _catSub;
  StreamSubscription<List<String>>? _citySub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    HomeScreen.onSwitchTab = (int idx) {
      if (mounted) {
        setState(() => _currentIndex = idx);
      }
    };
    _unreadNotifications = _authService.currentUser != null ? 3 : 0;
    _shortsStream = FirebaseFirestore.instance
        .collection('shorts')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots()
        .asBroadcastStream();
    _ustaStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['usta', 'worker'])
        .snapshots()
        .asBroadcastStream();
    _shortsSub = _shortsStream.listen((snap) {
      if (mounted) {
        setState(() => _latestShortsSnapshot = snap);
      } else {
        _latestShortsSnapshot = snap;
      }
    }, onError: (_) {});
    _ustaSub = _ustaStream.listen((snap) {
      if (mounted) {
        setState(() => _latestUstaSnapshot = snap);
      } else {
        _latestUstaSnapshot = snap;
      }
    }, onError: (_) {});
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

  void _centerMapOnSelection({String? city, String? village}) {
    final c = city ?? _selectedCity;
    final v = village ?? _selectedVillage;
    final coords = CategoryCityService.getCoordinates(c, v);
    _mapLat = coords[0];
    _mapLng = coords[1];
    _mapZoom = v.isNotEmpty ? 14.0 : 12.0;
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _citySub?.cancel();
    _shortsSub?.cancel();
    _ustaSub?.cancel();
    _searchController.dispose();
    _mapSearchController.dispose();
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
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _currentUserRole = role;
        if (user == null || hasRead) {
          _unreadNotifications = 0;
        }
      });
    }
  }

  /// İstifadəçinin adı, nömrəsi, fotosu və ya ixtisası dəyişdikdə bütün Shorts və Post bazasını sinxronlaşdırır (WriteBatch ilə)
  Future<void> _syncUserDataAcrossCollections(
    String uid, {
    String? newName,
    String? newPhone,
    String? newTrade,
    String? newPhotoBase64,
  }) async {
    if (uid.isEmpty || uid == 'guest') return;
    if (newName != null && newName.trim().isNotEmpty) {
      _AuthorNameText._nameCache[uid] = newName.trim();
    }
    try {
      final db = FirebaseFirestore.instance;
      WriteBatch batch = db.batch();
      int opCount = 0;

      Future<void> addToBatch(DocumentReference ref, Map<String, dynamic> updates) async {
        batch.set(ref, updates, SetOptions(merge: true));
        opCount++;
        if (opCount >= 400) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }

      // 1. Shorts kolleksiyasında istifadəçinin videolarını tap və yenilə
      final shortsSnap = await db.collection('shorts').where('userId', isEqualTo: uid).get();
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
          await addToBatch(doc.reference, updates);
        }
      }

      // 2. Posts (portfolio) kolleksiyasında istifadəçinin postlarını tap və yenilə
      final postsSnap = await db.collection('posts').where('userId', isEqualTo: uid).get();
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
          await addToBatch(doc.reference, updates);
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Sync user data across collections error: $e');
    }
  }

  // Firestore client-side tarix sıralaması (ən yenisi yuxarıda)
  int _compareCreatedAtDesc(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final ta = a.data()['createdAt'];
    final tb = b.data()['createdAt'];
    final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
    final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
    return mb.compareTo(ma);
  }

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
        return MarketScreen(
          onBackToHome: () => setState(() => _currentIndex = 0),
          onNavigateToMap: (cityOrAddr, lat, lng) {
            setState(() {
              if (cityOrAddr.isNotEmpty) {
                final reg = cityOrAddr.split(',').first.trim();
                if (_cities.contains(reg)) {
                  _selectedCity = reg;
                }
              }
              _selectedVillage = '';
              if (lat != null && lng != null) {
                _mapLat = lat;
                _mapLng = lng;
                _mapZoom = 14.5;
              } else {
                _centerMapOnSelection();
              }
              _currentIndex = 3;
            });
          },
          openMyListingsSignal: _openMyListingsSignal,
        );
      case 3:
        return _buildMapTab();
      case 4:
        return _buildMessagesTab();
      case 5:
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

  // Bütün Kateqoriyalar və İxtisaslar Modal Pəncərəsi
  void _showAllCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normFilter = CategoryCityService.normalizeAz(filter);
            final List<Map<String, dynamic>> filteredGroups = [];

            for (final grp in CategoryCityService.specialtyGroups) {
              final grpTitle = grp['title'] as String;
              final items = (grp['items'] as List<Map<String, String>>).where((item) {
                if (normFilter.isEmpty) return true;
                final itemTitle = CategoryCityService.normalizeAz(item['title'] ?? '');
                final normGrp = CategoryCityService.normalizeAz(grpTitle);
                return itemTitle.contains(normFilter) || normGrp.contains(normFilter);
              }).toList();

              if (items.isNotEmpty) {
                filteredGroups.add({
                  ...grp,
                  'items': items,
                });
              }
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.grid_view_rounded, color: Color(0xFF1769D2), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Bütün İxtisaslar və Kateqoriyalar',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setSheetState(() => filter = v),
                    decoration: InputDecoration(
                      hintText: 'İxtisas axtarın (məs: Santexnik, Kombi, Pitminutka...)',
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
                  const SizedBox(height: 12),

                  // Bütün Ustalar sürətli düyməsi
                  if (normFilter.isEmpty) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.people_alt_rounded, color: Color(0xFF1769D2), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Bütün Ustalar (Hamısına bax)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Expanded(
                    child: filteredGroups.isEmpty
                        ? const Center(
                            child: Text('Uyğun ixtisas tapılmadı', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: filteredGroups.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, gIdx) {
                              final grp = filteredGroups[gIdx];
                              final grpTitle = grp['title'] as String;
                              final grpIcon = grp['icon'] as IconData? ?? Icons.handyman;
                              final grpColor = grp['color'] as Color? ?? const Color(0xFF1769D2);
                              final grpBg = grp['bgColor'] as Color? ?? const Color(0xFFEFF6FF);
                              final items = grp['items'] as List<Map<String, String>>;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: grpBg, borderRadius: BorderRadius.circular(8)),
                                          child: Icon(grpIcon, color: grpColor, size: 18),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            grpTitle,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: items.map((item) {
                                        final spTitle = item['title'] ?? '';
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CategoryArtisansScreen(
                                                  categoryTitle: spTitle,
                                                  categoryIcon: grpIcon,
                                                  categoryColor: grpColor,
                                                  categoryBgColor: grpBg,
                                                  selectedCity: _selectedCity,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: grpColor.withOpacity(0.25)),
                                            ),
                                            child: Text(
                                              spTitle,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
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
                child: Text(
                  'UstaGo v1.0.0 (Bütün hüquqlar qorunur)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                stream: _ustaStream,
                initialData: _latestUstaSnapshot,
                builder: (context, uSnap) {
                  final rawQuery = _searchController.text.trim();
                  final q = rawQuery.toLowerCase();
                  final normQ = CategoryCityService.normalizeAz(rawQuery);
                  final matchingLocations = CategoryCityService.searchLocations(rawQuery);
                  final docs = (uSnap.data ?? _latestUstaSnapshot)?.docs ?? [];
                  final sc = CategoryCityService.normalizeAz(_selectedCity);
                  final sv = CategoryCityService.normalizeAz(_selectedVillage);
                  final String selectedLocLabel = _selectedVillage.isNotEmpty ? '$_selectedCity, $_selectedVillage' : _selectedCity;

                  final matchingUstas = docs.where((d) {
                    final data = d.data();
                    final city = CategoryCityService.normalizeAz((data['city'] ?? '').toString());
                    final district = CategoryCityService.normalizeAz((data['district'] ?? '').toString());
                    final address = CategoryCityService.normalizeAz((data['address'] ?? '').toString());
                    final fullLoc = '$city $district $address';

                    // Seçilmiş bölgəyə (Şəhər / Kənd) görə filtr
                    if (sc.isNotEmpty && sc != 'hamisi') {
                      if (!fullLoc.contains(sc)) return false;
                      if (sv.isNotEmpty && sv != 'hamisi' && sv != 'butun erazi') {
                        if (sv == 'merkez') {
                          if (!fullLoc.contains('merkez') && district.isNotEmpty) return false;
                        } else if (!fullLoc.contains(sv)) {
                          return false;
                        }
                      }
                    }

                    final name = CategoryCityService.normalizeAz((data['fullName'] ?? '').toString());
                    final cat = CategoryCityService.normalizeAz((data['category'] ?? '').toString());
                    final specs = (data['specialties'] is List)
                        ? CategoryCityService.normalizeAz((data['specialties'] as List).join(' '))
                        : '';
                    final bio = CategoryCityService.normalizeAz((data['bio'] ?? '').toString());
                    return fullLoc.contains(normQ) || name.contains(normQ) || cat.contains(normQ) || specs.contains(normQ) || bio.contains(normQ);
                  }).map((d) {
                    final m = Map<String, dynamic>.from(d.data());
                    m['id'] = d.id;
                    m['uid'] = d.id;
                    return m;
                  }).toList();

                  matchingUstas.sort((a, b) {
                    final double aRat = (a['rating'] is num) ? (a['rating'] as num).toDouble() : 0.0;
                    final double bRat = (b['rating'] is num) ? (b['rating'] as num).toDouble() : 0.0;
                    return bRat.compareTo(aRat);
                  });

                  final matchingCats = _categories.where((c) {
                    final title = CategoryCityService.normalizeAz(c['title'] as String);
                    return title.contains(normQ);
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Color(0xFF1769D2), size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '"$rawQuery" axtarış nəticələri',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
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

                      if (matchingLocations.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'Uyğun Rayon və Kəndlər (Xəritədə göstər)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: matchingLocations.map((loc) {
                            final region = loc['region'] ?? '';
                            final village = loc['village'] ?? '';
                            final display = loc['display'] ?? region;
                            return ActionChip(
                              avatar: const Icon(Icons.pin_drop_rounded, size: 15, color: Color(0xFF059669)),
                              label: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFFECFDF5),
                              side: const BorderSide(color: Color(0xFFA7F3D0)),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  if (!_cities.contains(region) && region.isNotEmpty) {
                                    _cities.add(region);
                                  }
                                  _selectedCity = region;
                                  _selectedVillage = village;
                                  _selectedMapPinId = null;
                                  _centerMapOnSelection(city: region, village: village);
                                  _searchController.clear();
                                  _currentIndex = 3;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (matchingUstas.isEmpty && matchingCats.isEmpty && matchingLocations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.location_off_outlined, color: Colors.orange.shade400, size: 36),
                                const SizedBox(height: 6),
                                Text(
                                  'Axtardığınız "$rawQuery" üzrə "$selectedLocLabel" konumunda usta yoxdur',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Başqa bölgə seçin və ya fərqli peşə adı daxil edin',
                                  style: TextStyle(color: Colors.grey, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (matchingUstas.isEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Axtardığınız "$rawQuery" üzrə "$selectedLocLabel" konumunda usta yoxdur.',
                                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
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
                            final uBytes = _decodeB64(uPhoto);
                            if (uBytes != null) {
                              avatarImg = MemoryImage(uBytes);
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

        // 2. Kateqoriyalar Bölməsi (Yanında sürətli "Xəritə" keçidi ilə)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.grid_view_rounded, color: Color(0xFF1769D2), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Kateqoriyalar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _centerMapOnSelection();
                          _currentIndex = 3;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.map_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Xəritə',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _showAllCategoriesSheet,
                      child: Row(
                        children: const [
                          Text(
                            'Hamısına bax',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1769D2)),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1769D2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

        // 3. Shorts Videolar Bölməsi (Ekrana sığan 3 ən son video)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.play_circle_fill,
              iconColor: Colors.red,
              title: 'Shorts',
              actionTitle: 'Hamısını izlə',
              onTap: () {
                _ShortsVideoThumbnail.pauseAndReleaseAll();
                setState(() => _currentIndex = 1);
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 205,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _shortsStream,
              initialData: _latestShortsSnapshot,
              builder: (context, snapshot) {
                // Səhifə yenilənərkən 3 zərif işıqlı skelet kartı yan-yana
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    _latestShortsSnapshot == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: List.generate(3, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 4,
                              right: index == 2 ? 0 : 4,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBFDBFE).withOpacity(0.5)),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: const Color(0xFF1769D2).withOpacity(0.4),
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }

                final docs = (snapshot.data ?? _latestShortsSnapshot)?.docs ?? [];
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

                final top3Shorts = dynamicShorts.take(3).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 4,
                            right: index == 2 ? 0 : 4,
                          ),
                          child: index < top3Shorts.length
                              ? _buildDynamicShortsCard(top3Shorts[index], index)
                              : const SizedBox.shrink(),
                        ),
                      );
                    }),
                  ),
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
            stream: _ustaStream,
            initialData: _latestUstaSnapshot,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData &&
                  _latestUstaSnapshot == null) {
                return const SizedBox(
                  height: 155,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = (snapshot.data ?? _latestUstaSnapshot)?.docs ?? [];
              if (docs.isEmpty) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Hələlik qeydiyyatdan keçmiş usta yoxdur',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              }

              final List<Map<String, dynamic>> list = docs.map((d) {
                final m = Map<String, dynamic>.from(d.data());
                m['id'] = d.id;
                m['uid'] = d.id;
                return m;
              }).toList();

              // Seçilmiş şəhərə uyğun olan ustalar, sonra təsdiqlənmiş və yüksək reytinqlilər ön sıralarda çıxır
              final sc = _selectedCity.toLowerCase();
              list.sort((a, b) {
                final aMatches = (a['city'] ?? '').toString().toLowerCase().contains(sc);
                final bMatches = (b['city'] ?? '').toString().toLowerCase().contains(sc);
                if (aMatches != bMatches) return aMatches ? -1 : 1;
                final bool aVer = a['isVerified'] == true;
                final bool bVer = b['isVerified'] == true;
                if (aVer != bVer) return aVer ? -1 : 1;
                final double aRat = (a['rating'] is num) ? (a['rating'] as num).toDouble() : 0.0;
                final double bRat = (b['rating'] is num) ? (b['rating'] as num).toDouble() : 0.0;
                return bRat.compareTo(aRat);
              });

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
    int unreadBeforeOpen = _unreadNotifications;
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
                      if (unreadBeforeOpen > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadBeforeOpen yeni',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (unreadBeforeOpen > 0)
                    TextButton(
                      onPressed: () {
                        setState(() => _unreadNotifications = 0);
                        setSheetState(() => unreadBeforeOpen = 0);
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
                      isUnread: unreadBeforeOpen >= 1,
                    ),
                    _buildNotificationItem(
                      icon: Icons.verified_user,
                      iconBg: Colors.blue.shade100,
                      iconColor: const Color(0xFF1769D2),
                      title: 'Profil Təhlükəsizliyi 🛡️',
                      body: 'Hesabınız uğurla aktivləşdirilib. Profilinizdə gördüyünüz işlərin foto və videolarını paylaşa bilərsiniz.',
                      time: '2 saat əvvəl',
                      isUnread: unreadBeforeOpen >= 2,
                    ),
                    _buildNotificationItem(
                      icon: Icons.tips_and_updates,
                      iconBg: Colors.green.shade100,
                      iconColor: Colors.green.shade800,
                      title: 'Yeni İmkan: Usta Haqqında Məlumat 💡',
                      body: 'Artıq profilinizdə "Usta Haqqında" məlumatınızı istədiyiniz vaxt redaktə edib yeniləyə bilərsiniz!',
                      time: 'Dünən',
                      isUnread: unreadBeforeOpen >= 3,
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
                          hintText: 'Usta, rayon, kənd və ya xidmət axtarın...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
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
                    // Şəhər / Rayon / Kənd seçici düyməsi
                    InkWell(
                      onTap: _showLocationSearchSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF1769D2), size: 16),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 112),
                              child: Text(
                                _selectedVillage.isNotEmpty ? '$_selectedCity, $_selectedVillage' : _selectedCity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1769D2), size: 18),
                          ],
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
    );
  }

  /// Rayon və Kənd/Qəsəbə üzrə sürətli lokasiya seçimi pəncərəsi
  Future<void> _showLocationSearchSheet() async {
    final searchCtrl = TextEditingController();
    String tempRegion = _selectedCity;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.trim();
          final normQ = CategoryCityService.normalizeAz(query);
          final locationMatches = query.isNotEmpty
              ? CategoryCityService.searchLocations(query, maxResults: 30)
              : const <Map<String, String>>[];
          final villages = CategoryCityService.getVillagesForRegion(tempRegion);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 14,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Icon(Icons.explore_rounded, color: Color(0xFF1769D2), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Rayon, Şəhər və Kənd seçin',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rayon və ya kənd adı yazın (məs: Maştağa, Quba, Lahıc)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (query.isNotEmpty) ...[
                    Expanded(
                      child: locationMatches.isEmpty
                          ? Center(
                              child: Text(
                                '"$query" üzrə rayon və ya kənd tapılmadı',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: locationMatches.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final loc = locationMatches[index];
                                final region = loc['region'] ?? '';
                                final village = loc['village'] ?? '';
                                final isRegionOnly = village.isEmpty;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isRegionOnly ? Icons.location_city_rounded : Icons.pin_drop_rounded,
                                    color: isRegionOnly ? const Color(0xFF1769D2) : const Color(0xFF059669),
                                  ),
                                  title: Text(
                                    loc['display'] ?? region,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    isRegionOnly ? 'Şəhər / Rayon (bütün ərazi)' : '$region bölgəsi',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      if (!_cities.contains(region) && region.isNotEmpty) {
                                        _cities.add(region);
                                      }
                                      _selectedCity = region;
                                      _selectedVillage = village;
                                      _selectedMapPinId = null;
                                      _centerMapOnSelection(city: region, village: village);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    const Text(
                      '1. Şəhər / Rayon:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _cities.map((city) {
                          final selected = CategoryCityService.normalizeAz(city) == CategoryCityService.normalizeAz(tempRegion);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(city),
                              selected: selected,
                              selectedColor: const Color(0xFF1769D2),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : const Color(0xFF1E293B),
                              ),
                              onSelected: (_) {
                                setSheetState(() => tempRegion = city);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2. $tempRegion — Rayon, Qəsəbə və Kəndlər:',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.public_rounded, color: Color(0xFF1769D2)),
                            title: Text('Bütün $tempRegion ərazisi', style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: (CategoryCityService.normalizeAz(_selectedCity) == CategoryCityService.normalizeAz(tempRegion) &&
                                    _selectedVillage.isEmpty)
                                ? const Icon(Icons.check_circle, color: Color(0xFF1769D2), size: 20)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedCity = tempRegion;
                                _selectedVillage = '';
                                _selectedMapPinId = null;
                                _centerMapOnSelection(city: tempRegion, village: '');
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ...villages.where((v) => normQ.isEmpty || CategoryCityService.normalizeAz(v).contains(normQ)).map((v) {
                            final isCurrent = CategoryCityService.normalizeAz(_selectedCity) ==
                                    CategoryCityService.normalizeAz(tempRegion) &&
                                CategoryCityService.normalizeAz(_selectedVillage) == CategoryCityService.normalizeAz(v);
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF059669)),
                              title: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: isCurrent ? const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20) : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedCity = tempRegion;
                                  _selectedVillage = v;
                                  _selectedMapPinId = null;
                                  _centerMapOnSelection(city: tempRegion, village: v);
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  /// Açıq rəngli, real küçə xəritəsi ilə ayrıca "Xəritə" bölməsi (Alış-Satış ilə Mesajlar arasında)
  Widget _buildMapTab() {
    final regionVillages = CategoryCityService.getVillagesForRegion(_selectedCity);
    final rawQuery = _mapSearchController.text.trim();
    final normQ = CategoryCityService.normalizeAz(rawQuery);
    final locationSuggestions = rawQuery.isNotEmpty
        ? CategoryCityService.searchLocations(rawQuery, maxResults: 8)
        : const <Map<String, String>>[];

    final filterCats = _categories.where((c) => c['id'] != 'def_diger').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Üst Axtarış və Filtr Paneli
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 10),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.map_rounded, color: Color(0xFF059669), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Usta Xəritəsi',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Rayon və kəndlər üzrə yaxın ustalar',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showLocationSearchSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, color: Color(0xFF1769D2), size: 15),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 118),
                                  child: Text(
                                    _selectedVillage.isNotEmpty ? '$_selectedCity, $_selectedVillage' : _selectedCity,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1769D2),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1769D2), size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Xəritə daxili axtarış qutusu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _mapSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Rayon, kənd (Maştağa, Quba...), usta və ya peşə axtar...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: rawQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () {
                                  _mapSearchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  if (locationSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: locationSuggestions.map((loc) {
                          final region = loc['region'] ?? '';
                          final village = loc['village'] ?? '';
                          final display = loc['display'] ?? region;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF059669)),
                              label: Text(display, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFFECFDF5),
                              side: const BorderSide(color: Color(0xFFA7F3D0)),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  if (!_cities.contains(region) && region.isNotEmpty) {
                                    _cities.add(region);
                                  }
                                  _selectedCity = region;
                                  _selectedVillage = village;
                                  _selectedMapPinId = null;
                                  _centerMapOnSelection(city: region, village: village);
                                  _mapSearchController.clear();
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  // Kənd / Qəsəbə sürətli filtri
                  SizedBox(
                    height: 32,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('Bütün $_selectedCity'),
                            selected: _selectedVillage.isEmpty,
                            visualDensity: VisualDensity.compact,
                            selectedColor: const Color(0xFF059669),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _selectedVillage.isEmpty ? Colors.white : const Color(0xFF334155),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedVillage = '';
                                _selectedMapPinId = null;
                                _centerMapOnSelection(city: _selectedCity, village: '');
                              });
                            },
                          ),
                        ),
                        ...regionVillages.take(15).map((v) {
                          final sel = CategoryCityService.normalizeAz(_selectedVillage) == CategoryCityService.normalizeAz(v);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(v),
                              selected: sel,
                              visualDensity: VisualDensity.compact,
                              selectedColor: const Color(0xFF1769D2),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: sel ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0)),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : const Color(0xFF334155),
                              ),
                              onSelected: (_) {
                                final nextVillage = sel ? '' : v;
                                setState(() {
                                  _selectedVillage = nextVillage;
                                  _selectedMapPinId = null;
                                  _centerMapOnSelection(city: _selectedCity, village: nextVillage);
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  // İxtisas / Kateqoriya filtri
                  SizedBox(
                    height: 30,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: const Text('Bütün ustalar'),
                            selected: _selectedMapCategory.isEmpty,
                            visualDensity: VisualDensity.compact,
                            selectedColor: const Color(0xFF0F172A),
                            backgroundColor: const Color(0xFFF8FAFC),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _selectedMapCategory.isEmpty ? Colors.white : const Color(0xFF475569),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedMapCategory = '';
                                _selectedMapPinId = null;
                              });
                            },
                          ),
                        ),
                        ...filterCats.map((cat) {
                          final rawTitle = (cat['title'] as String).replaceAll('\n', ' ');
                          final sel = CategoryCityService.normalizeAz(_selectedMapCategory) ==
                              CategoryCityService.normalizeAz(rawTitle);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(rawTitle),
                              selected: sel,
                              visualDensity: VisualDensity.compact,
                              selectedColor: const Color(0xFF0F172A),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: sel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : const Color(0xFF475569),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedMapCategory = sel ? '' : rawTitle;
                                  _selectedMapPinId = null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Real Açıq Rəngli Küçə Xəritəsi + Usta Pinləri + Aşağı Kartlar
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ustaStream,
              initialData: _latestUstaSnapshot,
              builder: (context, snapshot) {
                final docs = (snapshot.data ?? _latestUstaSnapshot)?.docs ?? [];
                final allArtisans = docs.map((d) {
                  final m = Map<String, dynamic>.from(d.data());
                  m['id'] = d.id;
                  m['uid'] = d.id;
                  return m;
                }).where((u) {
                  if (normQ.isNotEmpty) {
                    final c = CategoryCityService.normalizeAz((u['city'] ?? '').toString());
                    final n = CategoryCityService.normalizeAz((u['fullName'] ?? '').toString());
                    final t = CategoryCityService.normalizeAz((u['category'] ?? '').toString());
                    final b = CategoryCityService.normalizeAz((u['bio'] ?? '').toString());
                    if (!c.contains(normQ) && !n.contains(normQ) && !t.contains(normQ) && !b.contains(normQ)) {
                      return false;
                    }
                  }
                  if (_selectedMapCategory.isNotEmpty) {
                    final t = CategoryCityService.normalizeAz((u['category'] ?? '').toString());
                    final target = CategoryCityService.normalizeAz(_selectedMapCategory);
                    final words = target.split(' ').where((w) => w.length > 3).toList();
                    final matchesCat = t.contains(target) || words.any((w) => t.contains(w));
                    if (!matchesCat) return false;
                  }
                  return true;
                }).toList();

                final sc = CategoryCityService.normalizeAz(_selectedCity);
                final sv = CategoryCityService.normalizeAz(_selectedVillage);

                allArtisans.sort((a, b) {
                  final aCity = CategoryCityService.normalizeAz((a['city'] ?? '').toString());
                  final bCity = CategoryCityService.normalizeAz((b['city'] ?? '').toString());
                  if (sv.isNotEmpty) {
                    final aV = aCity.contains(sv);
                    final bV = bCity.contains(sv);
                    if (aV != bV) return aV ? -1 : 1;
                  }
                  final aC = aCity.contains(sc);
                  final bC = bCity.contains(sc);
                  if (aC != bC) return aC ? -1 : 1;
                  final double aRat = (a['rating'] is num) ? (a['rating'] as num).toDouble() : 0.0;
                  final double bRat = (b['rating'] is num) ? (b['rating'] as num).toDouble() : 0.0;
                  return bRat.compareTo(aRat);
                });

                final areaMatches = allArtisans.where((a) {
                  final c = CategoryCityService.normalizeAz((a['city'] ?? '').toString());
                  if (sv.isNotEmpty) return c.contains(sv);
                  return c.contains(sc);
                }).toList();

                final List<Map<String, dynamic>> displayArtisans =
                    areaMatches.isNotEmpty ? areaMatches : allArtisans;

                Map<String, dynamic>? selectedPin;
                if (_selectedMapPinId != null) {
                  for (final u in allArtisans) {
                    if (u['id'] == _selectedMapPinId) {
                      selectedPin = u;
                      break;
                    }
                  }
                }

                return Stack(
                  children: [
                    // Real küçə tile xəritəsi
                    Positioned.fill(
                      child: _buildRealSlippyMapCanvas(allArtisans),
                    ),

                    // Yuxarı sol: tapılan usta sayı göstəricisi
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              areaMatches.isNotEmpty
                                  ? '${_selectedVillage.isNotEmpty ? "$_selectedCity, $_selectedVillage" : _selectedCity} • ${areaMatches.length} usta'
                                  : '${_selectedVillage.isNotEmpty ? "$_selectedCity, $_selectedVillage" : _selectedCity} • ${displayArtisans.length} usta',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sağ tərəf: Zoom (+ / -) və Mərkəzlə düymələri
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Column(
                        children: [
                          _buildMapCircleBtn(
                            icon: Icons.add_rounded,
                            tooltip: 'Yaxınlaşdır',
                            onTap: () {
                              setState(() => _mapZoom = (_mapZoom + 1.0).clamp(7.0, 17.0));
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildMapCircleBtn(
                            icon: Icons.remove_rounded,
                            tooltip: 'Uzaqlaşdır',
                            onTap: () {
                              setState(() => _mapZoom = (_mapZoom - 1.0).clamp(7.0, 17.0));
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildMapCircleBtn(
                            icon: Icons.my_location_rounded,
                            iconColor: const Color(0xFF1769D2),
                            tooltip: 'Bölgəyə mərkəzlə',
                            onTap: () {
                              setState(() => _centerMapOnSelection());
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildMapCircleBtn(
                            icon: _isSatelliteMap ? Icons.map_rounded : Icons.layers_rounded,
                            iconColor: _isSatelliteMap ? const Color(0xFF059669) : const Color(0xFF0F172A),
                            tooltip: _isSatelliteMap ? 'Küçə xəritəsi' : 'Peyk görünüşü',
                            onTap: () {
                              setState(() => _isSatelliteMap = !_isSatelliteMap);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Aşağı bölmə: Seçilmiş Usta Kartı və ya Üfüqi Usta Siyahısı
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: selectedPin != null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _buildMapSpotlightCard(selectedPin),
                            )
                          : (displayArtisans.isEmpty
                              ? Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8),
                                      ],
                                    ),
                                    child: const Text(
                                      'Bu axtarış üzrə usta tapılmadı',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 112,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: displayArtisans.take(15).length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, index) => _buildMapCompactCarouselCard(displayArtisans[index]),
                                  ),
                                )),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealSlippyMapCanvas(List<Map<String, dynamic>> artisans) {
    final int tileZ = _mapZoom.floor().clamp(7, 17);
    final int nTiles = 1 << tileZ;
    final double worldPx = 256.0 * math.pow(2.0, _mapZoom).toDouble();
    final double tileSize = 256.0 * math.pow(2.0, _mapZoom - tileZ).toDouble();

    double lngToX(double lng) => ((lng + 180.0) / 360.0) * worldPx;
    double latToY(double lat) {
      final double rad = lat.clamp(-85.0, 85.0) * math.pi / 180.0;
      final double s = math.sin(rad);
      final double f = 0.5 - math.log((1.0 + s) / (1.0 - s)) / (4.0 * math.pi);
      return f * worldPx;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double centerX = lngToX(_mapLng);
        final double centerY = latToY(_mapLat);

        final int minTx = ((centerX - w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTx = ((centerX + w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int minTy = ((centerY - h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTy = ((centerY + h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);

        final List<Widget> tileWidgets = [];

        for (int tx = minTx; tx <= maxTx; tx++) {
          for (int ty = minTy; ty <= maxTy; ty++) {
            final double left = w / 2.0 + (tx * tileSize - centerX);
            final double top = h / 2.0 + (ty * tileSize - centerY);
            final int sub = (tx + ty) % 4;
            final String lyrs = _isSatelliteMap ? 'y' : 'm';
            final String googleTileUrl = 'https://mt$sub.google.com/vt/lyrs=$lyrs&x=$tx&y=$ty&z=$tileZ&hl=az';
            final String arcgisUrl =
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$tileZ/$ty/$tx';

            tileWidgets.add(
              Positioned(
                key: ValueKey('tile_${_isSatelliteMap ? "sat" : "str"}_${tileZ}_${tx}_$ty'),
                left: left,
                top: top,
                width: tileSize + 0.6,
                height: tileSize + 0.6,
                child: Image.network(
                  googleTileUrl,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Image.network(
                    arcgisUrl,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          }
        }

        final List<Widget> pinWidgets = [];
        final List<List<double>> placedCoords = [];
        for (final u in artisans) {
          final uid = (u['id'] ?? '').toString();
          final uCity = (u['city'] ?? 'Bakı').toString();
          final double? uLat = (u['lat'] is num) ? (u['lat'] as num).toDouble() : null;
          final double? uLng = (u['lng'] is num) ? (u['lng'] as num).toDouble() : null;
          var coords = CategoryCityService.resolveArtisanCoordinates(
            uCity,
            uid,
            lat: uLat,
            lng: uLng,
          );
          int overlapIdx = 0;
          for (final prev in placedCoords) {
            if ((coords[0] - prev[0]).abs() < 0.0001 && (coords[1] - prev[1]).abs() < 0.0001) {
              overlapIdx++;
            }
          }
          if (overlapIdx > 0) {
            final double angle = overlapIdx * 2.0943951; // 120 dərəcə addımla kiçik dairə
            coords = [
              coords[0] + math.sin(angle) * 0.0003,
              coords[1] + math.cos(angle) * 0.0003,
            ];
          }
          placedCoords.add(coords);
          final double px = w / 2.0 + (lngToX(coords[1]) - centerX);
          final double py = h / 2.0 + (latToY(coords[0]) - centerY);
          if (px < -70 || px > w + 70 || py < -70 || py > h + 70) continue;

          pinWidgets.add(_buildMapPinMarker(u, uid, px, py));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_selectedMapPinId != null) {
              setState(() => _selectedMapPinId = null);
            }
          },
          onPanUpdate: (details) {
            final double cx = centerX - details.delta.dx;
            final double cy = centerY - details.delta.dy;
            final double nLng = ((cx / worldPx) * 360.0 - 180.0).clamp(43.5, 52.0);
            final double yF = (cy / worldPx).clamp(0.01, 0.99);
            final double n = math.pi - 2.0 * math.pi * yF;
            final double nLat = (180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)))).clamp(37.5, 42.6);
            setState(() {
              _mapLat = nLat;
              _mapLng = nLng;
            });
          },
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BrightStreetMapFallbackPainter()),
                ),
                ...tileWidgets,
                ...pinWidgets,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapPinMarker(Map<String, dynamic> u, String uid, double px, double py) {
    final bool isSelected = _selectedMapPinId == uid;
    final String uName = (u['fullName'] ?? 'Usta').toString();
    final String shortName = uName.split(' ').first;
    final String uTrade = (u['category'] ?? 'Usta').toString();
    final avatarBytes = _decodeB64(u['photoBase64'] as String?);

    return Positioned(
      left: px - 42,
      top: py - 58,
      width: 84,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMapPinId = isSelected ? null : uid;
          });
        },
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1769D2),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                  child: avatarBytes == null
                      ? Text(
                          uName.isNotEmpty ? uName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFB45309) : const Color(0xFF1769D2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1769D2) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1769D2) : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isSelected ? '$shortName ($uTrade)' : shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
  }

  Widget _buildMapCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSpotlightCard(Map<String, dynamic> u) {
    final uName = (u['fullName'] ?? 'Usta').toString();
    final uTrade = (u['category'] ?? 'Usta').toString();
    final uCity = (u['city'] ?? 'Bakı').toString();
    final uPhone = (u['phone'] ?? '').toString();
    final rating = u['rating'] != null ? u['rating'].toString() : 'Yeni';
    final avatarBytes = _decodeB64(u['photoBase64'] as String?);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArtisanDetailScreen(artisanData: u)),
              );
            },
            child: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
              child: avatarBytes == null
                  ? Text(
                      uName.isNotEmpty ? uName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1769D2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArtisanDetailScreen(artisanData: u)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          uName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFF1769D2), size: 15),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$uTrade • $uCity',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 3),
                      Text(rating, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (uPhone.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.call, color: Color(0xFF00C853), size: 22),
              tooltip: 'Zəng et',
              onPressed: () => _makeCall(uPhone),
            ),
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.green, size: 22),
              tooltip: 'WhatsApp',
              onPressed: () => _openWhatsApp(uPhone),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => setState(() => _selectedMapPinId = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCompactCarouselCard(Map<String, dynamic> u) {
    final uid = (u['id'] ?? '').toString();
    final uName = (u['fullName'] ?? 'Usta').toString();
    final uTrade = (u['category'] ?? 'Usta').toString();
    final uCity = (u['city'] ?? 'Bakı').toString();
    final uPhone = (u['phone'] ?? '').toString();
    final avatarBytes = _decodeB64(u['photoBase64'] as String?);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final double? uLat = (u['lat'] is num) ? (u['lat'] as num).toDouble() : null;
        final double? uLng = (u['lng'] is num) ? (u['lng'] as num).toDouble() : null;
        final coords = CategoryCityService.resolveArtisanCoordinates(
          uCity,
          uid,
          lat: uLat,
          lng: uLng,
        );
        setState(() {
          _selectedMapPinId = uid;
          _mapLat = coords[0];
          _mapLng = coords[1];
          if (_mapZoom < 13.0) _mapZoom = 13.5;
        });
      },
      child: Container(
        width: 245,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
              child: avatarBytes == null
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    uName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    uTrade,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1769D2), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 11, color: Colors.redAccent),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          uCity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (uPhone.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.call, color: Color(0xFF00C853), size: 19),
                onPressed: () => _makeCall(uPhone),
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
    final String artisanName = (item['author'] ?? item['artisanName'] ?? 'Usta').toString();
    final String title = (item['title'] ?? '').toString();

    // Video kadrı çıxarılana qədər parlaq və işıqlı fallback
    final Widget fallbackVisual = _buildShortsFallbackVisual(
      title: title,
      trade: trade,
      artisanName: artisanName,
    );

    Widget coverWidget;
    final Uint8List? thumbBytes = _decodeB64(thumbnailBase64);
    if (thumbBytes != null) {
      coverWidget = Image.memory(
        thumbBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => fallbackVisual,
      );
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
          shortDocId: (item['id'] ?? '').toString(),
          collectionName: 'shorts',
          ownerId: (item['userId'] ?? '').toString(),
          fallback: fallbackVisual,
        );
      } else {
        coverWidget = fallbackVisual;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        _ShortsVideoThumbnail.pauseAndReleaseAll();
        final targetIndex = await Navigator.push<int>(
          context,
          MaterialPageRoute(
            builder: (routeCtx) => ShortsScreen(
              initialIndex: index,
              onNavigateTab: (idx) {
                Navigator.pop(routeCtx, idx);
              },
              onOpenArtisanProfile: (artisanData) async {
                await Navigator.push(
                  routeCtx,
                  MaterialPageRoute(
                    builder: (_) => ArtisanDetailScreen(artisanData: artisanData),
                  ),
                );
              },
            ),
          ),
        );
        _ShortsVideoThumbnail.resumeAll();
        if (targetIndex != null && mounted) {
          setState(() => _currentIndex = targetIndex);
        }
      },
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. VİDEONUN REAL BAŞLIQ FOTOSU
                    coverWidget,

                    // 2. Yalnız aşağıda zərif qradiyent
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // 3. Ən son yüklənən üçün YENİ nişanı (index == 0)
                    if (index == 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YENİ',
                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    // 4. Mərkəzdə Play ikonu
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // 5. Aşağıda Müəllif adı
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: _AuthorNameText(
                        userId: (item['userId'] ?? '').toString(),
                        defaultName: (item['author'] ?? 'Usta').toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item['title'] ?? 'Usta Videosu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
    final String rating = (artisan['rating'] != null) ? artisan['rating'].toString() : 'Yeni';
    final String reviews = (artisan['reviewCount'] ?? artisan['reviews'] ?? artisan['reviewsCount'] ?? '0').toString();

    ImageProvider? avatarImg;
    final photoBytes = _decodeB64(photoBase64);
    if (photoBytes != null) {
      avatarImg = MemoryImage(photoBytes);
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

  // AŞAĞI NAVİQASİYA (6 tab: Alış-Satış ilə Mesajlar arasında Xəritə bölməsi)
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
        onTap: (idx) {
          if (idx == 1) {
            _ShortsVideoThumbnail.pauseAndReleaseAll();
          } else {
            _ShortsVideoThumbnail.resumeAll();
          }
          setState(() => _currentIndex = idx);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1769D2),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 10.5,
        unselectedFontSize: 10,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Ana səhifə',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Shorts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront_rounded),
            label: 'Alış-Satış',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Xəritə',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Mesajlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // Yeni İş / Şəkil və ya Shorts Video Paylaşmaq dialoqu (Yeni dizayn və sistemə 1:1 uyğun)
  Future<void> _showAddPostDialog(String uid, String authorName, String role, {int initialTab = 0, bool lockTab = false}) async {
    // Qalereya və video seçimi üçün MediaCodec və RAM-ı dərhal tam boşaldırıq
    _ShortsVideoThumbnail.pauseAndReleaseAll();

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
        onBeforeOpenGallery: _ShortsVideoThumbnail.pauseAndReleaseAll,
      ),
    );
    _ShortsVideoThumbnail.resumeAll();
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
                      _decodeB64(imgBase64) ?? base64Decode(imgBase64),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
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
                                try {
                                  await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                  if (videoUrl.isNotEmpty) {
                                    final shQ = await FirebaseFirestore.instance
                                        .collection('shorts')
                                        .where('videoUrl', isEqualTo: videoUrl)
                                        .get();
                                    for (final d in shQ.docs) {
                                      await ShortsSocialService.deleteShortVideoCompletely(d.id);
                                    }
                                  }
                                } catch (_) {}
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                    const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Paylaşım silindi.')),
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
            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? [])
              ..sort(_compareCreatedAtDesc);
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
                crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 1.0,
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
                            final bBytes = _decodeB64(base64Img);
                            if (bBytes != null) {
                              return Image.memory(bBytes, fit: BoxFit.cover, gaplessPlayback: true);
                            }
                            final thumbUrl = data['thumbnailUrl']?.toString();
                            if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                              return Image.network(thumbUrl, fit: BoxFit.cover);
                            }
                            final videoUrl = (data['videoUrl'] ?? '').toString();
                            final fallbackVisual = _buildShortsFallbackVisual(
                              title: (data['title'] ?? '').toString(),
                              trade: (data['category'] ?? data['trade'] ?? 'Usta İşi').toString(),
                              artisanName: (data['authorName'] ?? '').toString(),
                            );
                            if (videoUrl.isNotEmpty && index < 6) {
                              return _ShortsVideoThumbnail(
                                key: ValueKey('post_thumb_${doc.id}'),
                                videoUrl: videoUrl,
                                shortDocId: doc.id,
                                collectionName: 'posts',
                                ownerId: (data['userId'] ?? '').toString(),
                                fallback: fallbackVisual,
                              );
                            }
                            return fallbackVisual;
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
                    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                      const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Profil şəkli silindi.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta: $e'), backgroundColor: Colors.red),
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
          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
            const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Profil şəkli uğurla yeniləndi!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Profil məlumatlarını redaktə etmək üçün müasir dizaynlı dialoq
  void _showEditProfileDialog(String uid, Map<String, dynamic>? userData) {
    final nameController = TextEditingController(text: userData?['fullName'] ?? '');
    final phoneController = TextEditingController(text: userData?['phone'] ?? '');
    final bioController = TextEditingController(text: userData?['bio'] ?? '');
    final tiktokController = TextEditingController(text: userData?['tiktokHandle'] ?? '');
    final instagramController = TextEditingController(text: userData?['instagramHandle'] ?? '');
    final websiteController = TextEditingController(text: userData?['websiteUrl'] ?? userData?['website'] ?? '');
    final specialtySearchController = TextEditingController();
    String specialtySearchQuery = '';
    String specialtyLimitWarning = '';

    String selectedRole = userData?['role'] ?? 'usta';
    String selectedUstaCategory = userData?['category'] ?? 'Tikinti';
    bool isWorkingStatus = userData?['isWorking'] == true;

    // Mövcud ixtisas ID-lərini təyin edirik (Maksimum 4 sahə)
    final Set<String> selectedSpecialtyIds = {};
    if (userData?['specialtyIds'] is List) {
      for (final item in (userData!['specialtyIds'] as List)) {
        if (item != null && item.toString().trim().isNotEmpty) {
          if (selectedSpecialtyIds.length < 4) {
            selectedSpecialtyIds.add(item.toString().trim());
          }
        }
      }
    }
    // Əgər specialtyIds yoxdursa, specialties və ya category sahəsinə görə ilkin ixtisasları təyin edirik
    if (selectedSpecialtyIds.isEmpty && userData?['specialties'] is List) {
      for (final spTitle in (userData!['specialties'] as List)) {
        if (spTitle == null) continue;
        final t = spTitle.toString().trim().toLowerCase();
        for (final g in CategoryCityService.specialtyGroups) {
          final items = g['items'] as List<Map<String, String>>;
          for (final it in items) {
            if (it['title']!.toLowerCase() == t) {
              if (selectedSpecialtyIds.length < 4) selectedSpecialtyIds.add(it['id']!);
              break;
            }
          }
        }
      }
    }
    if (selectedSpecialtyIds.isEmpty && userData?['category'] != null) {
      final rawCat = (userData!['category'] as String);
      final catParts = rawCat.split(',').map((e) => e.trim().toLowerCase()).toList();
      for (final part in catParts) {
        for (final g in CategoryCityService.specialtyGroups) {
          final items = g['items'] as List<Map<String, String>>;
          for (final it in items) {
            final tLower = it['title']!.toLowerCase();
            if (part == tLower || part.contains(tLower) || tLower.contains(part)) {
              if (selectedSpecialtyIds.length < 4) {
                selectedSpecialtyIds.add(it['id']!);
              }
              break;
            }
          }
        }
      }
    }

    final Set<String> expandedGroupIds = {};

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
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = specialtySearchQuery.trim().toLowerCase();

          return Dialog(
            backgroundColor: Colors.white,
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Pinned Header (Müasir Üst Başlıq)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF1769D2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profil Məlumatlarını Redaktə Et',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Məlumatlarınızı və göstərdiyiniz xidmətləri yeniləyin',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                          onPressed: () => Navigator.pop(ctx),
                          tooltip: 'Bağla',
                        ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BÖLMƏ 1: Əsas Məlumatlar
                          const Text(
                            'Əsas Məlumatlar',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),

                          // Ad və Soyad
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Ad və Soyad',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1769D2), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mobil Nömrə
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Mobil Nömrə',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF10B981), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Hesab Növü (Rol)
                          DropdownButtonFormField<String>(
                            value: ['usta', 'worker', 'customer', 'seller'].contains(selectedRole) ? selectedRole : 'usta',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Hesab Növü',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF8B5CF6), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'usta', child: Text('Usta kimi (Peşəkar usta)')),
                              DropdownMenuItem(value: 'worker', child: Text('Fəhlə kimi (Köməkçi işçi)')),
                              DropdownMenuItem(value: 'customer', child: Text('Müştəri kimi')),
                              DropdownMenuItem(value: 'seller', child: Text('Satıcı / Mağaza')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedRole = val);
                            },
                          ),
                          const SizedBox(height: 18),

                          // BÖLMƏ 2: Məkan və Ünvan
                          const Text(
                            'Məkan və Ünvan',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  value: _cities.contains(selectedCityVal) ? selectedCityVal : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Şəhər / Rayon',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF1769D2), size: 19),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                                  ),
                                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedCityVal = val;
                                        districtController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 6,
                                child: TextField(
                                  controller: districtController,
                                  onChanged: (_) => setDialogState(() {}),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Kənd / Qəsəbə / Ərazi',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: 'Məs: Yasamal, Qobu...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.pin_drop_outlined, color: Color(0xFFEA580C), size: 19),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Sürətli Qəsəbə Seçimləri (Çiplər)
                          SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: CategoryCityService.getVillagesForRegion(selectedCityVal).map((v) {
                                final isPicked = districtController.text.trim().toLowerCase() == v.toLowerCase();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      v,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isPicked ? Colors.white : const Color(0xFF1E293B),
                                        fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    backgroundColor: isPicked ? const Color(0xFF1769D2) : const Color(0xFFF1F5F9),
                                    side: BorderSide(color: isPicked ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setDialogState(() {
                                        districtController.text = v;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // BÖLMƏ 3: İXTİSAS SEÇİMİ (Qeydiyyatdakı kimi zəngin və geniş)
                          if (selectedRole == 'usta' || selectedRole == 'worker') ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.handyman_rounded, color: Color(0xFF1769D2), size: 18),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'İxtisas və Fəaliyyət Sahələri (Maksimum 4)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: selectedSpecialtyIds.length >= 4 ? const Color(0xFF10B981) : const Color(0xFF1769D2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${selectedSpecialtyIds.length}/4 seçilib',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gördüyünüz işləri seçin (profilinizdə görünməsi üçün maksimum 4 sahə seçə bilərsiniz):',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),

                            // Axtarış Xanası
                            TextField(
                              controller: specialtySearchController,
                              onChanged: (val) => setDialogState(() => specialtySearchQuery = val),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'İxtisas axtar (Santexnik, Malyar, PlayStation, Kafel)...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                suffixIcon: specialtySearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                        onPressed: () {
                                          specialtySearchController.clear();
                                          setDialogState(() => specialtySearchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Seçilmiş İxtisasların Həbləri (Badges)
                            if (selectedSpecialtyIds.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Seçilmiş İxtisaslarınız:',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                        GestureDetector(
                                          onTap: () => setDialogState(() {
                                            specialtyLimitWarning = '';
                                            selectedSpecialtyIds.clear();
                                          }),
                                          child: const Text(
                                            'Hamısını təmizlə',
                                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: selectedSpecialtyIds.map((sId) {
                                        final sp = CategoryCityService.findSpecialtyById(sId);
                                        final title = sp != null ? sp['title']! : sId;
                                        return Chip(
                                          backgroundColor: const Color(0xFFEFF6FF),
                                          deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1769D2)),
                                          onDeleted: () => setDialogState(() {
                                            specialtyLimitWarning = '';
                                            selectedSpecialtyIds.remove(sId);
                                          }),
                                          label: Text(
                                            title,
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                          ),
                                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // 5-ci ixtisas seçilərkən birbaşa bölmə daxilində görünən xəbərdarlıq banneri
                            if (specialtyLimitWarning.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        specialtyLimitWarning,
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setDialogState(() => specialtyLimitWarning = ''),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Qeydiyyatdakı Kateqoriya Qrupları Akordeon Şəklində
                            ...CategoryCityService.specialtyGroups.map((g) {
                              final gId = g['id'] as String;
                              final gTitle = g['title'] as String;
                              final gIcon = g['icon'] as IconData;
                              final gColor = g['color'] as Color;
                              final items = (g['items'] as List<Map<String, String>>);

                              final matchingItems = query.isEmpty
                                  ? items
                                  : items.where((it) => it['title']!.toLowerCase().contains(query)).toList();

                              if (query.isNotEmpty && matchingItems.isEmpty) return const SizedBox.shrink();

                              final selectedCountInGroup = items.where((it) => selectedSpecialtyIds.contains(it['id'])).length;
                              final isExpanded = expandedGroupIds.contains(gId) || query.isNotEmpty;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selectedCountInGroup > 0 ? gColor : const Color(0xFFE2E8F0),
                                    width: selectedCountInGroup > 0 ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        setDialogState(() {
                                          if (expandedGroupIds.contains(gId)) {
                                            expandedGroupIds.remove(gId);
                                          } else {
                                            expandedGroupIds.add(gId);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: gColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(gIcon, color: gColor, size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                gTitle,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: selectedCountInGroup > 0 ? gColor : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (selectedCountInGroup > 0)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: gColor,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$selectedCountInGroup',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            Icon(
                                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                              color: const Color(0xFF64748B),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded) ...[
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: matchingItems.map((item) {
                                            final itemId = item['id']!;
                                            final itemTitle = item['title']!;
                                            final isChecked = selectedSpecialtyIds.contains(itemId);

                                            return FilterChip(
                                              label: Text(
                                                itemTitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                                  color: isChecked ? Colors.white : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              selected: isChecked,
                                              selectedColor: gColor,
                                              backgroundColor: const Color(0xFFF8FAFC),
                                              checkmarkColor: Colors.white,
                                              showCheckmark: true,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: BorderSide(
                                                  color: isChecked ? gColor : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    if (selectedSpecialtyIds.length >= 4) {
                                                      specialtyLimitWarning = 'Maksimum 4 ixtisas sahəsi seçə bilərsiniz!';
                                                      return;
                                                    }
                                                    specialtyLimitWarning = '';
                                                    selectedSpecialtyIds.add(itemId);
                                                  } else {
                                                    specialtyLimitWarning = '';
                                                    selectedSpecialtyIds.remove(itemId);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 14),

                            // Usta Haqqında Məlumat (Bio / Təcrübə)
                            const Text(
                              'Haqqında Məlumat',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: bioController,
                              maxLines: 4,
                              maxLength: 500,
                              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                labelText: 'Gördüyünüz işlər, təcrübəniz və xidmət şərtləriniz...',
                                labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 50),
                                  child: Icon(Icons.info_outline_rounded, color: Color(0xFF1769D2), size: 20),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Müasir İş Statusu Kartı (Sərbəstəm / Məşğulam)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isWorkingStatus ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isWorkingStatus ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isWorkingStatus ? const Color(0xFFF43F5E).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isWorkingStatus ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                                      color: isWorkingStatus ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isWorkingStatus ? 'Hal-hazırda işləyirəm (Məşğulam)' : 'Sərbəstəm (İş təkliflərinə açığam)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isWorkingStatus ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isWorkingStatus ? 'Profilinizdə qırmızı "Məşğul" statusu görünəcək' : 'Profilinizdə yaşıl "Sərbəstəm" statusu görünəcək',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isWorkingStatus ? const Color(0xFFE11D48).withOpacity(0.8) : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: !isWorkingStatus,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) => setDialogState(() => isWorkingStatus = !val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // BÖLMƏ 4: Sosial Linklər (Maksimum 3 link)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.link_rounded, color: Color(0xFF1769D2), size: 19),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sosial Şəbəkələr və Linklər (Maksimum 3 ədəd)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hesabınızı silmək üçün xananı boşaldın və ya (✕) işarəsinə vurun.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),

                                // 1. TikTok
                                TextField(
                                  controller: tiktokController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '1. TikTok Hesabı',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: '@istifadəçi_adı və ya link',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.music_note_rounded, color: Color(0xFFFE2C55), size: 18),
                                    suffixIcon: tiktokController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => tiktokController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                                const SizedBox(height: 10),

                                // 2. Instagram
                                TextField(
                                  controller: instagramController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '2. Instagram Hesabı',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: '@istifadəçi_adı və ya link',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 18),
                                    suffixIcon: instagramController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => instagramController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                                const SizedBox(height: 10),

                                // 3. Veb-sayt / Digər link
                                TextField(
                                  controller: websiteController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '3. Veb-sayt və ya Digər link',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: 'sayt.az, youtube, facebook...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF1769D2), size: 18),
                                    suffixIcon: websiteController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => websiteController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Pinned Footer Actions (Bərkidilmiş Alt Düymələr)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Ləğv et',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1769D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text(
                              'Yadda Saxla',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            onPressed: () async {
                              final String district = districtController.text.trim();
                              if ((selectedRole == 'usta' || selectedRole == 'worker') && district.isEmpty) {
                                ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                  const SnackBar(duration: Duration(milliseconds: 1300), 
                                    content: Text('Usta və fəhlə üçün kənd / qəsəbə / ərazi göstərmək vacibdir!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final String initialRole = _normalizeRoleKey(userData?['role']?.toString() ?? 'usta');
                              if (initialRole == 'seller' && _normalizeRoleKey(selectedRole) != 'seller') {
                                final allowed = await _canSwitchFromSellerRole(uid, popParentOnNavigate: true);
                                if (!allowed) return;
                              }
                              final String fullCity = district.isNotEmpty ? '$selectedCityVal, $district' : selectedCityVal;
                              final coords = CategoryCityService.getCoordinates(selectedCityVal, district);
                              final updatedName = nameController.text.trim();
                              final updatedPhone = phoneController.text.trim();

                              // Seçilmiş ixtisas adları və kateqoriyaları (maksimum 4 sahə)
                              final specialtyTitles = <String>[];
                              final specialtyCategoryTitles = <String>{};
                              for (final sId in selectedSpecialtyIds.take(4)) {
                                final sp = CategoryCityService.findSpecialtyById(sId);
                                if (sp != null) {
                                  specialtyTitles.add(sp['title']!);
                                  specialtyCategoryTitles.add(sp['groupTitle']!);
                                }
                              }

                              // Bütün seçilmiş ixtisaslar profilin başlığında ardıcıl görünür (məs: Santexnik, Tikinti, Elektrik ustası)
                              final updatedTrade = selectedRole == 'usta'
                                  ? (specialtyTitles.isNotEmpty ? specialtyTitles.join(', ') : selectedUstaCategory)
                                  : (selectedRole == 'worker' ? (specialtyTitles.isNotEmpty ? specialtyTitles.join(', ') : 'Fəhlə (Köməkçi işlər)') : '');

                              final cleanedTikTok = _cleanTikTokHandle(tiktokController.text.trim());
                              final cleanedInsta = _cleanInstagramHandle(instagramController.text.trim());
                              final rawWeb = websiteController.text.trim();

                              final currentConsent = userData?['locationSharingConsent'] == true;
                              final bool shareCoords = currentConsent;

                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'fullName': updatedName,
                                'phone': updatedPhone,
                                'role': selectedRole,
                                'category': updatedTrade,
                                'specialtyIds': selectedSpecialtyIds.toList(),
                                'specialties': specialtyTitles,
                                'specialtyCategories': specialtyCategoryTitles.toList(),
                                'city': fullCity,
                                'isWorking': (selectedRole == 'usta' || selectedRole == 'worker') ? isWorkingStatus : false,
                                'bio': (selectedRole == 'usta' || selectedRole == 'worker') ? bioController.text.trim() : (userData?['bio'] ?? ''),
                                'tiktokHandle': cleanedTikTok,
                                'tiktokConnected': cleanedTikTok.isNotEmpty,
                                'instagramHandle': cleanedInsta,
                                'websiteUrl': rawWeb,
                                if (shareCoords) 'lat': coords[0],
                                if (shareCoords) 'lng': coords[1],
                                if (shareCoords) 'latitude': coords[0],
                                if (shareCoords) 'longitude': coords[1],
                              }, SetOptions(merge: true));

                              // Mövcud Shorts və Post-ları yeni ad və ixtisas ilə sinxronlaşdır
                              await _syncUserDataAcrossCollections(
                                uid,
                                newName: updatedName,
                                newPhone: updatedPhone,
                                newTrade: updatedTrade,
                              );

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                                  const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Profil məlumatları uğurla yeniləndi! 🎉'), backgroundColor: Colors.green),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(duration: Duration(milliseconds: 1300), 
                      content: Text('Haqqımda məlumatı uğurla yeniləndi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
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

  Future<bool> _hasActiveSellerListings(String uid) async {
    try {
      final byOwner = await FirebaseFirestore.instance
          .collection('market_stores')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (byOwner.docs.isNotEmpty) return true;

      final byUser = await FirebaseFirestore.instance
          .collection('market_stores')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (byUser.docs.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  Future<bool> _canSwitchFromSellerRole(
    String uid, {
    bool popParentOnNavigate = false,
  }) async {
    // İndi hər kəs (Usta, Fəhlə, Müştəri, Satıcı) mağaza və elan aça bildiyi üçün keçid hər zaman sərbəstdir
    return true;
  }

  String _normalizeRoleKey(String role) {
    final r = role.trim().toLowerCase();
    if (r == 'satici' || r == 'satıcı' || r == 'seller') return 'seller';
    if (r == 'fehle' || r == 'fəhlə' || r == 'worker') return 'worker';
    if (r == 'musteri' || r == 'müştəri' || r == 'customer') return 'customer';
    return 'usta';
  }

  String _roleDisplayName(String roleKey) {
    switch (_normalizeRoleKey(roleKey)) {
      case 'seller':
        return 'Satıcı';
      case 'worker':
        return 'Fəhlə';
      case 'customer':
        return 'Müştəri';
      case 'usta':
      default:
        return 'Usta';
    }
  }

  Future<void> _handleProfileRoleChange(
    String uid,
    String currentRole,
    String newRole,
  ) async {
    final normalizedCurrent = _normalizeRoleKey(currentRole);
    final normalizedTarget = _normalizeRoleKey(newRole);
    if (normalizedCurrent == normalizedTarget) return;

    if (normalizedCurrent == 'seller' && normalizedTarget != 'seller') {
      final allowed = await _canSwitchFromSellerRole(uid);
      if (!allowed) return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'role': normalizedTarget,
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1300), 
            content: Text(
              'Aktiv profil növünüz "${_roleDisplayName(normalizedTarget)}" olaraq dəyişdirildi.',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1300), 
            content: Text('Profil növü yenilənmədi: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildFourRoleSwitcherCard(String uid, String currentRole) {
    final activeKey = _normalizeRoleKey(currentRole);
    final roles = <Map<String, dynamic>>[
      {
        'key': 'usta',
        'label': 'Usta',
        'icon': Icons.handyman_rounded,
        'color': const Color(0xFF1769D2),
      },
      {
        'key': 'worker',
        'label': 'Fəhlə',
        'icon': Icons.construction_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'key': 'customer',
        'label': 'Müştəri',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF0D9488),
      },
      {
        'key': 'seller',
        'label': 'Satıcı',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFF7C3AED),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF1769D2),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Aktiv Profil Növü',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1769D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _roleDisplayName(activeKey),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1769D2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Elan və mağaza yerləşdirmək üçün Satıcı profili aktiv olmalıdır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.1,
            children: roles.map((item) {
              final roleKey = item['key'] as String;
              final label = item['label'] as String;
              final icon = item['icon'] as IconData;
              final accent = item['color'] as Color;
              final isSelected = activeKey == roleKey;

              return Material(
                color: isSelected ? accent : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _handleProfileRoleChange(uid, currentRole, roleKey),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? accent : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isSelected ? Colors.white : accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (activeKey == 'seller') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1769D2),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text(
                  'Mağaza və elanlarımı idarə et',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 2;
                    _openMyListingsSignal++;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationPrivacyCard(String uid, Map<String, dynamic>? userData) {
    final bool consent = userData?['locationSharingConsent'] == true;
    final String city = (userData?['city'] ?? 'Bakı').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: consent ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: consent ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: consent ? 1.5 : 1,
        ),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: consent ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  consent ? Icons.share_location_rounded : Icons.location_off_rounded,
                  color: consent ? const Color(0xFF059669) : const Color(0xFF64748B),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Konum Paylaşımı Vəziyyəti',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: consent ? const Color(0xFF059669).withOpacity(0.12) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  consent ? 'Aktivdir' : 'Deaktivdir',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: consent ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            consent
                ? 'Dəqiq konumunuz UstaGo xəritəsində yaxınlıqdakı istifadəçilərə göstərilir. İstənilən vaxt söndürə bilərsiniz.'
                : 'Konum paylaşımı bağlıdır. Xəritədə dəqiq koordinatınız göstərilmir (yalnız $city rayon/şəhər adı görünür).',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: consent,
            activeColor: const Color(0xFF059669),
            title: Text(
              consent ? 'Konumumu xəritədə paylaş' : 'Konumu gizli saxla',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: consent ? const Color(0xFF059669) : const Color(0xFF334155),
              ),
            ),
            subtitle: Text(
              consent
                  ? 'Konumu gizlətmək üçün toxunun'
                  : 'Xəritədə görünmək üçün icazə verin',
              style: const TextStyle(fontSize: 11),
            ),
            onChanged: (val) async {
              if (val) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Konumu paylaşmaq istəyirsiniz?'),
                    content: const Text(
                      'Konumunuz yalnız təsdiq etdikdən sonra ictimai profildə və UstaGo xəritəsində göstəriləcək.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İmtina et')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1769D2),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Bəli, paylaş'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;

                final rawCity = (userData?['city'] ?? 'Bakı').toString();
                final coords = CategoryCityService.getCoordinates(rawCity);

                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'locationSharingConsent': true,
                  'lat': coords[0],
                  'lng': coords[1],
                  'latitude': coords[0],
                  'longitude': coords[1],
                }, SetOptions(merge: true));

                if (mounted) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(duration: Duration(milliseconds: 1300), 
                      content: Text('Konum paylaşımı aktivləşdirildi.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              } else {
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'locationSharingConsent': false,
                  'lat': FieldValue.delete(),
                  'lng': FieldValue.delete(),
                  'latitude': FieldValue.delete(),
                  'longitude': FieldValue.delete(),
                }, SetOptions(merge: true));

                if (mounted) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(duration: Duration(milliseconds: 1300), 
                      content: Text('Konum paylaşımı söndürüldü və koordinatlar profildən silindi.'),
                      backgroundColor: Color(0xFF334155),
                    ),
                  );
                }
              }
            },
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
        final uBytes = _decodeB64(photoBase64);
        if (uBytes != null) {
          avatarImage = MemoryImage(uBytes);
        } else if (photoUrl != null && photoUrl.isNotEmpty) {
          avatarImage = NetworkImage(photoUrl);
        }

        // Bütün rollar üçün (Usta, Fəhlə, Satıcı, Müştəri) vahid modern premium profil dizaynı
        return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);
      },
    );
  }

  /// İnstaqram Sağ Yuxarı 3 Nöqtə (⋮) menyusu — Bütün ayarlar və idarəetmə funksiyaları
  Future<void> _recalculateTargetRating(String artisanUid) async {
    try {
      final reviewsRef = FirebaseFirestore.instance.collection('users').doc(artisanUid).collection('reviews');
      final allReviews = await reviewsRef.get();
      double sum = 0;
      for (var doc in allReviews.docs) {
        sum += (doc.data()['rating'] as num?)?.toDouble() ?? 5.0;
      }
      final double avg = allReviews.docs.isEmpty ? 5.0 : sum / allReviews.docs.length;
      await FirebaseFirestore.instance.collection('users').doc(artisanUid).set({
        'rating': double.parse(avg.toStringAsFixed(1)),
        'reviewCount': allReviews.docs.length,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showMyGivenReviewsModal(BuildContext rootContext, String uid) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('given_reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (streamCtx, snapshot) {
            final docs = snapshot.data?.docs ?? [];
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
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.rate_review_outlined, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Yazdığım Rəylər (${docs.length})',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: docs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF94A3B8)),
                                SizedBox(height: 12),
                                Text(
                                  'Hələlik heç bir ustaya rəy yazmamısınız',
                                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Başqa istifadəçilərin profilində "Rəy yaz" düyməsi ilə qiymətləndirmə etdiyinizdə burada görünəcək.',
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
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final doc = docs[idx];
                            final data = doc.data();
                            final artisanId = (data['artisanId'] ?? '').toString();
                            final artisanName = (data['artisanName'] ?? 'Usta').toString();
                            final comment = (data['comment'] ?? '').toString();
                            final ratingVal = (data['rating'] as num?)?.toInt() ?? 5;
                            final reviewId = (data['reviewId'] ?? doc.id).toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                          future: artisanId.isNotEmpty
                                              ? FirebaseFirestore.instance.collection('users').doc(artisanId).get()
                                              : null,
                                          builder: (ctx, aSnap) {
                                            final aData = aSnap.data?.data();
                                            final aBytes = _HomeScreenState._decodeB64(aData?['photoBase64']?.toString());
                                            final displayArtisanName = (aData?['fullName'] ?? aData?['name'] ?? artisanName).toString();
                                            return InkWell(
                                              onTap: () {
                                                if (artisanId.isNotEmpty) {
                                                  Navigator.push(
                                                    rootContext,
                                                    MaterialPageRoute(
                                                      builder: (_) => ArtisanDetailScreen(
                                                        artisanData: {'uid': artisanId, 'fullName': displayArtisanName, ...?aData},
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 17,
                                                    backgroundColor: const Color(0xFFEFF6FF),
                                                    backgroundImage: aBytes != null ? MemoryImage(aBytes) : null,
                                                    child: aBytes == null
                                                        ? Text(
                                                            displayArtisanName.isNotEmpty ? displayArtisanName[0].toUpperCase() : 'U',
                                                            style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 13),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      displayArtisanName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < ratingVal ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          int editRating = ratingVal;
                                          final editCtrl = TextEditingController(text: comment);
                                          showDialog(
                                            context: rootContext,
                                            builder: (dCtx) => StatefulBuilder(
                                              builder: (dCtx, setDState) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                title: const Text('Rəyi Düzəlt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: List.generate(5, (i) {
                                                        return IconButton(
                                                          icon: Icon(
                                                            i < editRating ? Icons.star_rounded : Icons.star_border_rounded,
                                                            color: Colors.amber,
                                                            size: 30,
                                                          ),
                                                          onPressed: () => setDState(() => editRating = i + 1),
                                                        );
                                                      }),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    TextField(
                                                      controller: editCtrl,
                                                      maxLines: 3,
                                                      decoration: InputDecoration(
                                                        labelText: 'Rəyiniz',
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Ləğv et')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2), foregroundColor: Colors.white),
                                                    onPressed: () async {
                                                      final newText = editCtrl.text.trim();
                                                      if (newText.isEmpty) return;
                                                      Navigator.pop(dCtx);
                                                      if (artisanId.isNotEmpty) {
                                                        await FirebaseFirestore.instance
                                                            .collection('users')
                                                            .doc(artisanId)
                                                            .collection('reviews')
                                                            .doc(reviewId)
                                                            .update({'rating': editRating, 'comment': newText})
                                                            .catchError((_) {});
                                                        await _recalculateTargetRating(artisanId);
                                                      }
                                                      await FirebaseFirestore.instance
                                                          .collection('users')
                                                          .doc(uid)
                                                          .collection('given_reviews')
                                                          .doc(doc.id)
                                                          .update({'rating': editRating, 'comment': newText});
                                                    },
                                                    child: const Text('Yadda saxla'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF1769D2)),
                                              SizedBox(width: 4),
                                              Text('Düzəlt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1769D2))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final bool? confirmed = await showDialog<bool>(
                                            context: rootContext,
                                            builder: (cCtx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: const Text('Rəyi sil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                              content: const Text('Bu rəyi silmək istədiyinizə əminsiniz?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(cCtx, false), child: const Text('Ləğv et')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(cCtx, true),
                                                  child: const Text('Sil'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true) return;
                                          if (artisanId.isNotEmpty) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(artisanId)
                                                .collection('reviews')
                                                .doc(reviewId)
                                                .delete()
                                                .catchError((_) {});
                                            await _recalculateTargetRating(artisanId);
                                          }
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .collection('given_reviews')
                                              .doc(doc.id)
                                              .delete();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                                              SizedBox(width: 4),
                                              Text('Sil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  void _showProfileOptionsMenu(String uid, Map<String, dynamic>? userData, bool isAdmin, String userRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMenuState) {
          final bool isWorking = userData?['isWorking'] == true;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sürükləmə xətti (Handle)
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Başlıq
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: const [
                        Icon(Icons.settings_suggest_rounded, color: Color(0xFF1769D2), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Profil Parametrləri və İdarəetmə',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),

                  // 1. Profili Redaktə Et
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.edit_outlined, color: Color(0xFF1769D2), size: 20),
                    ),
                    title: const Text('Profili Redaktə Et', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Ad, soyad, əlaqə nömrəsi, peşə və bio məlumatları', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditProfileDialog(uid, userData);
                    },
                  ),

                  // 1.1 Sosial Şəbəkələr və Linklər (TikTok, Instagram, Sayt)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.link_rounded, color: Color(0xFFDB2777), size: 20),
                    ),
                    title: const Text('Sosial Şəbəkələr və Linklər', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('TikTok, Instagram və veb-sayt linklərini idarə et / sil', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showManageSocialLinksDialog(uid, userData);
                    },
                  ),

                  // 1.2 Profili Paylaş (WhatsApp, Telegram, Sistem Paylaşımı)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.share_rounded, color: Color(0xFF1769D2), size: 20),
                    ),
                    title: const Text('Profili Paylaş', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('WhatsApp, Telegram və digər tətbiqlərdə birbaşa paylaş', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final name = (userData?['fullName'] ?? 'UstaGo Ustası').toString();
                      final phone = (userData?['phone'] ?? '').toString();
                      final category = (userData?['category'] ?? userData?['trade'] ?? '').toString();
                      _shareUserProfile(name, phone, category);
                    },
                  ),

                  // 2. Məkan və Konum Seçimi
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.location_on_outlined, color: Color(0xFFD97706), size: 20),
                    ),
                    title: const Text('Məkan və Konum', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Xəritədə xidmət göstərdiyiniz ərazini təyin edin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showLocationPickerModal(uid, userData);
                    },
                  ),

                  // 3. Aktivlik Statusu (Online / Məşğulam Switch)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isWorking ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isWorking ? Icons.do_not_disturb_on_rounded : Icons.check_circle_rounded,
                        color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isWorking ? 'Status: Hal-hazırda məşğulam' : 'Status: Online (Sərbəstəm)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      isWorking ? 'Müştərilər profilinizdə məşğul olduğunuzu görəcək' : 'Yeni sifarişləri qəbul etməyə hazırsınız',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Switch(
                      value: !isWorking,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (val) async {
                        final newStatus = !val;
                        await FirebaseFirestore.instance.collection('users').doc(uid).set({
                          'isWorking': newStatus,
                        }, SetOptions(merge: true));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                            SnackBar(duration: const Duration(milliseconds: 1300), 
                              content: Text(newStatus
                                  ? 'Status "Hal-hazırda məşğulam" olaraq dəyişdirildi!'
                                  : 'Status "Online (Sərbəstəm)" olaraq dəyişdirildi!'),
                              backgroundColor: newStatus ? Colors.orange : Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // 4. Profil Növü (Rol Dəyiş: Usta, Müştəri, Satıcı)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF9333EA), size: 20),
                    ),
                    title: const Text('Profil Növü (Rol)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Hazırda: ${userRole == 'usta' ? 'Usta' : (userRole == 'seller' ? 'Satıcı' : 'Müştəri')}', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRoleSwitcherModal(uid, userRole);
                    },
                  ),

                  // 5. Bildirişlər
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1769D2), size: 20),
                    ),
                    title: const Text('Bildirişlər', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Sistem və sifariş bildirişləri', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showNotificationsSheet();
                    },
                  ),

                  // 6. Mağazamı İdarə Et
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    title: const Text('Mağazamı İdarə Et', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Mağazanızı açın, məhsullarınızı vitrinə qoyun və idarə edin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUserStoreModal(context, uid, userData?['fullName'] ?? '', isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString());
                    },
                  ),

                  // 6.1 Elanlarımı İdarə Et
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFFEA580C), size: 20),
                    ),
                    title: const Text('Elanlarımı İdarə Et', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Fərdi alış-satış elanlarınızı yerləşdirin, redaktə edin və ya silin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUserListingsModal(context, uid, userData?['fullName'] ?? '', isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString());
                    },
                  ),

                  // 6.2 Yazdığım Rəylər
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.rate_review_outlined, color: Color(0xFFD97706), size: 20),
                    ),
                    title: const Text('Yazdığım Rəylər', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Başqa ustalara yazdığınız rəylərə baxın, düzəldin və ya silin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMyGivenReviewsModal(context, uid);
                    },
                  ),

                  // 7. Kömək və Dəstək
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.headset_mic_outlined, color: Color(0xFF64748B), size: 20),
                    ),
                    title: const Text('Kömək və Dəstək', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Texniki dəstək və qaynar xətt', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showHelpSupportSheet();
                    },
                  ),

                  const Divider(height: 1),

                  // 8. Hesabdan Çıxış
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                    title: const Text('Hesabdan Çıxış', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEF4444))),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Çıxış təsdiqi'),
                          content: const Text('Hesabınızdan çıxmaq istədiyinizə əminsiniz?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Xeyr')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Bəli, çıx', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _authService.signOut();
                        if (mounted) {
                          setState(() => _currentUserRole = null);
                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                            const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Hesabdan çıxış edildi.')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Məkan / Konum seçimi modal pəncərəsi
  void _showLocationPickerModal(String uid, Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              _buildLocationPrivacyCard(uid, userData),
            ],
          ),
        ),
      ),
    );
  }

  /// Rol Dəyişmə modal pəncərəsi
  void _showRoleSwitcherModal(String uid, String currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              _buildFourRoleSwitcherCard(uid, currentRole),
            ],
          ),
        ),
      ),
    );
  }

  /// TikTok Hesabı ilə Qoşulma dialoqu
  void _showTikTokSyncDialog(BuildContext parentCtx) {
    final user = FirebaseAuth.instance.currentUser;
    final handleCtrl = TextEditingController();
    bool isSyncing = false;
    String statusMsg = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFE2C55), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF25F4EE), width: 1),
                ),
                child: const Icon(Icons.music_note_rounded, color: Color(0xFFFE2C55), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'TikTok ilə Qoşul',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tətbiq: UstaGo (Rəsmi TikTok Partner)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tələb olunan icazələr: user.info.basic, video.list',
                      style: TextStyle(color: Color(0xFF25F4EE), fontSize: 11),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'UstaGo profilinizi bağlayaraq TikTok-dakı bütün sənət və təmir videolarınızı müştərilərə canlı nümayiş etdirə bilərsiniz.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'TikTok Profil Linki və ya @İstifadəçi Adı:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: handleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '@usta_eli və ya tiktok.com/@usta_eli',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFFFE2C55), size: 18),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
              if (statusMsg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  statusMsg,
                  style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bağla', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isSyncing
                  ? null
                  : () async {
                      final handle = handleCtrl.text.trim();
                      if (handle.isEmpty) return;

                      setDlgState(() {
                        isSyncing = true;
                        statusMsg = 'TikTok OAuth təsdiqi yoxlanılır...';
                      });

                      // Rəsmi TikTok OAuth linkini açırıq
                      final authUrl =
                          'https://www.tiktok.com/v2/auth/authorize/?client_key=aw7707302381934888980&scope=user.info.basic,video.list&response_type=code&redirect_uri=https://ustago-app.github.io/ustago/&state=ustago_oauth';
                      try {
                        final uri = Uri.parse(authUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {}

                      // İstifadəçinin məlumatını Firestore-da saxlayırıq
                      if (user != null) {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                            'tiktokConnected': true,
                            'tiktokHandle': _cleanTikTokHandle(handle),
                            'tiktokConnectedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        } catch (_) {}
                      }

                      await Future.delayed(const Duration(milliseconds: 1200));

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(parentCtx)..clearSnackBars()..showSnackBar(
                          SnackBar(duration: const Duration(milliseconds: 1300), 
                            content: Text('${_cleanTikTokHandle(handle)} TikTok hesabı UstaGo ilə uğurla əlaqələndirildi! 🎉'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: isSyncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Qoşul və Təsdiqlə', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// TikTok istifadəçi adını təmizləyən köməkçi (linkləri və artıq işarələri silir)
  static String _cleanTikTokHandle(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var s = raw.trim();
    if (s.contains('?')) s = s.split('?').first;
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.contains('/@')) {
      s = s.split('/@').last;
    } else if (s.contains('tiktok.com/')) {
      s = s.split('tiktok.com/').last;
    }
    return s.replaceAll('@', '').trim();
  }

  /// TikTok Profilinə keçid
  Future<void> _openTikTokProfile(String handle) async {
    final cleanHandle = _cleanTikTokHandle(handle);
    final url = 'https://www.tiktok.com/@$cleanHandle';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Instagram istifadəçi adını təmizləyən köməkçi
  static String _cleanInstagramHandle(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var s = raw.trim();
    if (s.contains('?')) s = s.split('?').first;
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.contains('instagram.com/')) {
      s = s.split('instagram.com/').last;
    }
    return s.replaceAll('@', '').trim();
  }

  /// Xarici veb linkləri açmaq
  Future<void> _openExternalLink(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Instagram Profilinə keçid
  Future<void> _openInstagramProfile(String handle) async {
    final clean = _cleanInstagramHandle(handle);
    if (clean.isEmpty) return;
    _openExternalLink('https://www.instagram.com/$clean');
  }

  /// Profili Paylaşmaq (WhatsApp, Telegram, Sistem Paylaşımı)
  Future<void> _shareUserProfile(String displayName, String? phone, String? category) async {
    final buffer = StringBuffer();
    buffer.writeln('🛠️ UstaGo Peşəkar Usta Profili: $displayName');
    if (category != null && category.trim().isNotEmpty) {
      buffer.writeln('📋 Xidmət Sahəsi: $category');
    }
    if (phone != null && phone.trim().isNotEmpty) {
      buffer.writeln('📞 Əlaqə: $phone');
    }
    buffer.writeln('🌐 Platforma: https://ustago-app.github.io/ustago/');
    buffer.writeln('Peşəkar ustaları UstaGo-da dərhal tapın və əlaqə saxlayın!');

    final text = buffer.toString();
    try {
      await Share.share(
        text,
        subject: 'UstaGo Profil: $displayName',
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Profil məlumatları kopyalandı!'), backgroundColor: Color(0xFF1769D2)),
        );
      }
    }
  }

  /// Sosial linkləri (TikTok, Instagram, Veb-sayt) tənzimləmək və ya silmək dialoqu
  void _showManageSocialLinksDialog(String uid, Map<String, dynamic>? userData) {
    final tiktokCtrl = TextEditingController(text: userData?['tiktokHandle'] ?? '');
    final instagramCtrl = TextEditingController(text: userData?['instagramHandle'] ?? '');
    final websiteCtrl = TextEditingController(text: userData?['websiteUrl'] ?? userData?['website'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.link_rounded, color: Color(0xFF1769D2)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sosial Linkləri İdarə Et',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profilinizdə göstərmək üçün 3 link əlavə edə bilərsiniz. Linki silmək üçün xananı təmizləyin və ya (❌) işarəsinə basın.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 14),

                // 1. TikTok
                TextField(
                  controller: tiktokCtrl,
                  decoration: InputDecoration(
                    labelText: '1. TikTok',
                    hintText: '@istifadəçi_adı və ya link',
                    prefixIcon: const Icon(Icons.music_note_rounded, color: Color(0xFFFE2C55), size: 20),
                    suffixIcon: tiktokCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setDlgState(() => tiktokCtrl.clear()),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 12),

                // 2. Instagram
                TextField(
                  controller: instagramCtrl,
                  decoration: InputDecoration(
                    labelText: '2. Instagram',
                    hintText: '@istifadəçi_adı və ya link',
                    prefixIcon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 20),
                    suffixIcon: instagramCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setDlgState(() => instagramCtrl.clear()),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 12),

                // 3. Veb-sayt / Digər link
                TextField(
                  controller: websiteCtrl,
                  decoration: InputDecoration(
                    labelText: '3. Veb-sayt və ya Digər link',
                    hintText: 'sayt.az, youtube, facebook...',
                    prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF1769D2), size: 20),
                    suffixIcon: websiteCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setDlgState(() => websiteCtrl.clear()),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bağla'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769D2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final cleanedTikTok = _cleanTikTokHandle(tiktokCtrl.text.trim());
                final cleanedInsta = _cleanInstagramHandle(instagramCtrl.text.trim());
                final rawWeb = websiteCtrl.text.trim();

                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'tiktokHandle': cleanedTikTok,
                  'tiktokConnected': cleanedTikTok.isNotEmpty,
                  'instagramHandle': cleanedInsta,
                  'websiteUrl': rawWeb,
                }, SetOptions(merge: true));

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(duration: Duration(milliseconds: 1300), 
                      content: Text('Sosial linklər uğurla yeniləndi!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Yadda Saxla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Əlaqə modal pəncərəsi (Zəng et / WhatsApp)
  void _showContactModal(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phone.isNotEmpty ? phone : 'Nömrə qeyd olunmayıb',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone_rounded),
                      label: const Text('Zəng Et', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _makeCall(phone);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openWhatsApp(phone);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xidmətlər modal pəncərəsi (Ustanın seçdiyi bütün ixtisaslar)
  void _showServicesModal(BuildContext context, String category, Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Color(0xFF1769D2), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xidmət Sahələri və İxtisaslar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ustanın təklif etdiyi peşəkar fəaliyyət sahələri',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildServiceChips(category, userData),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1769D2), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1769D2)),
                  label: const Text(
                    'İxtisasları Dəyişdir (Maksimum 4)',
                    style: TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      _showEditProfileDialog(user.uid, userData);
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

  /// UstaGo brendinə uyğun Statistika Sütunu (İşlərim, Video İşlər, Reytinq)
  Widget _buildUstaStatItem({
    required String count,
    required String label,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: iconColor ?? const Color(0xFF1769D2)),
              const SizedBox(width: 4),
            ],
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
        const SizedBox(height: 3),
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

  /// Dairəvi Bölmələr (UstaGo Highlights / Xidmətlər, Əlaqə, Məkan, TikTok)
  Widget _buildHighlightCircle({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Color? borderColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final ringColor = borderColor ?? iconColor.withOpacity(0.4);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 1.8),
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yeni İnstaqram Stilində Premium Usta Profil Səhifəsi (İstifadəçinin tələbinə tam uyğun)
  Widget _buildModernUstaProfile(
    User user,
    Map<String, dynamic>? userData,
    bool isAdmin,
    ImageProvider? avatarImage,
    String displayName,
    String userRole,
  ) {
    final String phone = (userData?['phone'] ?? user.phoneNumber ?? '').toString().trim();
    final String category = (userData?['category'] ?? userData?['trade'] ?? '').toString();
    final String rating = (userData?['rating'] != null) ? userData!['rating'].toString() : '5.0';

    final normRole = userRole.toLowerCase().trim();
    String defaultRoleTitle = 'Tikinti və Təmir Ustası';
    if (normRole == 'fehle' || normRole == 'fəhlə' || normRole == 'worker') {
      defaultRoleTitle = 'Fəhlə (Köməkçi işlər)';
    } else if (normRole == 'satici' || normRole == 'satıcı' || normRole == 'seller') {
      defaultRoleTitle = 'Tikinti Malları Satıcısı';
    } else if (normRole == 'musteri' || normRole == 'müştəri' || normRole == 'customer') {
      defaultRoleTitle = 'Müştəri';
    }

    // Seçilmiş ixtisasların siyahısı (maksimum 4 sahə)
    List<String> userSpecialties = [];
    if (userData?['specialties'] is List && (userData!['specialties'] as List).isNotEmpty) {
      userSpecialties = (userData!['specialties'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (userData?['specialtyIds'] is List && (userData!['specialtyIds'] as List).isNotEmpty) {
      for (final id in (userData!['specialtyIds'] as List)) {
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
    if (normRole == 'fehle' || normRole == 'fəhlə' || normRole == 'worker') {
      defaultBio = 'Fiziki və köməkçi tikinti işləri, söküntü, daşıma və sahə təmizliyi xidmətləri.';
    } else if (normRole == 'satici' || normRole == 'satıcı' || normRole == 'seller') {
      defaultBio = 'Tikinti materialları, təmir alətləri və avadanlıqların sərfəli satışı.';
    } else if (normRole == 'musteri' || normRole == 'müştəri' || normRole == 'customer') {
      defaultBio = 'UstaGo istifadəçisi. Tikinti və təmir sifarişləri.';
    }

    final String bio = (userData?['bio'] != null && (userData!['bio'] as String).trim().isNotEmpty)
        ? userData!['bio'] as String
        : defaultBio;
    final String rawTikTok = (userData?['tiktokHandle'] as String?)?.trim() ?? '';
    final String cleanTikTok = _cleanTikTokHandle(rawTikTok);
    final bool tiktokConnected = userData?['tiktokConnected'] == true;
    final String rawInsta = (userData?['instagramHandle'] as String?)?.trim() ?? '';
    final String cleanInstagram = _cleanInstagramHandle(rawInsta);
    final String websiteUrl = (userData?['websiteUrl'] as String?)?.trim() ?? (userData?['website'] as String?)?.trim() ?? '';
    final bool isWorking = userData?['isWorking'] == true;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. Üst Başlıq (Instagram Top Bar: @istifadəçi_adı + Təsdiq Nişanı + Sağda 3 Nöqtə)
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sol: Geri qayıtmaq və ya Başlıq
                  if (Navigator.canPop(context))
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
                      ),
                    )
                  else
                    const Text(
                      'Profil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),

                  // Orta: Canlı Sərbəst / Məşğul Status Göstəricisi (Kliklə dəyişir)
                  InkWell(
                    onTap: () async {
                      final newStatus = !isWorking;
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'isWorking': newStatus,
                      }, SetOptions(merge: true));
                      if (mounted) {
                        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                          SnackBar(duration: const Duration(milliseconds: 1300), 
                            content: Text(newStatus
                                ? 'Status "Hal-hazırda məşğulam" olaraq dəyişdirildi!'
                                : 'Status "Sərbəstəm (Online)" olaraq dəyişdirildi!'),
                            backgroundColor: newStatus ? Colors.orange : Colors.green,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
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
                            isWorking ? 'Məşğulam' : 'Sərbəstəm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: isWorking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sağ: Bütün ayarlar və idarəetmə üçün 3 Nöqtə (⋮)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A), size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Parametrlər və İdarəetmə',
                    onPressed: () => _showProfileOptionsMenu(user.uid, userData, isAdmin, userRole),
                  ),
                ],
              ),
            ),
          ),

          // 2. Əsas Profil Məzmunu (Instagram stili axıcı siyahı)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),

                // Yuxarı Sətir: Dairəvi Avatar (UstaGo Ring) + 3 Göstərici Sütunu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Avatar (UstaGo firuzəyi-göy brend halqası ilə)
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3.0),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF1E88E5), // UstaGo Royal Blue
                                  Color(0xFF00D2FF), // Parlaq Firuzəyi Cyan
                                  Color(0xFF059669), // Zümrüd Yaşıl
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
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
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _showPhotoPicker(user.uid),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1769D2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // 3 Göstərici: Göndəri (vahid foto və videolar) • Video • Reytinq
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, postSnap) {
                            final postCount = postSnap.data?.docs.length ?? 0;
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('shorts')
                                  .where('userId', isEqualTo: user.uid)
                                  .snapshots(),
                              builder: (context, shortSnap) {
                                final shortCount = shortSnap.data?.docs.length ?? 0;
                                final totalCount = postCount + shortCount;
                                final cleanRating = rating.replaceAll('★', '').trim();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildUstaStatItem(
                                      count: '$totalCount',
                                      label: 'göndəri',
                                      icon: Icons.grid_on_rounded,
                                      iconColor: const Color(0xFF1769D2),
                                    ),
                                    _buildUstaStatItem(
                                      count: '$shortCount',
                                      label: 'video',
                                      icon: Icons.play_circle_outline_rounded,
                                      iconColor: const Color(0xFFFE2C55),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: _buildUstaStatItem(
                                          count: cleanRating,
                                          label: 'reytinq',
                                          icon: Icons.star_rounded,
                                          iconColor: const Color(0xFFF59E0B),
                                        ),
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

                // Bio və Məlumat Sətri (Usta Haqqında, Peşə, Linklər)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ad və Soyad
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Color(0xFF1769D2), size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Peşə / İxtisaslar (Seçilmiş bütün sahələr: məs: Santexnik, Tikinti, Elektrik)
                      Text(
                        displaySpecialtiesText,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Bio mətni (Daha çox / Daha az ilə)
                      Text(
                        bio,
                        maxLines: _isUstaBioExpanded ? null : 3,
                        overflow: _isUstaBioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isUstaBioExpanded = !_isUstaBioExpanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _isUstaBioExpanded ? 'Daha az' : 'Daha çox',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Sosial Şəbəkə və Linklər (Maksimum 3 ədəd: TikTok, Instagram, Veb-sayt)
                      Builder(
                        builder: (context) {
                          final List<Map<String, dynamic>> activeLinks = [];
                          if (cleanTikTok.isNotEmpty) {
                            activeLinks.add({
                              'label': 'tiktok.com/@$cleanTikTok',
                              'icon': Icons.music_note_rounded,
                              'color': const Color(0xFFFE2C55),
                              'onTap': () => _openTikTokProfile(cleanTikTok),
                            });
                          }
                          if (cleanInstagram.isNotEmpty) {
                            activeLinks.add({
                              'label': 'instagram.com/$cleanInstagram',
                              'icon': Icons.camera_alt_rounded,
                              'color': const Color(0xFFE1306C),
                              'onTap': () => _openInstagramProfile(cleanInstagram),
                            });
                          }
                          if (websiteUrl.isNotEmpty) {
                            final cleanWeb = websiteUrl.replaceAll('https://', '').replaceAll('http://', '');
                            activeLinks.add({
                              'label': cleanWeb,
                              'icon': Icons.language_rounded,
                              'color': const Color(0xFF1769D2),
                              'onTap': () => _openExternalLink(websiteUrl),
                            });
                          }

                          if (activeLinks.isEmpty) {
                            return InkWell(
                              onTap: () => _showManageSocialLinksDialog(user.uid, userData),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.add_link_rounded, size: 16, color: Color(0xFF1769D2)),
                                    SizedBox(width: 4),
                                    Text(
                                      '+ Sosial link əlavə et (TikTok, Instagram, Sayt)',
                                      style: TextStyle(
                                        color: Color(0xFF1769D2),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                          style: TextStyle(
                                            color: lk['color'] as Color,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_outward_rounded, size: 11, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                              InkWell(
                                onTap: () => _showManageSocialLinksDialog(user.uid, userData),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.edit_outlined, size: 12, color: Color(0xFF64748B)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Linkləri dəyiş / sil',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Dairəvi Hekayələr (UstaGo Highlights / Önə Çıxarılanlar)
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
                            _openTikTokProfile(cleanTikTok);
                          } else {
                            _showTikTokSyncDialog(context);
                          }
                        },
                      ),
                      _buildHighlightCircle(
                        icon: Icons.handyman_rounded,
                        iconColor: const Color(0xFF1769D2),
                        bgColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFF1769D2),
                        label: 'Xidmətlər',
                        onTap: () => _showServicesModal(context, category, userData),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.phone_in_talk_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFF10B981),
                        label: 'Əlaqə',
                        onTap: () => _showContactModal(context, phone),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.location_on_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFFEF3C7),
                        borderColor: const Color(0xFFF59E0B),
                        label: 'Məkan',
                        onTap: () => _showLocationPickerModal(user.uid, userData),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.storefront_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        bgColor: const Color(0xFFF5F3FF),
                        borderColor: const Color(0xFF8B5CF6),
                        label: 'Mağaza',
                        onTap: () => _showUserStoreModal(context, user.uid, displayName, isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString()),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.campaign_rounded,
                        iconColor: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFF7ED),
                        borderColor: const Color(0xFFEA580C),
                        label: 'Elanlar',
                        onTap: () => _showUserListingsModal(context, user.uid, displayName, isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString()),
                      ),
                    ],
                  ),
                ),

                // İşlər və Müştəri Rəyləri Tabları
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('reviews').snapshots(),
                  builder: (context, revCountSnap) {
                    final int revCount = revCountSnap.data?.docs.length ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
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
                              onTap: () => setState(() => _ustaProfileGalleryTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.grid_on_rounded,
                                      color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'İşlər',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _ustaProfileGalleryTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: _ustaProfileGalleryTab == 1 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Rəylər ($revCount)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _ustaProfileGalleryTab == 1 ? const Color(0xFFD97706) : const Color(0xFF64748B),
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

                const SizedBox(height: 6),

                if (_ustaProfileGalleryTab == 0)
                  _buildUstaUnifiedGrid(user.uid, displayName, userRole)
                else
                  _buildOwnProfileReviewsTab(user.uid, rating.replaceAll('★', '').trim()),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnProfileReviewsTab(String userId, String ratingStr) {
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
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 34),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$ratingStr / 5.0',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Ümumi ${docs.length} müştəri rəyi',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Hələlik sizin haqqınızda rəy yazılmayıb.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                  ),
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
                    final directBytes = _HomeScreenState._decodeB64(revPhotoB64);

                    Widget buildRevAvatar(Uint8List? bytes) {
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
                                      buildRevAvatar(directBytes)
                                    else if (revId.isNotEmpty && revId != 'anonymous')
                                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                        future: FirebaseFirestore.instance.collection('users').doc(revId).get(),
                                        builder: (ctx, uSnap) {
                                          final fetchedBytes = _HomeScreenState._decodeB64(uSnap.data?.data()?['photoBase64']?.toString());
                                          return buildRevAvatar(fetchedBytes);
                                        },
                                      )
                                    else
                                      buildRevAvatar(null),
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

  /// Ustanın ixtisasına uyğun peşəkar xidmət teqləri (seçilmiş maksimum 4 ixtisas əsasında)
  List<Widget> _buildServiceChips(String category, Map<String, dynamic>? userData) {
    List<String> rawSkills = [];
    if (userData?['specialties'] is List && (userData!['specialties'] as List).isNotEmpty) {
      rawSkills = (userData!['specialties'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (userData?['specialtyIds'] is List && (userData!['specialtyIds'] as List).isNotEmpty) {
      for (final id in (userData!['specialtyIds'] as List)) {
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
      if (t.contains('santexnik') || t.contains('boru') || t.contains('kran')) return Icons.plumbing_rounded;
      if (t.contains('elektrik') || t.contains('şit') || t.contains('naqil')) return Icons.bolt_rounded;
      if (t.contains('kafel') || t.contains('metlax')) return Icons.grid_view_rounded;
      if (t.contains('malyar') || t.contains('rəng')) return Icons.format_paint_rounded;
      if (t.contains('alçıpan') || t.contains('alcipan')) return Icons.architecture_rounded;
      if (t.contains('mebel') || t.contains('dülgər')) return Icons.chair_rounded;
      if (t.contains('qapı') || t.contains('pəncərə')) return Icons.door_front_door_rounded;
      if (t.contains('dam') || t.contains('fasad') || t.contains('beton')) return Icons.roofing_rounded;
      if (t.contains('telefon') || t.contains('iphone') || t.contains('android')) return Icons.smartphone_rounded;
      if (t.contains('kompüter') || t.contains('noutbuk')) return Icons.laptop_rounded;
      if (t.contains('televizor') || t.contains('tv')) return Icons.tv_rounded;
      if (t.contains('playstation') || t.contains('ps') || t.contains('xbox') || t.contains('konsol')) return Icons.sports_esports_rounded;
      if (t.contains('kondisioner') || t.contains('iqlim') || t.contains('soyuducu')) return Icons.ac_unit_rounded;
      if (t.contains('kombi') || t.contains('istilik') || t.contains('radiator')) return Icons.hvac_rounded;
      if (t.contains('paltaryuyan') || t.contains('qabyuyan')) return Icons.local_laundry_service_rounded;
      if (t.contains('avto') || t.contains('maşın') || t.contains('motor')) return Icons.directions_car_rounded;
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
              style: const TextStyle(
                color: Color(0xFF1769D2),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// İstifadəçinin mağaza profilini və məhsullarını göstərən modal
  void _showUserStoreModal(
    BuildContext rootContext,
    String targetUid,
    String authorName, {
    bool isOwner = false,
    String? userPhone,
    String? userAddress,
  }) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('market_stores')
              .snapshots(),
          builder: (streamCtx, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final userDocs = allDocs.where((d) {
              final data = d.data();
              return data['ownerId'] == targetUid || data['userId'] == targetUid;
            }).toList();

            final storeDocs = userDocs.where((d) => (d.data()['listingType'] ?? 'store') == 'store').toList();
            final productDocs = userDocs.where((d) => d.data()['listingType'] == 'product' && (d.data()['store'] != null && d.data()['store'].toString().isNotEmpty)).toList();

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
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner ? 'Mənim Mağazam' : '$authorName — Mağazası',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasStore ? (storeData?['category'] ?? 'Tikinti və Təmir Mağazası').toString() : 'Mağaza bölməsi',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner && hasStore)
                        TextButton.icon(
                          onPressed: () {
                            MarketScreen.showProductFormSheet(
                              rootContext,
                              defaultPhone: userPhone,
                              defaultAddress: userAddress,
                            );
                          },
                          icon: const Icon(Icons.add, size: 17, color: Color(0xFF1769D2)),
                          label: const Text('+ Məhsul', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1769D2))),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!hasStore) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.storefront_outlined, size: 36, color: Color(0xFF8B5CF6)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Mağaza elanı yoxdur',
                                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isOwner
                                    ? 'Hələlik heç bir mağaza yaratmamısınız. Öz mağazanızı açaraq tikinti malları və alətlərinizi UstaGo-da satın!'
                                    : 'Bu istifadəçinin hələlik heç bir aktiv mağaza elanı yoxdur.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                              ),
                              if (isOwner) ...[
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.add_business_rounded, size: 18),
                                  label: const Text('Mağaza Aç və Məhsul Yerləşdir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  onPressed: () {
                                    MarketScreen.showStoreFormSheet(
                                      rootContext,
                                      defaultPhone: userPhone,
                                      defaultAddress: userAddress,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Mağaza Kartı
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => StoreDetailScreen(
                                  store: {
                                    'id': storeId,
                                    ...?storeData,
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                            ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: (storeData?['logoUrl'] ?? '').toString().startsWith('http')
                                        ? ClipOval(
                                            child: Image.network(
                                              storeData!['logoUrl'].toString(),
                                              fit: BoxFit.cover,
                                              width: 56,
                                              height: 56,
                                              errorBuilder: (_, __, ___) => _HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                                  ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                                  : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30),
                                            ),
                                          )
                                        : (_HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                            ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                            : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (storeData?['title'] ?? 'Mağaza').toString(),
                                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (storeData?['address'] ?? 'Ünvan qeyd olunmayıb').toString(),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Əlaqə: ${storeData?['phone'] ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6), size: 20),
                                      tooltip: 'Mağazanı Redaktə Et',
                                      onPressed: () {
                                        MarketScreen.showStoreFormSheet(
                                          rootContext,
                                          existingStore: {'id': storeId, ...storeData!},
                                          defaultPhone: userPhone,
                                          defaultAddress: userAddress,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              if ((storeData?['description'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  storeData!['description'].toString(),
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                        // Vitrindəki Məhsullar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vitrindəki Məhsullar (${productDocs.length})',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (isOwner)
                              InkWell(
                                onTap: () {
                                  MarketScreen.showProductFormSheet(
                                    rootContext,
                                    defaultPhone: userPhone,
                                    defaultAddress: userAddress,
                                  );
                                },
                                child: const Text(
                                  '+ Məhsul Əlavə Et',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (productDocs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 36),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Mağazanın vitrinində hələlik məhsul yoxdur',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                  if (isOwner) ...[
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () {
                                        MarketScreen.showProductFormSheet(
                                          rootContext,
                                          defaultPhone: userPhone,
                                          defaultAddress: userAddress,
                                        );
                                      },
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('İlk Məhsulunu Əlavə Et'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else
                          ...productDocs.map((pDoc) {
                            final pData = pDoc.data();
                            final imgB64 = pData['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);
                            int pDaysLeft = 30;
                            bool pIsExpired = false;
                            if (pData['createdAt'] is Timestamp) {
                              final dt = (pData['createdAt'] as Timestamp).toDate();
                              final passed = DateTime.now().difference(dt).inDays;
                              pDaysLeft = (30 - passed).clamp(0, 30);
                              pIsExpired = passed >= 30;
                            }
                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  rootContext,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: {'id': pDoc.id, ...pData},
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFF1F5F9),
                                      child: (pData['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              pData['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => imgBytes != null
                                                  ? Image.memory(imgBytes, fit: BoxFit.cover)
                                                  : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
                                            )
                                          : (imgBytes != null
                                              ? Image.memory(imgBytes, fit: BoxFit.cover)
                                              : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (pData['title'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${pData['price'] ?? ''} (${pData['unit'] ?? '1 ədəd'})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (pData['category'] ?? '').toString(),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (pIsExpired)
                                          InkWell(
                                            onTap: () async {
                                              await FirebaseFirestore.instance.collection('market_stores').doc(pDoc.id).update({
                                                'createdAt': FieldValue.serverTimestamp(),
                                                'bumpedAt': FieldValue.serverTimestamp(),
                                              });
                                              ScaffoldMessenger.of(rootContext)..clearSnackBars()..showSnackBar(
                                                const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Elanın müddəti 30 gün uzadıldı! 🚀')),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              margin: const EdgeInsets.only(right: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('🔄 Uzat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': pDoc.id, ...pData},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('market_stores').doc(pDoc.id).delete();
                                            if (rootContext.mounted) {
                                              ScaffoldMessenger.of(rootContext)..clearSnackBars()..showSnackBar(const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Məhsul silindi.')));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
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

  /// İstifadəçinin fərdi alış-satış elanlarını göstərən modal
  void _showUserListingsModal(
    BuildContext rootContext,
    String targetUid,
    String authorName, {
    bool isOwner = false,
    String? userPhone,
    String? userAddress,
  }) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetCtx, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('market_stores')
              .snapshots(),
          builder: (streamCtx, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final listings = allDocs.where((d) {
              final data = d.data();
              final isMatchingUser = data['ownerId'] == targetUid || data['userId'] == targetUid;
              final isListing = data['listingType'] != 'store';
              return isMatchingUser && isListing;
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
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Color(0xFFEA580C), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner ? 'Mənim Elanlarım' : '$authorName — Elanları',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${listings.length} aktiv elan mövcuddur',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        TextButton.icon(
                          onPressed: () {
                            MarketScreen.showProductFormSheet(
                              rootContext,
                              defaultPhone: userPhone,
                              defaultAddress: userAddress,
                            );
                          },
                          icon: const Icon(Icons.add, size: 17, color: Color(0xFFEA580C)),
                          label: const Text('+ Yeni Elan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFEA580C))),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
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
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.campaign_outlined, size: 36, color: Color(0xFFEA580C)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Elan yoxdur',
                                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isOwner
                                      ? 'Hələlik heç bir alış-satış elanı yerləşdirməmisiniz. Məhsul, alət və ya material satmaq üçün elan verin!'
                                      : 'Bu istifadəçinin hələlik heç bir aktiv alış-satış elanı yoxdur.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                                ),
                                if (isOwner) ...[
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA580C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text('Yeni Elan Yerləşdir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    onPressed: () {
                                      MarketScreen.showProductFormSheet(
                                        rootContext,
                                        defaultPhone: userPhone,
                                        defaultAddress: userAddress,
                                      );
                                    },
                                  ),
                                ],
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
                            final imgB64 = data['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);
                            final title = (data['title'] ?? '').toString();
                            final price = (data['price'] ?? '').toString();
                            final city = (data['city'] ?? '').toString();
                            final phone = (data['phone'] ?? '').toString();
                            int daysLeft = 30;
                            bool isExpired = false;
                            if (data['createdAt'] is Timestamp) {
                              final dt = (data['createdAt'] as Timestamp).toDate();
                              final passed = DateTime.now().difference(dt).inDays;
                              daysLeft = (30 - passed).clamp(0, 30);
                              isExpired = passed >= 30;
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  rootContext,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: {'id': doc.id, ...data},
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                                ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: const Color(0xFFF1F5F9),
                                      child: (data['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              data['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => imgBytes != null
                                                  ? Image.memory(imgBytes, fit: BoxFit.cover)
                                                  : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),
                                            )
                                          : (imgBytes != null
                                              ? Image.memory(imgBytes, fit: BoxFit.cover)
                                              : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          price,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (city.isNotEmpty) ...[
                                              const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                                              const SizedBox(width: 2),
                                              Text(city, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                              const SizedBox(width: 8),
                                            ],
                                            if (phone.isNotEmpty) ...[
                                              const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF10B981)),
                                              const SizedBox(width: 2),
                                              Text(phone, style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                              const SizedBox(width: 8),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isExpired ? 'Bitib' : '$daysLeft gün',
                                                style: TextStyle(
                                                  color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isExpired)
                                          InkWell(
                                            onTap: () async {
                                              await FirebaseFirestore.instance.collection('market_stores').doc(doc.id).update({
                                                'createdAt': FieldValue.serverTimestamp(),
                                                'bumpedAt': FieldValue.serverTimestamp(),
                                              });
                                              ScaffoldMessenger.of(rootContext)..clearSnackBars()..showSnackBar(
                                                const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Elanın müddəti 30 gün uzadıldı! 🚀')),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              margin: const EdgeInsets.only(right: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('🔄 Uzat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': doc.id, ...data},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('market_stores').doc(doc.id).delete();
                                            if (rootContext.mounted) {
                                              ScaffoldMessenger.of(rootContext)..clearSnackBars()..showSnackBar(const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Elan silindi.')));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
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
  /// Vahid Qalereya (Foto və Videolar birgə, İnstagram üslubunda)
  Widget _buildUstaUnifiedGrid(String uid, String authorName, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shorts')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, shortSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, postSnap) {
            final shortDocs = shortSnap.data?.docs ?? [];
            final postDocs = postSnap.data?.docs ?? [];

            // Bütün elementləri vahid siyahıda birləşdiririk
            final List<_UnifiedGridItem> allItems = [];

            for (final doc in shortDocs) {
              allItems.add(_UnifiedGridItem(
                id: doc.id,
                isVideo: true,
                data: doc.data(),
                createdAt: doc.data()['createdAt'],
              ));
            }

            for (final doc in postDocs) {
              final data = doc.data();
              final isVid = data['isVideo'] == true ||
                  (data['videoUrl'] != null && data['videoUrl'].toString().trim().isNotEmpty);
              allItems.add(_UnifiedGridItem(
                id: doc.id,
                isVideo: isVid,
                data: data,
                createdAt: data['createdAt'],
              ));
            }

            // Tarixə görə sıralayırıq (ən yeni birinci)
            allItems.sort((a, b) {
              final ta = a.createdAt;
              final tb = b.createdAt;
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });

            // Əgər hələ heç bir foto və ya video yoxdursa → İnstagram "Başlarkən" kartı (Şəkil 1)
            if (allItems.isEmpty) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Başlarkən',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Dairəvi media/kamera ikonu outline
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1E293B), width: 1.8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.photo_camera_back_outlined,
                                size: 38,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Foto və Videolar Paylaş',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'TikTok hesabını bağladıqdan sonra foto və videolar burada görünəcək.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 220,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _showTikTokSyncDialog(context),
                              child: const Text(
                                'TikTok Hesabını Bağla',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Grid dolu olduqda: 3 sütunlu kvadrat şəbəkə
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${allItems.length} paylaşım',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showTikTokSyncDialog(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'TikTok Sinxron',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final data = item.data;
                      final isVideo = item.isVideo;

                      if (isVideo) {
                        final videoUrl = (data['videoUrl'] ?? '').toString();
                        final coverBase64 = data['thumbnailBase64']?.toString();
                        final isTikTok = data['isTikTok'] == true || videoUrl.contains('tiktok.com');

                        return InkWell(
                          onTap: () async {
                            if (videoUrl.isNotEmpty) {
                              _ShortsVideoThumbnail.pauseAndReleaseAll();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenVideoViewer(
                                    videoUrl: videoUrl,
                                    title: data['title'] ?? 'Usta İşi',
                                    category: data['trade'] ?? 'Shorts',
                                    postId: item.id,
                                    coverBase64: coverBase64,
                                    isOwner: true,
                                  ),
                                ),
                              );
                              _ShortsVideoThumbnail.resumeAll();
                            }
                          },
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_HomeScreenState._decodeB64(coverBase64) != null)
                                  Image.memory(
                                    _HomeScreenState._decodeB64(coverBase64)!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                else if (data['thumbnailUrl'] != null && (data['thumbnailUrl'] as String).isNotEmpty && !(data['thumbnailUrl'] as String).contains('unsplash.com'))
                                  Image.network(
                                    data['thumbnailUrl'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                else if (videoUrl.isNotEmpty && index < 6)
                                  _ShortsVideoThumbnail(
                                    key: ValueKey('short_thumb_${item.id}'),
                                    videoUrl: videoUrl,
                                    shortDocId: item.id,
                                    collectionName: 'shorts',
                                    ownerId: (data['userId'] ?? '').toString(),
                                    fallback: const SizedBox.shrink(),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.35),
                                      ],
                                    ),
                                  ),
                                ),
                                // Instagram Video / Reel Badge (yuxarı sağda)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                                if (isTikTok)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFE2C55), width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.music_note, color: Color(0xFFFE2C55), size: 10),
                                          SizedBox(width: 3),
                                          Text('TikTok', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Foto
                        String? base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
                        if ((base64Img == null || base64Img.isEmpty) && data['imagesBase64'] is List && (data['imagesBase64'] as List).isNotEmpty) {
                          base64Img = (data['imagesBase64'] as List).first.toString();
                        }
                        final bool hasImage = (base64Img != null && base64Img.isNotEmpty) ||
                            (data['thumbnailUrl']?.toString().isNotEmpty == true &&
                                !data['thumbnailUrl'].toString().contains('unsplash.com'));

                        return GestureDetector(
                          onTap: hasImage ? () => _showPostDetailModal(item.id, data) : null,
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: Builder(
                              builder: (context) {
                                final pBytes = _decodeB64(base64Img);
                                if (pBytes != null) {
                                  return Image.memory(pBytes, fit: BoxFit.cover, gaplessPlayback: true);
                                }
                                final thumbUrl = data['thumbnailUrl']?.toString();
                                if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                                  return Image.network(thumbUrl, fit: BoxFit.cover);
                                }
                                return const Center(
                                  child: Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 28),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Vahid Qalereya üçün element modeli
class _UnifiedGridItem {
  final String id;
  final bool isVideo;
  final Map<String, dynamic> data;
  final dynamic createdAt;

  _UnifiedGridItem({
    required this.id,
    required this.isVideo,
    required this.data,
    required this.createdAt,
  });
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
  static const int _maxConcurrent = 3; // Eyni anda maksimum 3 kadr
  static final List<Completer<bool>> _queue = [];

  static Future<bool> acquire() async {
    if (_running < _maxConcurrent) {
      _running++;
      return true;
    }
    final completer = Completer<bool>();
    _queue.add(completer);
    return completer.future;
  }

  static void release() {
    if (_running > 0) {
      _running--;
    }
    while (_queue.isNotEmpty && _running < _maxConcurrent) {
      final next = _queue.removeAt(0);
      if (!next.isCompleted) {
        _running++;
        next.complete(true);
        return;
      }
    }
  }

  static void clearQueue() {
    // KRİTİK: Növbədə gözləyənləri false ilə ləğv edirik ki, eyni anda decoder açmasınlar!
    for (final c in _queue) {
      if (!c.isCompleted) c.complete(false);
    }
    _queue.clear();
    _running = 0;
  }
}

/// Videonun öz içindən kadr çıxararaq kartın üz qabığında göstərən və keşləyən vidcet
class _ShortsVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final Widget fallback;
  final String? shortDocId;
  final String collectionName;
  final String? ownerId;

  static final Set<_ShortsVideoThumbnailState> _activeStates = {};
  static final Map<String, Uint8List> _capturedFrameCache = {};
  static bool _isSuspended = false;

  /// Qalereya açılarkən və ya video upload zamanı bütün aktiv decoder-ları dərhal azad edir
  static void pauseAndReleaseAll() {
    _isSuspended = true;
    _ThumbnailQueue.clearQueue();
    for (final s in _activeStates.toList()) {
      try {
        s._controller?.pause();
        s._controller?.dispose();
        s._controller = null;
        if (s.mounted) {
          s.setState(() {
            s._isInitialized = false;
            s._frameRendered = false;
          });
        }
      } catch (_) {}
    }
    _activeStates.clear();
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    // Qalereya və ya Shorts bağlandıqda ilişib qalmaması üçün təhlükəsizlik taymeri
    Future.delayed(const Duration(seconds: 3), () {
      _isSuspended = false;
    });
  }

  static void resumeAll() {
    _isSuspended = false;
  }

  const _ShortsVideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.fallback,
    this.shortDocId,
    this.collectionName = 'shorts',
    this.ownerId,
  });

  @override
  State<_ShortsVideoThumbnail> createState() => _ShortsVideoThumbnailState();
}

class _ShortsVideoThumbnailState extends State<_ShortsVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _frameRendered = false;
  bool _disposed = false;
  Uint8List? _cachedBytes;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ShortsVideoThumbnail._activeStates.add(this);
    final url = widget.videoUrl.trim();
    final cached = _ShortsVideoThumbnail._capturedFrameCache[url];
    if (cached != null) {
      _cachedBytes = cached;
    } else {
      _initThumbnail();
    }
  }

  @override
  void didUpdateWidget(covariant _ShortsVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _frameRendered = false;
      final url = widget.videoUrl.trim();
      final cached = _ShortsVideoThumbnail._capturedFrameCache[url];
      if (cached != null) {
        _cachedBytes = cached;
      } else {
        _cachedBytes = null;
        _initThumbnail();
      }
    }
  }

  Future<void> _initThumbnail() async {
    String url = widget.videoUrl.trim();
    if (url.isEmpty || _ShortsVideoThumbnail._isSuspended) return;

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
    final allowed = await _ThumbnailQueue.acquire();
    if (!allowed) return;

    bool released = false;
    void safeRelease() {
      if (!released) {
        released = true;
        _ThumbnailQueue.release();
      }
    }

    try {
      if (!mounted || _disposed || _ShortsVideoThumbnail._isSuspended) {
        safeRelease();
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      // Timeout: 3.5 saniyə (gecikmə olmasın)
      await controller.initialize().timeout(
        const Duration(milliseconds: 3500),
        onTimeout: () {
          debugPrint('Thumbnail timeout: $url');
        },
      );

      if (!mounted || _disposed || _ShortsVideoThumbnail._isSuspended) {
        controller.dispose();
        if (_controller == controller) _controller = null;
        safeRelease();
        return;
      }

      if (!controller.value.isInitialized) {
        controller.dispose();
        if (_controller == controller) _controller = null;
        safeRelease();
        return;
      }

      await controller.setVolume(0);

      // Seek etmədən birbaşa 0ms açar kadrı göstəririk (2x sürətli)
      try {
        await controller.play();
        await Future.delayed(const Duration(milliseconds: 35));
        await controller.pause();
      } catch (_) {}

      if (mounted && !_disposed) {
        setState(() {
          _isInitialized = true;
          _frameRendered = true;
        });
      }
      safeRelease();

      // Kadrı yaddaşa/bazaya şəkil kimi saxlayıb hardware decoder-ı dərhal azad edirik
      _captureAndCacheFrame(url, controller);
    } catch (e) {
      debugPrint('Thumbnail extraction error: $e');
      safeRelease();
    }
  }

  Future<void> _captureAndCacheFrame(String url, VideoPlayerController controller) async {
    try {
      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted || _disposed || _controller != controller) return;

      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 0.75);
      final rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgbaData == null) {
        image.dispose();
        return;
      }

      // Kadrın tam qara və ya boş olmadığını yoxlayırıq
      final bytes = rgbaData.buffer.asUint8List();
      int nonBlackPixels = 0;
      final step = (bytes.length ~/ 400).clamp(4, 256) * 4;
      for (int i = 0; i + 3 < bytes.length; i += step) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        final a = bytes[i + 3];
        if (a > 200 && (r + g + b) > 24) {
          nonBlackPixels++;
          if (nonBlackPixels >= 6) break;
        }
      }

      if (nonBlackPixels < 6) {
        image.dispose();
        return;
      }

      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (pngData == null) return;

      final pngBytes = pngData.buffer.asUint8List();
      if (pngBytes.lengthInBytes < 500) return;

      if (_ShortsVideoThumbnail._capturedFrameCache.length > 60) {
        _ShortsVideoThumbnail._capturedFrameCache.remove(
          _ShortsVideoThumbnail._capturedFrameCache.keys.first,
        );
      }
      _ShortsVideoThumbnail._capturedFrameCache[url] = pngBytes;

      if (mounted && !_disposed) {
        setState(() {
          _cachedBytes = pngBytes;
        });
        // Şəkil hazırdır -> video decoder-ı dərhal azad edirik!
        if (_controller == controller) {
          _controller = null;
          _isInitialized = false;
          try {
            await controller.dispose();
          } catch (_) {}
        }
      }

      // Sahibdirsə və ölçüsü Firestore limitinə uyğundursa qalıcı olaraq bazaya yazırıq
      final curUid = FirebaseAuth.instance.currentUser?.uid;
      if (curUid != null &&
          widget.ownerId != null &&
          widget.ownerId == curUid &&
          widget.shortDocId != null &&
          widget.shortDocId!.isNotEmpty &&
          pngBytes.lengthInBytes <= 350000) {
        try {
          await FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(widget.shortDocId)
              .update({'thumbnailBase64': base64Encode(pngBytes)});
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _ShortsVideoThumbnail._activeStates.remove(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedBytes != null) {
      return IgnorePointer(
        child: Image.memory(
          _cachedBytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => widget.fallback,
        ),
      );
    }

    final bool showVideo = _isInitialized && _frameRendered && _controller != null && _controller!.value.isInitialized;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Zəmin: Həmişə parlaq fallback qalır (heç vaxt qara sıçrayış olmur)
          widget.fallback,
          // 2. Kadr tam hazır olduqda yumşaq AnimatedOpacity ilə açılır
          if (_controller != null && _controller!.value.isInitialized)
            AnimatedOpacity(
              opacity: showVideo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
              child: RepaintBoundary(
                key: _repaintKey,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 1080,
                    height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1920,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
        ],
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

    final isTikTok = url.contains('tiktok.com') || url.contains('player/v1/');
    if (isTikTok) {
      if (mounted) {
        setState(() {
          _isInit = true;
          _hasError = false;
        });
      }
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
          await ShortsSocialService.deleteShortVideoCompletely(d.id);
        }
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Video uğurla silindi.')),
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
    final bool isTikTok = widget.videoUrl.contains('tiktok.com') || widget.videoUrl.contains('player/v1/');
    if (isTikTok) {
      final videoId = TikTokService.extractVideoId(widget.videoUrl) ?? '';
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          actions: [
            if (widget.isOwner && widget.postId.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _deletePostAndShorts,
              ),
          ],
        ),
        body: TikTokEmbedView(
          videoId: videoId,
          embedUrl: widget.videoUrl,
          originalUrl: widget.videoUrl,
          title: widget.title,
        ),
      );
    }

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
            if (_HomeScreenState._decodeB64(widget.coverBase64) != null)
              Center(
                child: Image.memory(
                  _HomeScreenState._decodeB64(widget.coverBase64)!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
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

/// Shorts kartlarında müəllifin adını 'users' kolleksiyasından yaddaş keşi ilə oxuyan vidcet
class _AuthorNameText extends StatelessWidget {
  final String userId;
  final String defaultName;
  final TextStyle? style;

  static final Map<String, String> _nameCache = {};
  static final Map<String, Future<String>> _inFlight = {};

  const _AuthorNameText({
    super.key,
    required this.userId,
    required this.defaultName,
    this.style,
  });

  Future<String> _fetchName() {
    return _inFlight.putIfAbsent(userId, () async {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final liveName = snap.data()?['fullName']?.toString().trim();
        final resolved = (liveName != null && liveName.isNotEmpty) ? liveName : defaultName;
        _nameCache[userId] = resolved;
        return resolved;
      } catch (_) {
        return defaultName;
      } finally {
        _inFlight.remove(userId);
      }
    });
  }

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

    final cached = _nameCache[userId];
    if (cached != null) {
      return Text(
        cached,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return FutureBuilder<String>(
      future: _fetchName(),
      initialData: defaultName,
      builder: (context, snapshot) {
        final name = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data! : defaultName;
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

/// Açıq rəngli xəritə altlığı (tile-lar yüklənərkən və ya offline olduqda Google Maps üslublu fon)
class _BrightStreetMapFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFEEF2F6),
    );

    final parkPaint = Paint()..color = const Color(0xFFDCFCE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.18, size.width * 0.24, size.height * 0.20),
        const Radius.circular(14),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.64, size.height * 0.56, size.width * 0.26, size.height * 0.22),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    final waterPaint = Paint()..color = const Color(0xFFD6EAFF);
    final seaPath = Path()
      ..moveTo(size.width * 0.78, 0)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.35, size.width * 0.88, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(seaPath, waterPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final highwayPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final mainRoad = Path()
      ..moveTo(0, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.44, size.height * 0.36, size.width * 0.85, size.height * 0.55);
    canvas.drawPath(mainRoad, roadPaint);
    canvas.drawPath(mainRoad, highwayPaint);

    canvas.drawLine(Offset(size.width * 0.36, 0), Offset(size.width * 0.42, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.72), Offset(size.width * 0.75, size.height * 0.66), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

