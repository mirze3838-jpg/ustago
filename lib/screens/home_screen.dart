import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'admin_screen.dart';
import 'shorts_screen.dart';
import 'market_screen.dart';
import 'artisan_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  // Kateqoriyalar siyahısı (Dizayndakı rəng və ikonlara uyğun)
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Tikinti',
      'icon': Icons.foundation,
      'color': const Color(0xFFE65100),
      'bgColor': const Color(0xFFFBE9E7),
    },
    {
      'title': 'Santexnik',
      'icon': Icons.water_drop,
      'color': const Color(0xFF1976D2),
      'bgColor': const Color(0xFFE3F2FD),
    },
    {
      'title': 'Elektrik',
      'icon': Icons.bolt,
      'color': const Color(0xFFFBC02D),
      'bgColor': const Color(0xFFFFFDE7),
    },
    {
      'title': 'Təmir və\nQuraşdırma',
      'icon': Icons.build_rounded,
      'color': const Color(0xFF0288D1),
      'bgColor': const Color(0xFFE1F5FE),
    },
    {
      'title': 'Avtomobil\nUstası',
      'icon': Icons.directions_car_filled,
      'color': const Color(0xFF0277BD),
      'bgColor': const Color(0xFFE1F5FE),
    },
    {
      'title': 'Mebel\nUstası',
      'icon': Icons.chair,
      'color': const Color(0xFFE67E22),
      'bgColor': const Color(0xFFFDF2E9),
    },
    {
      'title': 'Kondisioner\nUstası',
      'icon': Icons.ac_unit,
      'color': const Color(0xFF29B6F6),
      'bgColor': const Color(0xFFE1F5FE),
    },
    {
      'title': 'Dülgər',
      'icon': Icons.hardware,
      'color': const Color(0xFF8D6E63),
      'bgColor': const Color(0xFFEFEBE9),
    },
    {
      'title': 'Rəngsaz',
      'icon': Icons.format_paint,
      'color': const Color(0xFFFF7043),
      'bgColor': const Color(0xFFFBE9E7),
    },
    {
      'title': 'Digər\nKateqoriyalar',
      'icon': Icons.more_horiz,
      'color': const Color(0xFF1565C0),
      'bgColor': const Color(0xFFE3F2FD),
    },
  ];

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final user = _authService.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mesajlar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Mesajlaşmaq üçün daxil olun',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ustalar və müştərilərlə birbaşa yazışmaq üçün hesabınıza daxil olun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      child: const Text('Daxil Ol', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1769D2),
                      child: Text('U', style: TextStyle(color: Colors.white)),
                    ),
                    title: const Text('UstaGo Dəstək', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('UstaGo platformasına xoş gəlmisiniz! Kömək lazımdırsa yazın.'),
                    trailing: const Text('İndi', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    onTap: () {},
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        // 1. Mavi Üst Başlıq və Axtarış Paneli (Header)
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),

        // 2. Kateqoriyalar Bölməsi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF1769D2),
              title: 'Kateqoriyalar',
              actionTitle: 'Hamısına bax',
              onTap: () {},
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _shortsList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildShortsCard(_shortsList[index]);
              },
            ),
          ),
        ),

        // 4. Populyar Ustalar Bölməsi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            child: _buildSectionTitle(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFB300),
              title: 'Populyar Ustalar',
              actionTitle: 'Hamısına bax',
              onTap: () {},
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _popularArtisans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildArtisanCard(_popularArtisans[index]);
              },
            ),
          ),
        ),

        // Boşluq (Aşağı naviqasiya üçün)
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
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

                  // Usta şəkli və bildiriş zəngi
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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
                        decoration: const InputDecoration(
                          hintText: 'Usta, xidmət və ya kateqoriya axtarın...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 8),
                    // Şəhər seçimi
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1769D2), size: 18),
                        items: ['Bakı', 'Sumqayıt', 'Gəncə'].map((String city) {
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
                        onChanged: (v) => setState(() => _selectedCity = v!),
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

  // KATEQORİYA KARTI (Dizayndakı rəngli ikonlar)
  Widget _buildCategoryItem(Map<String, dynamic> cat) {
    return Column(
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
    );
  }

  // SHORTS KARTI
  Widget _buildShortsCard(Map<String, String> item) {
    return SizedBox(
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
    );
  }

  // POPULYAR USTA KARTI (Zəng et düyməsi ilə)
  Widget _buildArtisanCard(Map<String, String> artisan) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtisanDetailScreen(
              artisanData: {
                'fullName': artisan['name'],
                'phone': artisan['phone'],
                'role': 'usta',
                'isVerified': true,
                'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-hands-of-a-carpenter-measuring-a-piece-of-wood-41006-large.mp4',
              },
            ),
          ),
        );
      },
      child: Container(
        width: 140,
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
              backgroundImage: NetworkImage(artisan['image']!),
            ),
            const SizedBox(height: 6),
            Text(
              artisan['name']!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 13),
                const SizedBox(width: 2),
                Text(
                  '${artisan['rating']} (${artisan['reviews']})',
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${artisan['name']} ilə əlaqə qurulur: ${artisan['phone']}')),
                  );
                },
                icon: const Icon(Icons.call, size: 12, color: Colors.white),
                label: const Text('Zəng et', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853), // Yaşıl zəng düyməsi
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
    bool isVideoPost = false;
    bool isUploading = false;

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

                // Paylaş düyməsi
                if (isUploading) ...[
                  const Center(child: CircularProgressIndicator()),
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
                                final fileName = 'short_${DateTime.now().millisecondsSinceEpoch}.mp4';
                                final ref = FirebaseStorage.instance.ref().child('shorts').child(fileName);
                                final task = await ref.putData(pickedVideoBytes!, SettableMetadata(contentType: 'video/mp4'));
                                finalVideoUrl = await task.ref.getDownloadURL();
                              } catch (e) {
                                debugPrint('Storage upload error: $e');
                                if (finalVideoUrl.isEmpty) {
                                  finalVideoUrl = 'https://assets.mixkit.co/videos/preview/mixkit-hands-of-a-carpenter-measuring-a-piece-of-wood-41006-large.mp4';
                                }
                              }
                            }

                            // 1. Profil postlarına əlavə et
                            await FirebaseFirestore.instance.collection('posts').add({
                              'userId': uid,
                              'authorName': authorName,
                              'authorRole': role,
                              'title': title,
                              'category': selectedCat,
                              'videoUrl': finalVideoUrl,
                              'isVideo': true,
                              'createdAt': FieldValue.serverTimestamp(),
                              'likes': 0,
                            });

                            // 2. Shorts bölməsinə əlavə et
                            await FirebaseFirestore.instance.collection('shorts').add({
                              'userId': uid,
                              'title': title,
                              'videoUrl': finalVideoUrl,
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
    final bool isVideo = post['isVideo'] == true || (post['videoUrl'] != null && (post['videoUrl'] as String).isNotEmpty);
    final String? imgBase64 = post['imageBase64'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imgBase64 != null && imgBase64.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.memory(
                  base64Decode(imgBase64),
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              )
            else if (isVideo)
              Container(
                width: double.infinity,
                height: 180,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_filled, color: Colors.red, size: 54),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _currentIndex = 1); // Shorts bölməsinə keçir
                      },
                      child: const Text('Shorts Bölməsində Bax', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post['category'] ?? 'Usta İşi',
                          style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Paylaşım silindi.')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['title'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                final base64Img = data['imageBase64'] as String?;
                final bool isVideo = data['isVideo'] == true || (data['videoUrl'] != null && (data['videoUrl'] as String).isNotEmpty);

                return InkWell(
                  onTap: () => _showPostDetailModal(doc.id, data),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        base64Img != null && base64Img.isNotEmpty
                            ? Image.memory(
                                base64Decode(base64Img),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.blueGrey.shade900,
                                child: const Center(
                                  child: Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
                                ),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Profil Məlumatlarını Redaktə Et', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                'fullName': nameController.text.trim(),
                'phone': phoneController.text.trim(),
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

          // Admin Girişi
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 26),
            title: const Text('Admin Paneli Girişi', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tətbiq rəhbərliyi üçün idarəetmə'),
            trailing: const Icon(Icons.lock_outline, color: Colors.amber),
            onTap: _showAdminAccessDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Kömək və Dəstək'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
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
                          : (userRole == 'usta' ? 'Usta' : 'Müştəri')),
                  style: TextStyle(
                    color: isAdmin ? Colors.amber.shade900 : const Color(0xFF1769D2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Admin Paneli
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
                  if (isAdmin) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                  } else {
                    _showAdminAccessDialog();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // İnstagram tərzi Portfólio / İşlərim bölməsi
            _buildInstagramGallery(user.uid, displayName, userRole),
            const SizedBox(height: 20),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil məlumatlarını redaktə et'),
              subtitle: const Text('Ad, nömrə və şəkil dəyiş'),
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
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Kömək və Dəstək'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
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
