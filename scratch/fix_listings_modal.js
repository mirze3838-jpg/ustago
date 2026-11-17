const fs = require('fs');

// --- 1. Update lib/screens/market_screen.dart ---
const marketPath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/market_screen.dart';
let marketContent = fs.readFileSync(marketPath, 'utf8');
const isMarketCRLF = marketContent.includes('\r\n');
if (isMarketCRLF) marketContent = marketContent.replace(/\r\n/g, '\n');

// Ensure firebase_auth is imported
if (!marketContent.includes("import 'package:firebase_auth/firebase_auth.dart';")) {
  marketContent = marketContent.replace(
    "import 'package:cloud_firestore/cloud_firestore.dart';",
    "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_auth/firebase_auth.dart';"
  );
}

// Replace showStoreFormSheet and showProductFormSheet in MarketScreen
const storeStart = '  static Future<void> showStoreFormSheet(';
const productEnd = '  @override\n  State<MarketScreen> createState() => _MarketScreenState();';

const idxStore = marketContent.indexOf(storeStart);
const idxProdEnd = marketContent.indexOf(productEnd);

if (idxStore === -1 || idxProdEnd === -1) {
  console.error('Could not find showStoreFormSheet/showProductFormSheet in market_screen.dart');
  process.exit(1);
}

const replacementSheets = `  static Future<void> showStoreFormSheet(
    BuildContext context, {
    Map<String, dynamic>? existingStore,
    String? defaultPhone,
    String? defaultAddress,
  }) async {
    final user = AuthService().currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mağaza açmaq üçün əvvəlcə daxil olmalısınız.')),
        );
      }
      return;
    }

    final bool isEdit = existingStore != null && existingStore['id'] != null;

    String initialTitle = existingStore?['title']?.toString() ?? '';
    String initialPhone = existingStore?['phone']?.toString() ?? defaultPhone ?? '';
    String initialAddress = existingStore?['address']?.toString() ?? defaultAddress ?? '';

    if (initialTitle.isEmpty || initialPhone.isEmpty || initialAddress.isEmpty) {
      try {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final uData = uDoc.data();
        if (uData != null) {
          if (initialTitle.isEmpty) {
            final fName = (uData['fullName'] ?? '').toString().trim();
            if (fName.isNotEmpty) initialTitle = '$fName Mağazası';
          }
          if (initialPhone.isEmpty) initialPhone = (uData['phone'] ?? '').toString();
          if (initialAddress.isEmpty) {
            final city = (uData['city'] ?? '').toString();
            final dist = (uData['district'] ?? '').toString();
            initialAddress = dist.isNotEmpty ? '$city, $dist' : city;
          }
        }
      } catch (_) {}
    }

    final nameCtrl = TextEditingController(text: initialTitle);
    final phoneCtrl = TextEditingController(text: initialPhone);
    final whatsappCtrl = TextEditingController(
      text: existingStore?['whatsapp']?.toString() ?? initialPhone,
    );
    final addressCtrl = TextEditingController(text: initialAddress);
    final descCtrl = TextEditingController(text: existingStore?['description']?.toString() ?? '');

    String selectedCat = existingStore?['category']?.toString() ?? 'Tikinti Materialları';
    if (!allListingCategories.contains(selectedCat)) selectedCat = allListingCategories.first;

    String selectedCity = existingStore?['city']?.toString() ?? 'Bakı';
    if (!CategoryCityService.defaultCities.contains(selectedCity)) selectedCity = 'Bakı';

    String? logoBase64 = existingStore?['logoBase64']?.toString();
    bool isSaving = false;

    if (!context.mounted) return;

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
                        isEdit ? 'Mağazanı Redaktə Et' : 'Yeni Mağaza Aç',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
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
                            SnackBar(content: Text('Loqo seçilmədi: $e')),
                          );
                        }
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: logoBytes != null
                            ? ClipOval(child: Image.memory(logoBytes, fit: BoxFit.cover, width: 90, height: 90))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_outlined, size: 28, color: Color(0xFF8B5CF6)),
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
                      hintText: 'Məs: Nurlan Tikinti Malları',
                      prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6)),
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
                      prefixIcon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF059669)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dəqiq Ünvan *',
                      hintText: 'Məs: Dərnəgül Tikinti Bazarı, Sıra 3, Mağaza 12',
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
                      hintText: 'Tikinti materialları, topdan və pərakəndə satış, çatdırılma xidməti...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
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
                                'category': selectedCat,
                                'city': selectedCity,
                                'phone': phone,
                                'whatsapp': whatsappCtrl.text.trim().isNotEmpty ? whatsappCtrl.text.trim() : phone,
                                'address': address,
                                'description': descCtrl.text.trim(),
                                'logoBase64': logoBase64,
                                'ownerId': user.uid,
                                'userId': user.uid,
                                'userEmail': user.email ?? '',
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
                                    content: Text(isEdit ? 'Mağaza yeniləndi!' : 'Təbriklər! Mağazanız uğurla açıldı!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
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
                              isEdit ? 'Dəyişiklikləri Yadda Saxla' : 'Mağazanı Aç',
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

  static Future<void> showProductFormSheet(
    BuildContext context, {
    Map<String, dynamic>? existingProduct,
    String? defaultPhone,
    String? defaultAddress,
  }) async {
    final user = AuthService().currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elan yerləşdirmək üçün əvvəlcə daxil olmalısınız.')),
        );
      }
      return;
    }

    List<Map<String, dynamic>> myStores = [];
    try {
      final snap = await FirebaseFirestore.instance.collection('market_stores').get();
      myStores = snap.docs
          .where((d) {
            final data = d.data();
            final isOwner = data['ownerId'] == user.uid || data['userId'] == user.uid;
            return isOwner && (data['listingType'] ?? 'store') == 'store';
          })
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

    String initialPhone = existingProduct?['phone']?.toString() ??
        (myStores.isNotEmpty ? (myStores.first['phone']?.toString() ?? '') : (defaultPhone ?? ''));
    String initialAddress = existingProduct?['address']?.toString() ??
        (myStores.isNotEmpty ? (myStores.first['address']?.toString() ?? '') : (defaultAddress ?? ''));

    if (initialPhone.isEmpty || initialAddress.isEmpty) {
      try {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final uData = uDoc.data();
        if (uData != null) {
          if (initialPhone.isEmpty) initialPhone = (uData['phone'] ?? '').toString();
          if (initialAddress.isEmpty) {
            final city = (uData['city'] ?? '').toString();
            final dist = (uData['district'] ?? '').toString();
            initialAddress = dist.isNotEmpty ? '$city, $dist' : city;
          }
        }
      } catch (_) {}
    }

    final phoneCtrl = TextEditingController(text: initialPhone);
    final whatsappCtrl = TextEditingController(
      text: existingProduct?['whatsapp']?.toString() ??
          (myStores.isNotEmpty ? (myStores.first['whatsapp']?.toString() ?? initialPhone) : initialPhone),
    );
    final addressCtrl = TextEditingController(text: initialAddress);
    final descCtrl = TextEditingController(text: existingProduct?['description']?.toString() ?? '');

    String selectedCat = existingProduct?['category']?.toString() ?? 'Sement';
    if (!allListingCategories.contains(selectedCat)) selectedCat = 'Sement';

    String selectedCity = existingProduct?['city']?.toString() ??
        (myStores.isNotEmpty ? (myStores.first['city']?.toString() ?? 'Bakı') : 'Bakı');
    if (!CategoryCityService.defaultCities.contains(selectedCity)) selectedCity = 'Bakı';

    String? imageBase64 = existingProduct?['imageBase64']?.toString();
    bool isSaving = false;

    if (!context.mounted) return;

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
                            SnackBar(content: Text('Şəkil seçilmədi: $e')),
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
                                'price': '$price AZN',
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
                                'userId': user.uid,
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
                                  SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
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
`;

marketContent = marketContent.slice(0, idxStore) + replacementSheets + marketContent.slice(idxProdEnd);

if (isMarketCRLF) marketContent = marketContent.replace(/\n/g, '\r\n');
fs.writeFileSync(marketPath, marketContent, 'utf8');
console.log('market_screen.dart updated successfully.');


// --- 2. Update lib/screens/home_screen.dart ---
const homePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let homeContent = fs.readFileSync(homePath, 'utf8');
const isHomeCRLF = homeContent.includes('\r\n');
if (isHomeCRLF) homeContent = homeContent.replace(/\r\n/g, '\n');

// Update calls in _showProfileOptionsMenu to pass userPhone and userAddress
const targetMenuStoreCall = "_showUserStoreModal(context, uid, userData?['fullName'] ?? '', isOwner: true);";
const replaceMenuStoreCall = "_showUserStoreModal(context, uid, userData?['fullName'] ?? '', isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString());";

if (homeContent.includes(targetMenuStoreCall)) {
  homeContent = homeContent.replace(targetMenuStoreCall, replaceMenuStoreCall);
  console.log('Menu store call updated.');
}

const targetMenuListCall = "_showUserListingsModal(context, uid, userData?['fullName'] ?? '', isOwner: true);";
const replaceMenuListCall = "_showUserListingsModal(context, uid, userData?['fullName'] ?? '', isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString());";

if (homeContent.includes(targetMenuListCall)) {
  homeContent = homeContent.replace(targetMenuListCall, replaceMenuListCall);
  console.log('Menu list call updated.');
}

// Update calls in _buildModernUstaProfile highlights
const targetHighlightStoreCall = "_showUserStoreModal(context, user.uid, displayName, isOwner: true),";
const replaceHighlightStoreCall = "_showUserStoreModal(context, user.uid, displayName, isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString()),";

if (homeContent.includes(targetHighlightStoreCall)) {
  homeContent = homeContent.replace(targetHighlightStoreCall, replaceHighlightStoreCall);
  console.log('Highlight store call updated.');
}

const targetHighlightListCall = "_showUserListingsModal(context, user.uid, displayName, isOwner: true),";
const replaceHighlightListCall = "_showUserListingsModal(context, user.uid, displayName, isOwner: true, userPhone: userData?['phone']?.toString(), userAddress: userData?['city']?.toString()),";

if (homeContent.includes(targetHighlightListCall)) {
  homeContent = homeContent.replace(targetHighlightListCall, replaceHighlightListCall);
  console.log('Highlight list call updated.');
}

// Replace the entire definitions of _showUserStoreModal and _showUserListingsModal
const targetModalsStart = '  /// İstifadəçinin mağaza profilini və məhsullarını göstərən modal\n  void _showUserStoreModal(';
const targetModalsEnd = '  /// Vahid Qalereya (Foto və Videolar birgə, İnstagram üslubunda)\n  Widget _buildUstaUnifiedGrid(';

const idxModalsStart = homeContent.indexOf(targetModalsStart);
const idxModalsEnd = homeContent.indexOf(targetModalsEnd);

if (idxModalsStart === -1 || idxModalsEnd === -1) {
  console.error('Could not find modals block in home_screen.dart');
  process.exit(1);
}

const replacementModals = `  /// İstifadəçinin mağaza profilini və məhsullarını göstərən modal
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
                        Container(
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
                                    child: _HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                        ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                        : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30),
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
                                          'Əlaqə: \${storeData?['phone'] ?? ''}',
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
                        const SizedBox(height: 18),

                        // Vitrindəki Məhsullar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vitrindəki Məhsullar (\${productDocs.length})',
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
                            return Container(
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
                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
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
                                          '\${pData['price'] ?? ''} (\${pData['unit'] ?? '1 ədəd'})',
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
                                              ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text('Məhsul silindi.')));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                ],
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
                              '\${listings.length} aktiv elan mövcuddur',
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

                            return Container(
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
                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),
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
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                                              ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text('Elan silindi.')));
                                            }
                                          },
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
`;

homeContent = homeContent.slice(0, idxModalsStart) + replacementModals + homeContent.slice(idxModalsEnd);

if (isHomeCRLF) homeContent = homeContent.replace(/\n/g, '\r\n');
fs.writeFileSync(homePath, homeContent, 'utf8');
console.log('home_screen.dart updated successfully.');
