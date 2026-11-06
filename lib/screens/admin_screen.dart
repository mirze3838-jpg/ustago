import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/category_city_service.dart';
import 'artisan_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'pending', 'verified'

  // Kateqoriya yaratma form sahələri
  final TextEditingController _categoryNameController = TextEditingController();
  IconData _selectedCategoryIcon = Icons.handyman;
  Color _selectedCategoryColor = const Color(0xFF1976D2);
  Color _selectedCategoryBgColor = const Color(0xFFE3F2FD);
  bool _isAddingCategory = false;

  // Şəhər yaratma sahələri
  final TextEditingController _cityNameController = TextEditingController();
  bool _isAddingCity = false;

  final List<Map<String, dynamic>> _availableIcons = [
    {'icon': Icons.handyman, 'label': 'Usta'},
    {'icon': Icons.cleaning_services, 'label': 'Təmizlik'},
    {'icon': Icons.roofing, 'label': 'Dam/Örtük'},
    {'icon': Icons.yard, 'label': 'Bağban'},
    {'icon': Icons.plumbing, 'label': 'Santexnika'},
    {'icon': Icons.kitchen, 'label': 'Mətbəx'},
    {'icon': Icons.tv, 'label': 'Elektronika'},
    {'icon': Icons.security, 'label': 'Təhlükəsizlik'},
    {'icon': Icons.local_shipping, 'label': 'Yükdaşıma'},
    {'icon': Icons.brush, 'label': 'Dizayn/Boyaq'},
    {'icon': Icons.solar_power, 'label': 'Günəş/Enerji'},
    {'icon': Icons.lock, 'label': 'Qıfıl/Qapı'},
    {'icon': Icons.pest_control, 'label': 'Dezinfeksiya'},
    {'icon': Icons.camera_alt, 'label': 'Kamera/Nəzarət'},
  ];

  final List<Map<String, dynamic>> _availableColors = [
    {'color': const Color(0xFF1976D2), 'bg': const Color(0xFFE3F2FD)},
    {'color': const Color(0xFFE65100), 'bg': const Color(0xFFFBE9E7)},
    {'color': const Color(0xFF2E7D32), 'bg': const Color(0xFFE8F5E9)},
    {'color': const Color(0xFF6A1B9A), 'bg': const Color(0xFFF3E5F5)},
    {'color': const Color(0xFFC2185B), 'bg': const Color(0xFFFCE4EC)},
    {'color': const Color(0xFF00838F), 'bg': const Color(0xFFE0F7FA)},
    {'color': const Color(0xFFF57F17), 'bg': const Color(0xFFFFFDE7)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryNameController.dispose();
    _cityNameController.dispose();
    super.dispose();
  }

  Future<void> _verifyArtisan(String uid, bool verify) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': verify,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verify ? 'Usta təsdiqləndi!' : 'Təsdiq ləğv edildi.'),
            backgroundColor: verify ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCreateCategory() async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zəhmət olmasa kateqoriyanın adını daxil edin!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isAddingCategory = true);
    try {
      await CategoryCityService.addCategory(
        title: name,
        icon: _selectedCategoryIcon,
        color: _selectedCategoryColor,
        bgColor: _selectedCategoryBgColor,
      );
      _categoryNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" kateqoriyası uğurla əlavə edildi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingCategory = false);
    }
  }

  Future<void> _handleCreateCity() async {
    final city = _cityNameController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zəhmət olmasa şəhər adını yazın!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isAddingCity = true);
    try {
      await CategoryCityService.addCity(city);
      _cityNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$city" şəhəri siyahıya əlavə edildi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingCity = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UstaGo Admin Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt), text: 'Ustalar'),
            Tab(icon: Icon(Icons.category), text: 'Kateqoriyalar'),
            Tab(icon: Icon(Icons.location_city), text: 'Şəhərlər'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArtisansTab(),
          _buildCategoriesTab(),
          _buildCitiesTab(),
        ],
      ),
    );
  }

  // TAB 1: USTALAR VƏ TƏSDİQLƏR
  Widget _buildArtisansTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final artisans = docs.where((d) => d.data()['role'] == 'usta' || d.data()['role'] == 'worker').toList();
        final customers = docs.where((d) => d.data()['role'] == 'customer').toList();

        List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = artisans;
        if (_selectedFilter == 'pending') {
          filteredDocs = artisans.where((d) => d.data()['isVerified'] != true).toList();
        } else if (_selectedFilter == 'verified') {
          filteredDocs = artisans.where((d) => d.data()['isVerified'] == true).toList();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statistika Kartları
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Ümumi İstifadəçi', '${docs.length}', Icons.people, Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Ustalar', '${artisans.length}', Icons.handyman, Colors.orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Müştərilər', '${customers.length}', Icons.person, Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter düymələri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Hamısı', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Təsdiq Gözləyənlər', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Təsdiqlənmişlər', 'verified'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Ustaların Siyahısı (${filteredDocs.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (filteredDocs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Bu kateqoriyada usta tapılmadı.', style: TextStyle(color: Colors.grey)),
                ),
              ),

            ...filteredDocs.map((doc) {
              final data = doc.data();
              final name = data['fullName'] ?? 'Adsız';
              final email = data['email'] ?? '';
              final phone = data['phone'] ?? '';
              final category = data['category'] ?? 'Usta';
              final bool isVerified = data['isVerified'] == true;
              final bool hasVideo = (data['videoUrl'] as String?)?.isNotEmpty == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.handyman, color: Color(0xFF1769D2)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified)
                                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('$email • $phone', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (hasVideo)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ArtisanDetailScreen(artisanData: data)),
                                );
                              },
                              icon: const Icon(Icons.play_circle_outline, size: 18),
                              label: const Text('Videosuna bax'),
                            )
                          else
                            const Text('Video yükləməyib', style: TextStyle(color: Colors.red, fontSize: 12)),

                          const Spacer(),

                          if (!isVerified)
                            FilledButton.icon(
                              onPressed: () => _verifyArtisan(doc.id, true),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Təsdiqlə'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _verifyArtisan(doc.id, false),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Ləğv et'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // TAB 2: KATEQORİYALARIN İDARƏ EDİLMƏSİ (YENİ ƏLAVƏ ET VƏ SİL)
  Widget _buildCategoriesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Kateqoriya Yaratma Kartı
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedCategoryBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_selectedCategoryIcon, color: _selectedCategoryColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yeni Kateqoriya Əlavə Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Yazdığınız kateqoriya ana səhifəyə və usta qeydiyyatına düşəcək',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Kateqoriya adı daxil etmə sahəsi
                TextField(
                  controller: _categoryNameController,
                  decoration: InputDecoration(
                    labelText: 'Kateqoriyanın adı *',
                    hintText: 'Məsələn: Kafel-Metlax, Qaynaqçı, Təmizlik...',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // İkon seçimi
                const Text('İkon seçin:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableIcons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = _availableIcons[index];
                      final icon = item['icon'] as IconData;
                      final isSelected = _selectedCategoryIcon == icon;

                      return InkWell(
                        onTap: () => setState(() => _selectedCategoryIcon = icon),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected ? _selectedCategoryColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? _selectedCategoryColor : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Rəng seçimi
                const Text('Rəng seçin:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: _availableColors.map((c) {
                    final color = c['color'] as Color;
                    final bg = c['bg'] as Color;
                    final isSelected = _selectedCategoryColor == color;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryColor = color;
                          _selectedCategoryBgColor = bg;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Əlavə et düyməsi
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isAddingCategory ? null : _handleCreateCategory,
                    icon: _isAddingCategory
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      _isAddingCategory ? 'Əlavə edilir...' : 'Kateqoriyanı Əlavə Et',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Mövcud Kateqoriyaların Canlı Siyahısı
        const Text(
          'Mövcud Kateqoriyalar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: CategoryCityService.getCategoriesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }

            final categories = snapshot.data ?? CategoryCityService.defaultCategories;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final String title = (cat['title'] as String).replaceAll('\n', ' ');
                final IconData icon = cat['icon'] as IconData? ?? Icons.category;
                final Color color = cat['color'] as Color? ?? Colors.blue;
                final Color bgColor = cat['bgColor'] as Color? ?? Colors.blue.shade50;
                final bool isCustom = cat['isCustom'] == true;
                final String? docId = cat['id'] as String?;

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isCustom ? 'Admin tərəfindən əlavə edilib' : 'Sistem kateqoriyası',
                      style: TextStyle(fontSize: 12, color: isCustom ? Colors.green.shade700 : Colors.grey),
                    ),
                    trailing: isCustom && docId != null
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Kateqoriyanı sil',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Kateqoriyanı sil'),
                                  content: Text('"$title" kateqoriyasını silmək istədiyinizdən əminsiniz?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Bəli, sil'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await CategoryCityService.deleteCategory(docId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('"$title" silindi.')),
                                  );
                                }
                              }
                            },
                          )
                        : const Chip(
                            label: Text('Sistem', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            visualDensity: VisualDensity.compact,
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

  // TAB 3: ŞƏHƏRLƏRİN İDARƏ EDİLMƏSİ (YENİ ƏLAVƏ ET VƏ SİL)
  Widget _buildCitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Şəhər Əlavə Etmə Kartı
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_location_alt, color: Colors.green, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yeni Şəhər / Rayon Əlavə Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Əlavə etdiyiniz şəhər ana səhifədəki və filtrlərdəki seçimlərə düşəcək',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Şəhər adı daxil etmə sahəsi
                TextField(
                  controller: _cityNameController,
                  decoration: InputDecoration(
                    labelText: 'Şəhər və ya Rayon adı *',
                    hintText: 'Məsələn: Xırdalan, Zaqatala, Qəbələ, Bərdə...',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Əlavə et düyməsi
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isAddingCity ? null : _handleCreateCity,
                    icon: _isAddingCity
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_location, color: Colors.white),
                    label: Text(
                      _isAddingCity ? 'Əlavə edilir...' : 'Şəhəri Əlavə Et',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Mövcud Şəhərlərin Siyahısı
        const Text(
          'Mövcud Şəhər Seçimləri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        StreamBuilder<List<String>>(
          stream: CategoryCityService.getCitiesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }

            final cities = snapshot.data ?? CategoryCityService.defaultCities;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities.map((city) {
                final isDefault = CategoryCityService.defaultCities.contains(city);

                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: isDefault ? Colors.blue.shade100 : Colors.green.shade100,
                    child: Icon(
                      Icons.location_on,
                      size: 14,
                      color: isDefault ? const Color(0xFF1769D2) : Colors.green.shade800,
                    ),
                  ),
                  label: Text(city, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: isDefault ? Colors.grey.shade100 : Colors.green.shade50,
                  deleteIcon: isDefault ? null : const Icon(Icons.close, size: 16, color: Colors.red),
                  onDeleted: isDefault
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Şəhəri sil'),
                              content: Text('"$city" şəhərini silmək istədiyinizdən əminsiniz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Bəli, sil'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await CategoryCityService.deleteCity(city);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('"$city" şəhəri silindi.')),
                              );
                            }
                          }
                        },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final bool isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
