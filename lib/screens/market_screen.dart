import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  String _selectedCategory = 'Hamısı';
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _marketStream;

  final List<String> _categories = [
    'Hamısı',
    'Tikinti Materialları',
    'Santexnika',
    'Elektrik',
    'Alətlər və Texnika',
    'Boya və Lak',
    'Qapı və Pəncərə',
    'Mebel və Taxta',
  ];

  // Başlanğıc nümunə mağazalar (Firestore boş olduqda da zəngin görünsün)
  final List<Map<String, dynamic>> _sampleStores = [
    {
      'title': 'Baku Tikinti Malları Mərkəzi',
      'category': 'Tikinti Materialları',
      'owner': 'Rəşad Əliyev',
      'phone': '+994 50 234 56 78',
      'address': 'Bakı ş., Dərnəgül tikinti bazarı, Sıra 4, Mağaza 12',
      'rating': 4.9,
      'isPromoted': true,
      'description': 'Sement, qum, kərpic, armatur, gips və digər bütün növ qara tikinti materiallarının topdan və pərakəndə satışı. Çatdırılma var.',
      'icon': Icons.apartment_rounded,
      'color': Color(0xFFE65100),
    },
    {
      'title': 'Santexnika Dünyası',
      'category': 'Santexnika',
      'owner': 'Vüsal Qasımov',
      'phone': '+994 55 987 65 43',
      'address': 'Bakı ş., Əhmədli qəsəbəsi, Sarayevo küç. 15',
      'rating': 4.8,
      'isPromoted': true,
      'description': 'Kombi, radiator, boru fitinqləri, kranlar, su nasosları və kanalizasiya ləvazimatları. Rəsmi zəmanət.',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF1976D2),
    },
    {
      'title': 'Master Tool - Peşəkar Usta Alətləri',
      'category': 'Alətlər və Texnika',
      'owner': 'Eldar Məmmədov',
      'phone': '+994 70 333 22 11',
      'address': 'Bakı ş., Sədərək Ticarət Mərkəzi, Şirniyyat yanı',
      'rating': 5.0,
      'isPromoted': true,
      'description': 'Drel, laqonda, perforator, qaynaq aparatları, lazer səviyyəölçənlər (Bosch, DeWalt, Makita, Total).',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFFF57C00),
    },
    {
      'title': 'Baku Elektrik Təchizat',
      'category': 'Elektrik',
      'owner': 'Kamran İsmayılov',
      'phone': '+994 51 444 88 99',
      'address': 'Bakı ş., Nərimanov r., Təbriz küç. 82',
      'rating': 4.7,
      'isPromoted': false,
      'description': 'Kabel, avtomat açarlar, çılçıraqlar, led panellər və sənaye elektrik avadanlıqları.',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFFFBC02D),
    },
    {
      'title': 'Rənglər Evi - Boya Mərkəzi',
      'category': 'Boya və Lak',
      'owner': 'Samir Rzayev',
      'phone': '+994 50 678 90 12',
      'address': 'Bakı ş., Babək prospekti 22',
      'rating': 4.8,
      'isPromoted': false,
      'description': 'Daxili və fasad boyaları, emulsiya, lak, divar kağızları və rəng qarışdırma xidməti.',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFF9C27B0),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _marketStream = FirebaseFirestore.instance
        .collection('market_stores')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _deleteListing(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elanı sil'),
        content: const Text('Bu elanı silmək istədiyinizdən əminsiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('market_stores').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Elan silindi.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silmə xətası: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '994${cleanPhone.substring(1)}';
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Yeni Mağaza və ya Elan əlavə etmək üçün dialoq
  void _showAddListingDialog() {
    final user = _authService.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Giriş tələb olunur'),
          content: const Text('Mağaza və ya elan yerləşdirmək üçün zəhmət olmasa tətbiqə daxil olun.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bağla'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('Daxil ol', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final storeNameController = TextEditingController();
    final priceController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final descController = TextEditingController();
    String selectedCat = _categories[1];
    String listingType = 'store'; // 'store' və ya 'product'

    showModalBottomSheet(
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
                    Text(
                      listingType == 'store' ? 'Yeni Mağaza Əlavə Et' : 'Məhsul / Elan Yerləşdir',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Mağaza')),
                        selected: listingType == 'store',
                        selectedColor: const Color(0xFF1769D2),
                        labelStyle: TextStyle(
                          color: listingType == 'store' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (v) {
                          if (v) setModalState(() => listingType = 'store');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Məhsul / Elan')),
                        selected: listingType == 'product',
                        selectedColor: const Color(0xFF1769D2),
                        labelStyle: TextStyle(
                          color: listingType == 'product' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (v) {
                          if (v) setModalState(() => listingType = 'product');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storeNameController,
                  decoration: InputDecoration(
                    labelText: listingType == 'store' ? 'Mağazanın Adı *' : 'Məhsulun Adı *',
                    prefixIcon: Icon(listingType == 'store' ? Icons.store : Icons.shopping_bag_outlined),
                  ),
                ),
                if (listingType == 'product') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Qiymət (AZN) *',
                      hintText: 'Məs: 45 AZN',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: const InputDecoration(
                    labelText: 'Kateqoriya *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.where((c) => c != 'Hamısı').map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Əlaqə Nömrəsi (Zəng / WhatsApp) *',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '+994 50 123 45 67',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Ünvan və ya Şəhər *',
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'Məs. Dərnəgül tikinti bazarı',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: listingType == 'store' ? 'Təsvir və Satılan Mallar *' : 'Məhsul haqqında məlumat *',
                    hintText: 'Məhsullar, çatdırılma və şərtlər haqqında qısa məlumat yazın...',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (storeNameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty ||
                          descController.text.trim().isEmpty ||
                          (listingType == 'product' && priceController.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zəhmət olmasa vacib xanaları doldurun!')),
                        );
                        return;
                      }

                      try {
                        await FirebaseFirestore.instance.collection('market_stores').add({
                          'title': storeNameController.text.trim(),
                          'listingType': listingType,
                          'price': listingType == 'product' ? priceController.text.trim() : '',
                          'category': selectedCat,
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'description': descController.text.trim(),
                          'userId': user.uid,
                          'ownerId': user.uid,
                          'userEmail': user.email,
                          'rating': 5.0,
                          'isPromoted': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                listingType == 'store'
                                    ? 'Təbriklər! Mağazanız uğurla əlavə edildi.'
                                    : 'Təbriklər! Elanınız uğurla dərc edildi.',
                              ),
                              backgroundColor: Colors.green,
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
                    },
                    child: const Text('Dərc et və Reklam et', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Alış-Satış & Tikinti Mağazaları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: 'Mağazalar & Satıcılar'),
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Tikinti Malları & Elanlar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1769D2),
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Mağaza Əlavə Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddListingDialog,
      ),
      body: Column(
        children: [
          // 1. Reklam Paneli (Satıcılar üçün çağırış)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Mağazanızı UstaGo-da Reklam Edin!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tikinti mallarınızı minlərlə usta və müştəriyə birbaşa satın.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _showAddListingDialog,
                  child: const Text('Elan Ver'),
                ),
              ],
            ),
          ),

          // 2. Axtarış Qutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  hintText: 'Mağaza, məhsul və ya ünvan axtar...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchController.text.isNotEmpty
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
          ),

          // 3. Kateqoriya Seçimi (Horizontal Scroll)
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1769D2),
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 3. TabBar Görünüşü
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStoresList(),
                _buildProductsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1-ci Tab: Mağazalar və Satıcılar Siyahısı
  Widget _buildStoresList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _marketStream,
      builder: (context, snapshot) {
        List<Map<String, dynamic>> allStores = List.from(_sampleStores);

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final firestoreStores = snapshot.data!.docs.where((d) {
            final lType = d.data()['listingType']?.toString() ?? 'store';
            return lType == 'store';
          }).map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = d.id;
            data['icon'] = Icons.store_mall_directory_rounded;
            data['color'] = const Color(0xFF1769D2);
            return data;
          }).toList();
          allStores = [...firestoreStores, ..._sampleStores];
        }

        // Kateqoriya və axtarış üzrə filtrasiya
        final q = _searchController.text.trim().toLowerCase();
        final filtered = allStores.where((s) {
          final catOk = _selectedCategory == 'Hamısı' || s['category'] == _selectedCategory;
          if (!catOk) return false;
          if (q.isEmpty) return true;
          final title = (s['title'] ?? '').toString().toLowerCase();
          final desc = (s['description'] ?? '').toString().toLowerCase();
          final addr = (s['address'] ?? '').toString().toLowerCase();
          return title.contains(q) || desc.contains(q) || addr.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Axtarışa və ya kateqoriyaya uyğun mağaza yoxdur.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80, top: 4),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final store = filtered[index];
            return _buildStoreCard(store);
          },
        );
      },
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final isPromoted = store['isPromoted'] == true;
    final String? docId = store['id']?.toString();
    final currentUser = _authService.currentUser;
    final bool canDelete = docId != null &&
        currentUser != null &&
        (store['ownerId'] == currentUser.uid ||
            store['userId'] == currentUser.uid ||
            currentUser.email == 'mirze3838@gmail.com');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPromoted ? const Color(0xFF1769D2).withOpacity(0.3) : Colors.grey.shade200,
          width: isPromoted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: (store['color'] as Color? ?? const Color(0xFF1769D2)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    store['icon'] as IconData? ?? Icons.storefront,
                    color: store['color'] as Color? ?? const Color(0xFF1769D2),
                    size: 30,
                  ),
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
                              store['title'] ?? '',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isPromoted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'VIP Reklam',
                                style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (canDelete)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Elanı sil',
                              onPressed: () => _deleteListing(docId),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          store['category'] ?? '',
                          style: const TextStyle(color: Color(0xFF1769D2), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              store['description'] ?? '',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    store['address'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _openWhatsApp(store['phone'] ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Zəng et', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _makeCall(store['phone'] ?? ''),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2-ci Tab: Məhsullar və Fərdi Elanlar (Canlı Firestore + Nümunə Məhsullar)
  Widget _buildProductsList() {
    final sampleProducts = [
      {
        'title': 'Sement Holcim 400 Marka (Topdan)',
        'price': '7.50 AZN',
        'store': 'Baku Tikinti Malları',
        'phone': '+994 50 234 56 78',
        'category': 'Tikinti Materialları',
        'icon': Icons.layers_rounded,
      },
      {
        'title': 'Kombi DemirDöküm 24 kW (Zəmanətlə)',
        'price': '890 AZN',
        'store': 'Santexnika Dünyası',
        'phone': '+994 55 987 65 43',
        'category': 'Santexnika',
        'icon': Icons.heat_pump_rounded,
      },
      {
        'title': 'Perforator DeWalt D25144K (Original)',
        'price': '280 AZN',
        'store': 'Master Tool',
        'phone': '+994 70 333 22 11',
        'category': 'Alətlər və Texnika',
        'icon': Icons.construction_rounded,
      },
      {
        'title': 'Boya Sobsan Emulsiya 20 kg',
        'price': '48 AZN',
        'store': 'Rənglər Evi',
        'phone': '+994 50 678 90 12',
        'category': 'Boya və Lak',
        'icon': Icons.format_paint_rounded,
      },
    ];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _marketStream,
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> firestoreProducts = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var d in snapshot.data!.docs) {
            final data = d.data();
            if (data['listingType']?.toString() == 'product') {
              firestoreProducts.add({
                'id': d.id,
                'ownerId': data['ownerId'] ?? data['userId'],
                'title': data['title'] ?? '',
                'price': (data['price']?.toString().isNotEmpty == true) ? data['price'].toString() : 'Razılaşma',
                'store': data['address']?.toString().isNotEmpty == true ? data['address'].toString() : 'Elan',
                'phone': data['phone'] ?? '',
                'category': data['category'] ?? 'Tikinti Materialları',
                'description': data['description'] ?? '',
                'icon': Icons.shopping_bag_rounded,
              });
            }
          }
        }

        final allProducts = [...firestoreProducts, ...sampleProducts];
        final q = _searchController.text.trim().toLowerCase();
        final filtered = allProducts.where((p) {
          final catOk = _selectedCategory == 'Hamısı' || p['category'] == _selectedCategory;
          if (!catOk) return false;
          if (q.isEmpty) return true;
          final title = (p['title'] ?? '').toString().toLowerCase();
          final store = (p['store'] ?? '').toString().toLowerCase();
          final desc = (p['description'] ?? '').toString().toLowerCase();
          return title.contains(q) || store.contains(q) || desc.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Axtarışa və ya kateqoriyaya uyğun məhsul yoxdur.', style: TextStyle(color: Colors.grey)),
          );
        }

        final currentUser = _authService.currentUser;

        return ListView.builder(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 80, top: 4),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final prod = filtered[index];
            final String? docId = prod['id']?.toString();
            final bool canDelete = docId != null &&
                currentUser != null &&
                (prod['ownerId'] == currentUser.uid || currentUser.email == 'mirze3838@gmail.com');

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1769D2).withOpacity(0.1),
                  child: Icon(prod['icon'] as IconData? ?? Icons.inventory_2, color: const Color(0xFF1769D2)),
                ),
                title: Text(prod['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${prod['store']} • ${prod['category']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prod['price'].toString(),
                      style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.phone, color: Color(0xFF2E7D32), size: 20),
                      tooltip: 'Zəng et',
                      onPressed: () => _makeCall(prod['phone'].toString()),
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Elanı sil',
                        onPressed: () => _deleteListing(docId),
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
}
