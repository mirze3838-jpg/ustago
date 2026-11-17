const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/market_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) content = content.replace(/\r\n/g, '\n');

// 1. In MarketScreen, add static allListingCategories and expose static showStoreFormSheet and showProductFormSheet
const targetClassHead = `class MarketScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final void Function(String cityOrAddress, double? lat, double? lng)? onNavigateToMap;
  final int openMyListingsSignal;

  const MarketScreen({
    super.key,
    this.onBackToHome,
    this.onNavigateToMap,
    this.openMyListingsSignal = 0,
  });

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}`;

const replaceClassHead = `class MarketScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final void Function(String cityOrAddress, double? lat, double? lng)? onNavigateToMap;
  final int openMyListingsSignal;

  const MarketScreen({
    super.key,
    this.onBackToHome,
    this.onNavigateToMap,
    this.openMyListingsSignal = 0,
  });

  static const List<String> allListingCategories = [
    'Sement',
    'Kafel & Metlax',
    'Boya & Malyar',
    'Santexnika',
    'Elektrik & Kabel',
    'Mebel Materialları',
    'Dəmir & Armatur',
    'Taxta & Laminat',
    'Dam Örtükləri',
    'Alçıpan & Profil',
    'İzolyasiya',
    'Qapı & Pəncərə',
    'Alətlər & Texnika',
    'Digər Tikinti Malları',
  ];

  static Uint8List? decodeB64(String? b64) => _MarketScreenState._decodeB64(b64);

  static Future<void> showStoreFormSheet(BuildContext context, {Map<String, dynamic>? existingStore}) async {
    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mağaza açmaq üçün əvvəlcə daxil olmalısınız.')),
      );
      return;
    }

    final bool isEdit = existingStore != null && existingStore['id'] != null;
    final nameCtrl = TextEditingController(text: existingStore?['title']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existingStore?['phone']?.toString() ?? '');
    final whatsappCtrl = TextEditingController(
      text: existingStore?['whatsapp']?.toString() ?? existingStore?['phone']?.toString() ?? '',
    );
    final addressCtrl = TextEditingController(text: existingStore?['address']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existingStore?['description']?.toString() ?? '');

    String selectedCat = existingStore?['category']?.toString() ?? 'Tikinti Materialları';
    if (!allListingCategories.contains(selectedCat)) selectedCat = allListingCategories.first;

    String selectedCity = existingStore?['city']?.toString() ?? 'Bakı';
    if (!CategoryCityService.defaultCities.contains(selectedCity)) selectedCity = 'Bakı';

    String? logoBase64 = existingStore?['logoBase64']?.toString();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final Uint8List? logoBytes = decodeB64(logoBase64);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
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
                        isEdit ? 'Mağazanı Redaktə Et' : 'Yeni Mağaza Yarat',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        try {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 70,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() => logoBase64 = base64Encode(bytes));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Loqo seçilmədi: \$e')),
                          );
                        }
                      },
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: logoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(logoBytes, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_outlined, size: 28, color: Color(0xFF1769D2)),
                                  SizedBox(height: 4),
                                  Text('Loqo', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mağazanın Adı *',
                      prefixIcon: const Icon(Icons.store_rounded, color: Color(0xFF1769D2)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCat,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Kateqoriya',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: allListingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedCat = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCity,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Şəhər',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: CategoryCityService.defaultCities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedCity = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Əlaqə Nömrəsi *',
                      hintText: '+994 50 123 45 67',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: whatsappCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp Nömrəsi',
                      hintText: '+994 50 123 45 67',
                      prefixIcon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dəqiq Ünvan / Filial *',
                      hintText: 'Məs: Dərnəgül Baksol yolu, Sıra 4, Mağaza 12',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Mağaza Haqqında Qısa Məlumat',
                      hintText: 'Tikinti materialları, çatdırılma xidməti və xüsusi endirimlər haqqında qeydlər...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();
                              final address = addressCtrl.text.trim();
                              if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Zəhmət olmasa Mağaza adı, Əlaqə nömrəsi və Ünvanı doldurun.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              final payload = <String, dynamic>{
                                'listingType': 'store',
                                'title': name,
                                'phone': phone,
                                'whatsapp': whatsappCtrl.text.trim().isNotEmpty ? whatsappCtrl.text.trim() : phone,
                                'address': address,
                                'city': selectedCity,
                                'category': selectedCat,
                                'description': descCtrl.text.trim(),
                                'logoBase64': logoBase64,
                                'ownerId': user.uid,
                                'userEmail': user.email ?? '',
                                'isVerified': existingStore?['isVerified'] ?? false,
                                'rating': existingStore?['rating'] ?? 5.0,
                                'reviewCount': existingStore?['reviewCount'] ?? 0,
                              };
                              try {
                                if (isEdit) {
                                  await FirebaseFirestore.instance
                                      .collection('market_stores')
                                      .doc(existingStore['id'].toString())
                                      .set(payload, SetOptions(merge: true));
                                } else {
                                  payload['createdAt'] = FieldValue.serverTimestamp();
                                  await FirebaseFirestore.instance.collection('market_stores').add(payload);
                                }
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEdit ? 'Mağaza yeniləndi!' : 'Mağazanız uğurla yaradıldı!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Xəta: \$e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEdit ? 'Dəyişiklikləri Yadda Saxla' : 'Mağazanı Yarat',
                              style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
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

  static Future<void> showProductFormSheet(BuildContext context, {Map<String, dynamic>? existingProduct}) async {
    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elan yerləşdirmək üçün əvvəlcə daxil olmalısınız.')),
      );
      return;
    }

    List<Map<String, dynamic>> myStores = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('market_stores')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      myStores = snap.docs
          .where((d) => (d.data()['listingType'] ?? 'store') == 'store')
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
    } catch (_) {}

    final bool isEdit = existingProduct != null && existingProduct['id'] != null;
    final titleCtrl = TextEditingController(text: existingProduct?['title']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: existingProduct?['unit']?.toString() ?? '1 ədəd');
    final rawPrice = (existingProduct?['price']?.toString() ?? '').replaceAll('AZN', '').trim();
    final priceCtrl = TextEditingController(text: rawPrice);
    final storeNameCtrl = TextEditingController(
      text: existingProduct?['store']?.toString() ??
          (myStores.isNotEmpty ? (myStores.first['title']?.toString() ?? '') : ''),
    );
    final phoneCtrl = TextEditingController(
      text: existingProduct?['phone']?.toString() ??
          (myStores.isNotEmpty ? (myStores.first['phone']?.toString() ?? '') : ''),
    );
    final whatsappCtrl = TextEditingController(
      text: existingProduct?['whatsapp']?.toString() ??
          (myStores.isNotEmpty ? (myStores.first['whatsapp']?.toString() ?? '') : ''),
    );
    final addressCtrl = TextEditingController(
      text: existingProduct?['address']?.toString() ??
          (myStores.isNotEmpty ? (myStores.first['address']?.toString() ?? '') : ''),
    );
    final descCtrl = TextEditingController(text: existingProduct?['description']?.toString() ?? '');

    String selectedCat = existingProduct?['category']?.toString() ?? 'Sement';
    if (!allListingCategories.contains(selectedCat)) selectedCat = 'Sement';

    String selectedCity = existingProduct?['city']?.toString() ??
        (myStores.isNotEmpty ? (myStores.first['city']?.toString() ?? 'Bakı') : 'Bakı');
    if (!CategoryCityService.defaultCities.contains(selectedCity)) selectedCity = 'Bakı';

    String? imageBase64 = existingProduct?['imageBase64']?.toString();
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final Uint8List? imgBytes = decodeB64(imageBase64);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
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
                        isEdit ? 'Elanı Redaktə Et' : 'Yeni Elan Yerləşdir',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        try {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 70,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() => imageBase64 = base64Encode(bytes));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Şəkil seçilmədi: \$e')),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: imgBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(imgBytes, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate_outlined, size: 34, color: Color(0xFF1769D2)),
                                  SizedBox(height: 6),
                                  Text('Məhsulun Şəklini Əlavə Et', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Məhsulun Adı *',
                      hintText: 'Məs: Holcim Sement 50 kq (400 marka)',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1769D2)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Qiymət (AZN) *',
                            hintText: '7.50',
                            prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            labelText: 'Vahid',
                            hintText: '1 kisə, 1 ədəd...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCat,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Kateqoriya',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: allListingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedCat = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCity,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Şəhər',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: CategoryCityService.defaultCities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedCity = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (myStores.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: storeNameCtrl.text.isNotEmpty ? storeNameCtrl.text : myStores.first['title']?.toString(),
                      decoration: InputDecoration(
                        labelText: 'Hansı Mağazaya aiddir?',
                        prefixIcon: const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Fərdi Elan (Mağazasız)')),
                        ...myStores.map((s) => DropdownMenuItem(
                              value: s['title']?.toString() ?? '',
                              child: Text(s['title']?.toString() ?? ''),
                            )),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          storeNameCtrl.text = val ?? '';
                          if (val != null && val.isNotEmpty) {
                            final matchStore = myStores.firstWhere((s) => s['title'] == val, orElse: () => {});
                            if (matchStore.isNotEmpty) {
                              if (phoneCtrl.text.isEmpty) phoneCtrl.text = matchStore['phone']?.toString() ?? '';
                              if (addressCtrl.text.isEmpty) addressCtrl.text = matchStore['address']?.toString() ?? '';
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Əlaqə Nömrəsi *',
                      hintText: '+994 50 123 45 67',
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ünvan / Ərazi *',
                      hintText: 'Məs: Nəsimi bazarı yanı, Mağaza 4',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Ətraflı Məlumat',
                      hintText: 'Məhsulun xüsusiyyətləri, çatdırılma və digər qeydlər...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              final price = priceCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();
                              final address = addressCtrl.text.trim();
                              if (title.isEmpty || price.isEmpty || phone.isEmpty || address.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Zəhmət olmasa Məhsul adı, Qiymət, Əlaqə nömrəsi və Ünvanı doldurun.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);
                              final payload = <String, dynamic>{
                                'listingType': 'product',
                                'title': title,
                                'price': '\$price AZN',
                                'unit': unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : '1 ədəd',
                                'category': selectedCat,
                                'city': selectedCity,
                                'store': storeNameCtrl.text.trim(),
                                'phone': phone,
                                'whatsapp': whatsappCtrl.text.trim().isNotEmpty ? whatsappCtrl.text.trim() : phone,
                                'address': address,
                                'description': descCtrl.text.trim(),
                                'imageBase64': imageBase64,
                                'ownerId': user.uid,
                                'userEmail': user.email ?? '',
                              };

                              try {
                                if (isEdit) {
                                  await FirebaseFirestore.instance
                                      .collection('market_stores')
                                      .doc(existingProduct['id'].toString())
                                      .set(payload, SetOptions(merge: true));
                                } else {
                                  payload['createdAt'] = FieldValue.serverTimestamp();
                                  await FirebaseFirestore.instance.collection('market_stores').add(payload);
                                }
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEdit ? 'Elan yeniləndi!' : 'Məhsul elanınız uğurla dərc edildi!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Xəta: \$e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEdit ? 'Dəyişiklikləri Yadda Saxla' : 'Elanı Dərc Et',
                              style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
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

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}`;

if (!content.includes(targetClassHead)) {
  console.error('targetClassHead not found!');
  process.exit(1);
}
content = content.replace(targetClassHead, replaceClassHead);
console.log('Class head replaced successfully.');

// 2. In _checkSellerPermissionAndRun, remove seller role restriction so ALL users can publish
const targetPermStart = '  Future<void> _checkSellerPermissionAndRun(VoidCallback onAllowed) async {';
const targetPermEnd = '  void _showPublishChoiceSheet() {';

const idxPermStart = content.indexOf(targetPermStart);
if (idxPermStart === -1) {
  console.error('idxPermStart not found!');
  process.exit(1);
}
const idxPermEnd = content.indexOf(targetPermEnd, idxPermStart);
if (idxPermEnd === -1) {
  console.error('idxPermEnd not found!');
  process.exit(1);
}

const replacePermFull = `  Future<void> _checkSellerPermissionAndRun(VoidCallback onAllowed) async {
    final user = _authService.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Giriş tələb olunur'),
          content: const Text('Mağaza və elan yerləşdirmək üçün zəhmət olmasa hesabınıza daxil olun.'),
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

    // İndi Usta, Fəhlə, Müştəri və Satıcı - hər kəs mağaza aça və elan yerləşdirə bilər (istifadəçi tələbi)
    onAllowed();
  }

`;

content = content.slice(0, idxPermStart) + replacePermFull + content.slice(idxPermEnd);
console.log('Permission check replaced successfully.');

if (isCRLF) content = content.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, content, 'utf8');
console.log('Market screen patched successfully.');
