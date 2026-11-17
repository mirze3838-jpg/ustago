import '../services/r2_image_upload_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/category_city_service.dart';
import 'login_screen.dart';
import 'market_detail_screens.dart';

class MarketScreen extends StatefulWidget {
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

  static Future<void> showStoreFormSheet(
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
    String? logoUrl = existingStore?['logoUrl']?.toString();
    Uint8List? rawPickedLogoBytes;
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
                            rawPickedLogoBytes = bytes;
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
    String? imageUrl = existingProduct?['imageUrl']?.toString();
    Uint8List? rawPickedImageBytes;
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
                            rawPickedImageBytes = bytes;
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
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  final TextEditingController _storeSearchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();

  String _selectedStoreCategory = 'Hamısı';
  String _selectedProductCategory = 'Hamısı';
  String _selectedCityFilter = 'Hamısı';
  bool _onlyVerifiedStores = false;
  bool _onlyFavorites = false;

  String? _currentUserRole;
  StreamSubscription? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _marketStream;
  QuerySnapshot<Map<String, dynamic>>? _latestMarketSnapshot;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _marketSub;

  final Set<String> _favoriteIds = {};
  final List<Map<String, dynamic>> _cartItems = [];
  static final Map<String, Uint8List> _b64Cache = {};

  static Uint8List? _decodeB64(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    final cached = _b64Cache[b64];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(b64);
      if (_b64Cache.length > 100) _b64Cache.remove(_b64Cache.keys.first);
      _b64Cache[b64] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  final List<String> _storeCategories = const [
    'Hamısı',
    'Tikinti Materialları',
    'Alətlər',
    'Elektrik',
    'Santexnika',
    'Boya və Lak',
  ];

  final List<Map<String, dynamic>> _productCategoryCards = const [
    {
      'key': 'Hamısı',
      'label': 'Hamısı',
      'icon': Icons.layers_rounded,
      'color': Color(0xFF1769D2),
      'bg': Color(0xFFEFF6FF),
    },
    {
      'key': 'Sement',
      'label': 'Sement',
      'icon': Icons.inventory_2_rounded,
      'color': Color(0xFF92400E),
      'bg': Color(0xFFFEF3C7),
    },
    {
      'key': 'Kərpic',
      'label': 'Kərpic',
      'icon': Icons.grid_view_rounded,
      'color': Color(0xFFEA580C),
      'bg': Color(0xFFFFEDD5),
    },
    {
      'key': 'Beton',
      'label': 'Beton',
      'icon': Icons.view_in_ar_rounded,
      'color': Color(0xFF475569),
      'bg': Color(0xFFF1F5F9),
    },
    {
      'key': 'Alətlər',
      'label': 'Alətlər',
      'icon': Icons.build_rounded,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF9C3),
    },
    {
      'key': 'Elektrik',
      'label': 'Elektrik',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFFCA8A04),
      'bg': Color(0xFFFEF08A),
    },
    {
      'key': 'Santexnika',
      'label': 'Santexnika',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF0284C7),
      'bg': Color(0xFFE0F2FE),
    },
    {
      'key': 'Boya və Lak',
      'label': 'Boya',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFF9333EA),
      'bg': Color(0xFFF3E8FF),
    },
  ];

  final List<String> _allListingCategories = const [
    'Tikinti Materialları',
    'Sement',
    'Kərpic',
    'Beton',
    'Alətlər',
    'Elektrik',
    'Santexnika',
    'Boya və Lak',
  ];

  // Ekran görüntüsündəki kimi zəngin nümunə mağazalar (Firestore mağazaları həmişə üst sırada gəlir)
  final List<Map<String, dynamic>> _sampleStores = const [
    {
      'sampleId': 'sample_abc',
      'title': 'ABC Tikinti Mağazası',
      'brandTag': 'ABC\nTİKİNTİ',
      'category': 'Tikinti Materialları',
      'owner': 'Rəşad Əliyev',
      'phone': '+994 50 234 56 78',
      'whatsapp': '+994502345678',
      'city': 'Bakı',
      'address': 'Bakı, Nərimanov r.',
      'lat': 40.4065,
      'lng': 49.8730,
      'rating': 4.8,
      'reviewCount': 124,
      'isVerified': true,
      'description': 'Tikinti materialları, alətlər və s.',
      'brandColorValue': 0xFF1769D2,
      'accentColorValue': 0xFFF59E0B,
      'iconCode': 0,
    },
    {
      'sampleId': 'sample_metak',
      'title': 'Metak Group',
      'brandTag': 'M\nMETAK',
      'category': 'Tikinti Materialları',
      'owner': 'Vüsal Qasımov',
      'phone': '+994 55 987 65 43',
      'whatsapp': '+994559876543',
      'city': 'Bakı',
      'address': 'Bakı, Yasamal r.',
      'lat': 40.3860,
      'lng': 49.8050,
      'rating': 4.7,
      'reviewCount': 98,
      'isVerified': true,
      'description': 'Tikinti və təmir materialları',
      'brandColorValue': 0xFFEA580C,
      'accentColorValue': 0xFF0F172A,
      'iconCode': 1,
    },
    {
      'sampleId': 'sample_buildmax',
      'title': 'BuildMax',
      'brandTag': 'BuildMax',
      'category': 'Alətlər',
      'owner': 'Eldar Məmmədov',
      'phone': '+994 70 333 22 11',
      'whatsapp': '+994703332211',
      'city': 'Bakı',
      'address': 'Bakı, Xətai r.',
      'lat': 40.3865,
      'lng': 49.9145,
      'rating': 4.6,
      'reviewCount': 87,
      'isVerified': true,
      'description': 'Tikinti materialları və avadanlıq',
      'brandColorValue': 0xFF0284C7,
      'accentColorValue': 0xFF1E3A8A,
      'iconCode': 2,
    },
    {
      'sampleId': 'sample_elektrik',
      'title': 'Baku Elektrik Təchizat',
      'brandTag': 'BAKU\nELEKTRİK',
      'category': 'Elektrik',
      'owner': 'Kamran İsmayılov',
      'phone': '+994 51 444 88 99',
      'whatsapp': '+994514448899',
      'city': 'Bakı',
      'address': 'Bakı, Nəsimi r., Təbriz küç.',
      'lat': 40.4025,
      'lng': 49.8325,
      'rating': 4.8,
      'reviewCount': 64,
      'isVerified': true,
      'description': 'Kabel, avtomat, LED panellər və şitlər',
      'brandColorValue': 0xFFCA8A04,
      'accentColorValue': 0xFF1E293B,
      'iconCode': 3,
    },
  ];

  // Ekran görüntüsündəki nümunə tikinti malları (2 sütunlu grid)
  final List<Map<String, dynamic>> _sampleProducts = const [
    {
      'sampleId': 'prod_sement_m500',
      'title': 'Sement M500',
      'unit': '25 kq kisə',
      'price': '8.50 AZN',
      'numericPrice': 8.50,
      'store': 'ABC Tikinti Mağazası',
      'city': 'Bakı',
      'address': 'Bakı, Nərimanov r.',
      'phone': '+994 50 234 56 78',
      'whatsapp': '+994502345678',
      'category': 'Sement',
      'description': 'Yüksək möhkəmlikli M500 marka tikinti sementi (25 kq kisə). Topdan və pərakəndə.',
      'visualType': 'cement',
      'isVip': true,
    },
    {
      'sampleId': 'prod_kerpic',
      'title': 'Keyfiyyətli Kərpic',
      'unit': '1 ədəd',
      'price': '0.35 AZN',
      'numericPrice': 0.35,
      'store': 'Metak Group',
      'city': 'Bakı',
      'address': 'Bakı, Yasamal r.',
      'phone': '+994 55 987 65 43',
      'whatsapp': '+994559876543',
      'category': 'Kərpic',
      'description': 'Yüksək istilik və səs izolyasiyalı qırmızı bişmiş tikinti kərpici.',
      'visualType': 'brick',
      'isVip': true,
    },
    {
      'sampleId': 'prod_armatur',
      'title': 'Armatur Dəmir',
      'unit': '1 ton',
      'price': '950 AZN',
      'numericPrice': 950.0,
      'store': 'BuildMax',
      'city': 'Bakı',
      'address': 'Bakı, Xətai r.',
      'phone': '+994 70 333 22 11',
      'whatsapp': '+994703332211',
      'category': 'Beton',
      'description': 'A500C standartlı 12mm-16mm bünövrə və monolit armatur dəmiri.',
      'visualType': 'rebar',
    },
    {
      'sampleId': 'prod_matkap',
      'title': 'Dəngəli Matkap',
      'unit': '1 ədəd',
      'price': '129 AZN',
      'numericPrice': 129.0,
      'store': 'ToolMaster',
      'city': 'Bakı',
      'address': 'Bakı, Sədərək TM',
      'phone': '+994 51 444 88 99',
      'whatsapp': '+994514448899',
      'category': 'Alətlər',
      'description': 'Peşəkar zərbəli (dəngəli) akkumulyatorlu drel-perforator, 2 ədəd batareya ilə.',
      'visualType': 'drill',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _marketStream = FirebaseFirestore.instance
        .collection('market_stores')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asBroadcastStream();
    _marketSub = _marketStream.listen((snap) {
      if (mounted) {
        setState(() => _latestMarketSnapshot = snap);
      } else {
        _latestMarketSnapshot = snap;
      }
    }, onError: (_) {});

    _bindUserRoleListener();
    _authSub = _authService.authStateChanges.listen((_) {
      _bindUserRoleListener();
    });
  }

  @override
  void didUpdateWidget(covariant MarketScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openMyListingsSignal != oldWidget.openMyListingsSignal &&
        widget.openMyListingsSignal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMyStoresAndListingsSheet();
      });
    }
  }

  void _bindUserRoleListener() {
    _userDocSub?.cancel();
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _currentUserRole = null);
      return;
    }
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _currentUserRole = doc.data()?['role']?.toString();
        });
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeSearchController.dispose();
    _productSearchController.dispose();
    _authSub?.cancel();
    _userDocSub?.cancel();
    _marketSub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BÖLMƏ 1.1: SATICI İCAZƏ YOXLAMASI VƏ KEÇİD DİALOQU
  // ---------------------------------------------------------------------------
  Future<void> _checkSellerPermissionAndRun(VoidCallback onAllowed) async {
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

  void _showPublishChoiceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Satıcı Paneli — Nə əlavə etmək istəyirsiniz?',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                ),
                tileColor: const Color(0xFFEFF6FF),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1769D2),
                  child: Icon(Icons.add_business_rounded, color: Colors.white),
                ),
                title: const Text('Yeni Mağaza Yarat', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Mağaza adı, loqo, haqqında, ünvan, telefon və WhatsApp'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1769D2)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showStoreFormSheet();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                tileColor: Colors.orange.shade50,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEA580C),
                  child: Icon(Icons.shopping_bag_rounded, color: Colors.white),
                ),
                title: const Text('Məhsul / Tikinti Materialı Elanı Ver', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Məhsul şəkli, qiymət, ölçü vahidi, mağaza və əlaqə'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEA580C)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProductFormSheet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BÖLMƏ 1.2: MAĞAZA VƏ MƏHSUL YARATMA / REDAKTƏ / SİLMƏ
  // ---------------------------------------------------------------------------
  Future<void> _showStoreFormSheet({Map<String, dynamic>? existingStore}) =>
      MarketScreen.showStoreFormSheet(context, existingStore: existingStore);

  Future<void> _showProductFormSheet({Map<String, dynamic>? existingProduct}) =>
      MarketScreen.showProductFormSheet(context, existingProduct: existingProduct);

  Future<void> _deleteListing(String docId, {bool isStore = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isStore ? 'Mağazanı sil' : 'Elanı sil'),
        content: Text(
          isStore
              ? 'Bu mağazanı silmək istədiyinizdən əminsiniz?'
              : 'Bu məhsul elanını silmək istədiyinizdən əminsiniz?',
        ),
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
            SnackBar(
              content: Text(isStore ? 'Mağaza silindi.' : 'Elan silindi.'),
              backgroundColor: const Color(0xFF059669),
            ),
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

  void _showMyStoresAndListingsSheet() {
    final user = _authService.currentUser;
    if (user == null) {
      _checkSellerPermissionAndRun(() {});
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF1769D2)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mağaza və Elanlarım',
                      style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _checkSellerPermissionAndRun(_showPublishChoiceSheet);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _marketStream,
                initialData: _latestMarketSnapshot,
                builder: (context, snap) {
                  final docs = (snap.data ?? _latestMarketSnapshot)?.docs ?? [];
                  final myDocs = docs.where((d) {
                    final m = d.data();
                    return m['ownerId'] == user.uid || m['userId'] == user.uid;
                  }).toList();

                  if (myDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              'Hazırda aktiv mağaza və ya elanınız yoxdur',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Satıcı profili ilə mağaza aça və ya məhsul elanı yerləşdirə bilərsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1769D2),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _checkSellerPermissionAndRun(_showPublishChoiceSheet);
                              },
                              icon: const Icon(Icons.add_business_rounded, size: 18),
                              label: const Text('Mağaza / Elan Əlavə Et'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    itemCount: myDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final d = myDocs[idx];
                      final data = Map<String, dynamic>.from(d.data());
                      data['id'] = d.id;
                      final bool isStore = (data['listingType']?.toString() ?? 'store') == 'store';
                      final String title = data['title']?.toString() ?? '';
                      final String subtitle = isStore
                          ? '${data['category'] ?? ''} • ${data['address'] ?? ''}'
                          : '${data['price'] ?? ''} (${data['unit'] ?? '1 ədəd'}) • ${data['storeName'] ?? ''}';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isStore ? const Color(0xFFEFF6FF) : const Color(0xFFFFEDD5),
                              child: Icon(
                                isStore ? Icons.store_rounded : Icons.shopping_bag_rounded,
                                color: isStore ? const Color(0xFF1769D2) : const Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isStore ? const Color(0xFF1769D2) : const Color(0xFFEA580C),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isStore ? 'Mağaza' : 'Məhsul',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Redaktə et',
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1769D2)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (isStore) {
                                  _showStoreFormSheet(existingStore: data);
                                } else {
                                  _showProductFormSheet(existingProduct: {
                                    ...data,
                                    'store': data['storeName'] ?? data['store'] ?? '',
                                  });
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Sil',
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteListing(d.id, isStore: isStore),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ƏLAQƏ, XƏRİTƏ VƏ SƏBƏT FUNKSİYALARI
  // ---------------------------------------------------------------------------
  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, {String? message}) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = '994${cleanPhone.substring(1)}';
    final encodedMsg = message != null ? '?text=${Uri.encodeComponent(message)}' : '';
    final uri = Uri.parse('https://wa.me/$cleanPhone$encodedMsg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openStoreOnMap(Map<String, dynamic> store) {
    final String title = store['title']?.toString() ?? 'Mağaza';
    final String addr = store['address']?.toString() ?? (store['city']?.toString() ?? 'Bakı');
    final double? sLat = store['lat'] is num ? (store['lat'] as num).toDouble() : null;
    final double? sLng = store['lng'] is num ? (store['lng'] as num).toDouble() : null;
    final coords = CategoryCityService.resolveArtisanCoordinates(
      addr,
      store['id']?.toString() ?? title,
      lat: sLat,
      lng: sLng,
    );
    final double lat = coords[0];
    final double lng = coords[1];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(addr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildStaticSlippyMapPreview(lat, lng, title),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openWhatsApp(store['whatsapp']?.toString() ?? store['phone']?.toString() ?? '');
                    },
                    icon: const Icon(Icons.chat, color: Color(0xFF16A34A)),
                    label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (widget.onNavigateToMap != null) {
                        widget.onNavigateToMap!(store['city']?.toString() ?? 'Bakı', lat, lng);
                      } else {
                        launchUrl(
                          Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Böyük Xəritədə Aç', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticSlippyMapPreview(double lat, double lng, String label) {
    const double zoom = 14.0;
    final int tileZ = zoom.floor();
    final int nTiles = 1 << tileZ;
    final double worldPx = 256.0 * math.pow(2.0, zoom).toDouble();
    final double tileSize = 256.0;
    final double centerX = ((lng + 180.0) / 360.0) * worldPx;
    final double rad = lat * math.pi / 180.0;
    final double s = math.sin(rad);
    final double centerY = (0.5 - math.log((1.0 + s) / (1.0 - s)) / (4.0 * math.pi)) * worldPx;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final int minTx = ((centerX - w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTx = ((centerX + w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int minTy = ((centerY - h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTy = ((centerY + h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);

        final List<Widget> tiles = [];
        for (int tx = minTx; tx <= maxTx; tx++) {
          for (int ty = minTy; ty <= maxTy; ty++) {
            final int sub = (tx + ty) % 4;
            tiles.add(
              Positioned(
                left: w / 2.0 + (tx * tileSize - centerX),
                top: h / 2.0 + (ty * tileSize - centerY),
                width: tileSize + 0.5,
                height: tileSize + 0.5,
                child: Image.network(
                  'https://mt$sub.google.com/vt/lyrs=m&x=$tx&y=$ty&z=$tileZ&hl=az',
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            Container(color: const Color(0xFFEAF2F8)),
            ...tiles,
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 36),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    final String key = (product['id'] ?? product['sampleId'] ?? product['title']).toString();
    setState(() {
      final idx = _cartItems.indexWhere((e) => e['key'] == key);
      if (idx >= 0) {
        _cartItems[idx]['qty'] = (_cartItems[idx]['qty'] as int) + 1;
      } else {
        _cartItems.add({
          'key': key,
          'title': product['title'] ?? '',
          'price': product['price'] ?? '0 AZN',
          'unit': product['unit'] ?? '1 ədəd',
          'store': product['store'] ?? product['storeName'] ?? 'Mağaza',
          'phone': product['phone'] ?? '',
          'whatsapp': product['whatsapp'] ?? product['phone'] ?? '',
          'qty': 1,
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['title']} səbətə əlavə edildi'),
        backgroundColor: const Color(0xFF1769D2),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Səbət (${_totalCartCount()})',
          textColor: Colors.white,
          onPressed: _showCartSheet,
        ),
      ),
    );
  }

  int _totalCartCount() {
    int sum = 0;
    for (final item in _cartItems) {
      sum += (item['qty'] as int? ?? 1);
    }
    return sum;
  }

  double _parseAzn(String priceStr) {
    final cleaned = priceStr.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          double total = 0.0;
          for (final item in _cartItems) {
            total += _parseAzn(item['price'].toString()) * (item['qty'] as int? ?? 1);
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_rounded, color: Color(0xFF1769D2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Səbətim (${_totalCartCount()} məhsul)',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_cartItems.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _cartItems.clear());
                            setSheetState(() {});
                          },
                          child: const Text('Təmizlə', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _cartItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Səbətiniz boşdur. Tikinti mallarını əlavə edə bilərsiniz.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _cartItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final item = _cartItems[i];
                            final int qty = item['qty'] as int? ?? 1;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          '${item['store']} • ${item['unit']}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['price'].toString(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                                        onPressed: () {
                                          setState(() {
                                            if (qty > 1) {
                                              item['qty'] = qty - 1;
                                            } else {
                                              _cartItems.removeAt(i);
                                            }
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1769D2)),
                                        onPressed: () {
                                          setState(() => item['qty'] = qty + 1);
                                          setSheetState(() {});
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
                if (_cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ümumi məbləğ:', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                            Text(
                              '${total.toStringAsFixed(2)} AZN',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text('Sifarişi WhatsApp ilə Göndər', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              final firstPhone = _cartItems.first['whatsapp']?.toString() ??
                                  _cartItems.first['phone']?.toString() ??
                                  '+994502345678';
                              final lines = _cartItems
                                  .map((e) => '• ${e['title']} x${e['qty']} (${e['price']})')
                                  .join('\n');
                              _openWhatsApp(
                                firstPhone,
                                message: 'Salam, UstaGo üzərindən sifariş vermək istəyirəm:\n$lines\nCəm: ${total.toStringAsFixed(2)} AZN',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtr Seçimləri', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCityFilter = 'Hamısı';
                        _onlyVerifiedStores = false;
                        _onlyFavorites = false;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Sıfırla'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCityFilter,
                decoration: const InputDecoration(labelText: 'Şəhər / Rayon', prefixIcon: Icon(Icons.location_on_outlined)),
                items: ['Hamısı', ...CategoryCityService.defaultCities]
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setSheetState(() => _selectedCityFilter = v);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yalnız təsdiqlənmiş mağazalar'),
                value: _onlyVerifiedStores,
                onChanged: (v) {
                  setSheetState(() => _onlyVerifiedStores = v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yalnız sevimlilər (♥)'),
                value: _onlyFavorites,
                onChanged: (v) {
                  setSheetState(() => _onlyFavorites = v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tətbiq Et', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStoreDetailSheet(Map<String, dynamic> store) {
    final String title = store['title']?.toString() ?? 'Mağaza';
    final String desc = store['description']?.toString() ?? '';
    final String addr = store['address']?.toString() ?? '';
    final String phone = store['phone']?.toString() ?? '';
    final String wa = (store['whatsapp']?.toString().isNotEmpty == true) ? store['whatsapp'].toString() : phone;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStoreLogoBox(store, size: 62),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.verified, color: Color(0xFF1769D2), size: 18),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        store['category']?.toString() ?? 'Tikinti Materialları',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1769D2), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(desc, style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(child: Text(addr, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 17, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openStoreOnMap(store);
                    },
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Xəritədə'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2), foregroundColor: Colors.white),
                    onPressed: () => _makeCall(phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Zəng et'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                    onPressed: () => _openWhatsApp(wa),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ƏSAS BUILD (REFERANS ŞƏKLƏ 1:1 DİZAYN)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final int cartCount = _totalCartCount();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Alış-Satış & Tikinti Mağazaları',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Mağaza və Elanlarım',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: _showMyStoresAndListingsSheet,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Səbətim',
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: _showCartSheet,
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded, size: 22), text: 'Mağazalar & Satıcılar'),
            Tab(icon: Icon(Icons.shopping_bag_rounded, size: 22), text: 'Tikinti Malları & Elanlar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1769D2),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(
          _tabController.index == 0 ? Icons.add_business_rounded : Icons.add_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          _tabController.index == 0 ? 'Mağaza Əlavə Et' : 'Elan Yerləşdir',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _checkSellerPermissionAndRun(() => _showStoreFormSheet());
          } else {
            _checkSellerPermissionAndRun(() => _showProductFormSheet());
          }
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoresTab(),
          _buildProductsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: MAĞAZALAR & SATICILAR
  // ---------------------------------------------------------------------------
  Widget _buildStoresTab() {
    return CustomScrollView(
      slivers: [
        // 1. Reklam Banneri + Axtarış + Kateqoriya Pill-ləri
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              children: [
                // Göy Promo Banner
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1769D2).withOpacity(0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Mağazanızı UstaGo-da Reklam Edin!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5, height: 1.2),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tikinti mallarınızı minlərlə usta və müştəriyə birbaşa satın.',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.25),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1565C0),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () => _checkSellerPermissionAndRun(_showPublishChoiceSheet),
                        child: const Text('Elan Ver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Axtarış + Filtr Düyməsi
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _storeSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                            hintText: 'Mağaza, məhsul və ya ünvan axtar...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            suffixIcon: _storeSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _storeSearchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _showFilterSheet,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF1769D2), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Kateqoriya Seçim Pill-ləri
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _storeCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _storeCategories[index];
                      final isSelected = cat == _selectedStoreCategory;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF1769D2),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSelected ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) => setState(() => _selectedStoreCategory = cat),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Canlı Firestore + Nümunə Mağazalar Siyahısı
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _marketStream,
          initialData: _latestMarketSnapshot,
          builder: (context, snapshot) {
            final docs = (snapshot.data ?? _latestMarketSnapshot)?.docs ?? [];
            final firestoreStores = docs.where((d) {
              final lType = d.data()['listingType']?.toString() ?? 'store';
              return lType == 'store';
            }).map((d) {
              final m = Map<String, dynamic>.from(d.data());
              m['id'] = d.id;
              return m;
            }).toList();

            final List<Map<String, dynamic>> allStores = [...firestoreStores, ..._sampleStores];
            final q = CategoryCityService.normalizeAz(_storeSearchController.text);

            final filtered = allStores.where((s) {
              final cat = CategoryCityService.normalizeAz((s['category'] ?? '').toString());
              final selCat = CategoryCityService.normalizeAz(_selectedStoreCategory);
              if (_selectedStoreCategory != 'Hamısı' && !cat.contains(selCat) && !selCat.contains(cat)) {
                return false;
              }
              if (_selectedCityFilter != 'Hamısı') {
                final addr = CategoryCityService.normalizeAz('${s['city'] ?? ''} ${s['address'] ?? ''}');
                if (!addr.contains(CategoryCityService.normalizeAz(_selectedCityFilter))) return false;
              }
              if (_onlyVerifiedStores && s['isVerified'] != true) return false;
              final favKey = (s['id'] ?? s['sampleId'] ?? s['title']).toString();
              if (_onlyFavorites && !_favoriteIds.contains(favKey)) return false;

              if (q.isEmpty) return true;
              final haystack = CategoryCityService.normalizeAz(
                '${s['title'] ?? ''} ${s['description'] ?? ''} ${s['address'] ?? ''} ${s['city'] ?? ''} ${s['category'] ?? ''}',
              );
              return haystack.contains(q);
            }).toList();

            if (filtered.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Axtarışa və ya filtrə uyğun mağaza tapılmadı.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 92),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) => _buildStoreCard(filtered[idx]),
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoreLogoBox(Map<String, dynamic> store, {double size = 76}) {
    final Uint8List? logoBytes = _decodeB64(store['logoBase64']?.toString());
    if (logoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(logoBytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }

    final Color brandColor = Color(store['brandColorValue'] as int? ?? 0xFF1769D2);
    final Color accentColor = Color(store['accentColorValue'] as int? ?? 0xFFF59E0B);
    final String tag = (store['brandTag'] ?? store['title'] ?? 'MAĞAZA').toString();
    final int iconCode = store['iconCode'] as int? ?? 0;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconCode == 0
                ? Icons.roofing_rounded
                : (iconCode == 1
                    ? Icons.apartment_rounded
                    : (iconCode == 2 ? Icons.domain_rounded : Icons.bolt_rounded)),
            color: iconCode == 0 ? accentColor : brandColor,
            size: size * 0.36,
          ),
          const SizedBox(height: 2),
          Text(
            tag,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: brandColor,
              fontSize: size * 0.135,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final String? docId = store['id']?.toString();
    final String favKey = (docId ?? store['sampleId'] ?? store['title']).toString();
    final bool isFav = _favoriteIds.contains(favKey);
    final currentUser = _authService.currentUser;
    final bool isOwner = docId != null &&
        currentUser != null &&
        (store['ownerId'] == currentUser.uid ||
            store['userId'] == currentUser.uid ||
            currentUser.email?.toLowerCase() == 'mirze3838@gmail.com');

    final double ratingVal = (store['rating'] is num) ? (store['rating'] as num).toDouble() : 4.8;
    final int reviews = (store['reviewCount'] is num) ? (store['reviewCount'] as num).toInt() : 12;
    final String phone = store['phone']?.toString() ?? '';
    final String whatsapp = (store['whatsapp']?.toString().isNotEmpty == true) ? store['whatsapp'].toString() : phone;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDetailScreen(store: store),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreLogoBox(store, size: 78),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              store['title']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (store['isVerified'] != false) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: Color(0xFF1769D2), size: 16),
                          ],
                          const Spacer(),
                          if (isOwner) ...[
                            InkWell(
                              onTap: () => _showStoreFormSheet(existingStore: store),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                              ),
                            ),
                            InkWell(
                              onTap: () => _deleteListing(docId, isStore: true),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              ),
                            ),
                          ],
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isFav) {
                                  _favoriteIds.remove(favKey);
                                } else {
                                  _favoriteIds.add(favKey);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 20,
                                color: isFav ? const Color(0xFFEF4444) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                          const SizedBox(width: 3),
                          Text(
                            ratingVal.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviews rəy)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              store['description']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13.5, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              store['address']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 17, color: Color(0xFF334155)),
                    label: const Text('Xəritədə', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _openStoreOnMap(store),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 17),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _openWhatsApp(whatsapp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: TİKİNTİ MALLARI & ELANLAR (2 SÜTUNLU MƏHSUL QRİDİ)
  // ---------------------------------------------------------------------------
  Widget _buildProductsTab() {
    return CustomScrollView(
      slivers: [
        // 1. Axtarış + Vizual Kateqoriya Kartları
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _productSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                            hintText: 'Məhsul və ya kateqoriya axtar...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            suffixIcon: _productSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _productSearchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _showFilterSheet,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF1769D2), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vizual Kateqoriya İkon Kartları (Hamısı, Sement, Kərpic, Beton, Alətlər...)
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _productCategoryCards.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final card = _productCategoryCards[index];
                      final key = card['key'] as String;
                      final bool isSelected = _selectedProductCategory == key;
                      final Color iconColor = card['color'] as Color;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _selectedProductCategory = key),
                        child: Container(
                          width: 68,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1769D2) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                card['icon'] as IconData,
                                color: isSelected ? Colors.white : iconColor,
                                size: 24,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                card['label'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                ),
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
          ),
        ),

        
        // 2. ★ VIP Elanlar & Elanlar Bölmə Başlığı
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _marketStream,
          initialData: _latestMarketSnapshot,
          builder: (context, snapshot) {
            final docs = (snapshot.data ?? _latestMarketSnapshot)?.docs ?? [];
            final List<Map<String, dynamic>> allVips = [];

            // Firestore-dakı VIP elanlar
            for (final d in docs) {
              final data = d.data();
              if (data['listingType']?.toString() == 'product' && data['isVip'] == true) {
                // 30 gündən köhnə elanlar avtomatik gizlədilir
                if (data['createdAt'] is Timestamp) {
                  final passed = DateTime.now().difference((data['createdAt'] as Timestamp).toDate()).inDays;
                  if (passed >= 30) continue;
                }
                final sName = (data['store']?.toString().isNotEmpty == true)
                    ? data['store'].toString()
                    : (data['storeName']?.toString().isNotEmpty == true ? data['storeName'].toString() : 'Mağaza');
                allVips.add({
                  'id': d.id,
                  'ownerId': data['ownerId'] ?? data['userId'],
                  'userId': data['userId'] ?? data['ownerId'],
                  'title': data['title'] ?? '',
                  'unit': data['unit'] ?? '1 ədəd',
                  'price': data['price'] ?? 'Razılaşma',
                  'store': sName,
                  'city': data['city'] ?? 'Bakı',
                  'category': data['category'] ?? 'Tikinti Materialları',
                  'description': data['description'] ?? '',
                  'imageBase64': data['imageBase64'] ?? '',
                  'imageUrl': data['imageUrl'] ?? '',
                  'isVip': true,
                  'createdAt': data['createdAt'],
                });
              }
            }

            // Nümunə VIP elanlar əlavə edirik
            for (final p in _sampleProducts) {
              if (p['isVip'] == true) {
                allVips.add(Map<String, dynamic>.from(p));
              }
            }

            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allVips.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                              SizedBox(width: 6),
                              Text(
                                'VIP Elanlar',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _tabController.animateTo(0); // Mağazalar tabına keçid
                            },
                            child: Row(
                              children: const [
                                Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF1769D2)),
                                SizedBox(width: 4),
                                Text(
                                  'Mağazalar',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1769D2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 215,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: allVips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final p = allVips[index];
                          return SizedBox(
                            width: 155,
                            child: _buildProductGridCard(p),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // "Elanlar" bölmə başlığı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Elanlar',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '${_selectedProductCategory == 'Hamısı' ? 'Bütün məhsullar' : _selectedProductCategory}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 2. 2 Sütunlu Məhsul Gridi
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _marketStream,
          initialData: _latestMarketSnapshot,
          builder: (context, snapshot) {
            final docs = (snapshot.data ?? _latestMarketSnapshot)?.docs ?? [];
            final List<Map<String, dynamic>> firestoreProducts = [];

            for (final d in docs) {
              final data = d.data();
              if (data['listingType']?.toString() == 'product') {
                final sName = (data['store']?.toString().isNotEmpty == true)
                    ? data['store'].toString()
                    : (data['storeName']?.toString().isNotEmpty == true ? data['storeName'].toString() : 'Mağaza');
                firestoreProducts.add({
                  'id': d.id,
                  'ownerId': data['ownerId'] ?? data['userId'],
                  'userId': data['userId'] ?? data['ownerId'],
                  'title': data['title'] ?? '',
                  'unit': (data['unit']?.toString().isNotEmpty == true) ? data['unit'].toString() : '1 ədəd',
                  'price': (data['price']?.toString().isNotEmpty == true) ? data['price'].toString() : 'Razılaşma',
                  'store': sName,
                  'storeName': sName,
                  'city': (data['city']?.toString().isNotEmpty == true) ? data['city'].toString() : 'Bakı',
                  'address': data['address'] ?? '',
                  'phone': data['phone'] ?? '',
                  'whatsapp': data['whatsapp'] ?? data['phone'] ?? '',
                  'category': data['category'] ?? 'Tikinti Materialları',
                  'description': data['description'] ?? '',
                  'imageBase64': data['imageBase64'] ?? '',
                  'isVip': data['isVip'] == true,
                  'vipUntil': data['vipUntil'],
                  'bumpedAt': data['bumpedAt'],
                  'createdAt': data['createdAt'],
                  'views': data['views'] ?? 48,
                });
              }
            }

            final allProducts = [...firestoreProducts, ..._sampleProducts];
            final q = CategoryCityService.normalizeAz(_productSearchController.text);

            final filtered = allProducts.where((p) {
              if (_selectedProductCategory != 'Hamısı') {
                final cat = CategoryCityService.normalizeAz((p['category'] ?? '').toString());
                final target = CategoryCityService.normalizeAz(_selectedProductCategory);
                final titleNorm = CategoryCityService.normalizeAz((p['title'] ?? '').toString());
                final bool matches = cat.contains(target) ||
                    target.contains(cat) ||
                    titleNorm.contains(target) ||
                    (target == 'beton' && (titleNorm.contains('armatur') || cat.contains('tikinti')));
                if (!matches) return false;
              }
              if (_selectedCityFilter != 'Hamısı') {
                final loc = CategoryCityService.normalizeAz('${p['city'] ?? ''} ${p['address'] ?? ''}');
                if (!loc.contains(CategoryCityService.normalizeAz(_selectedCityFilter))) return false;
              }
              // 30 gündən köhnə elanlar siyahıdan avtomatik çıxarılır
              if (p['createdAt'] is Timestamp) {
                final passed = DateTime.now().difference((p['createdAt'] as Timestamp).toDate()).inDays;
                if (passed >= 30) return false;
              }

              final favKey = (p['id'] ?? p['sampleId'] ?? p['title']).toString();
              if (_onlyFavorites && !_favoriteIds.contains(favKey)) return false;

              if (q.isEmpty) return true;
              final hay = CategoryCityService.normalizeAz(
                '${p['title'] ?? ''} ${p['category'] ?? ''} ${p['store'] ?? ''} ${p['city'] ?? ''} ${p['description'] ?? ''}',
              );
              return hay.contains(q);
            }).toList();

            // VIP və İrəli çəkilmiş elanları ən önə qaldırırıq
            filtered.sort((a, b) {
              if (a['isVip'] == true && b['isVip'] != true) return -1;
              if (b['isVip'] == true && a['isVip'] != true) return 1;
              final ta = a['bumpedAt'] ?? a['createdAt'];
              final tb = b['bumpedAt'] ?? b['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });

            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Axtarışa uyğun tikinti materialı tapılmadı.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildProductGridCard(filtered[index]),
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),

        // 3. Alt Məlumat Banneri
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 92),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _showFilterSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_rounded, color: Color(0xFF1769D2), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daha çox məhsul görmək üçün filtrdən istifadə edin',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductVisual(Map<String, dynamic> prod) {
    final String? imgUrl = prod['imageUrl']?.toString();
    if (imgUrl != null && imgUrl.startsWith('http')) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          final Uint8List? imgBytes = _decodeB64(prod['imageBase64']?.toString());
          if (imgBytes != null) return Image.memory(imgBytes, fit: BoxFit.cover, gaplessPlayback: true);
          return const SizedBox.shrink();
        },
      );
    }
    final Uint8List? imgBytes = _decodeB64(prod['imageBase64']?.toString());
    if (imgBytes != null) {
      return Image.memory(imgBytes, fit: BoxFit.cover, gaplessPlayback: true);
    }

    final vType = prod['visualType']?.toString() ?? '';
    final cat = (prod['category'] ?? '').toString().toLowerCase();

    List<Color> colors;
    IconData icon;
    String badgeText;

    if (vType == 'cement' || cat.contains('sement')) {
      colors = const [Color(0xFFFDE68A), Color(0xFFD97706)];
      icon = Icons.inventory_2_rounded;
      badgeText = 'M500';
    } else if (vType == 'brick' || cat.contains('kərpic')) {
      colors = const [Color(0xFFFDBA74), Color(0xFFC2410C)];
      icon = Icons.grid_view_rounded;
      badgeText = 'KƏRPİC';
    } else if (vType == 'rebar' || cat.contains('beton')) {
      colors = const [Color(0xFFCBD5E1), Color(0xFF475569)];
      icon = Icons.view_week_rounded;
      badgeText = 'ARMATUR';
    } else if (vType == 'drill' || cat.contains('alət')) {
      colors = const [Color(0xFFFEF08A), Color(0xFFB45309)];
      icon = Icons.build_rounded;
      badgeText = 'PRO ALƏT';
    } else {
      colors = const [Color(0xFFDBEAFE), Color(0xFF1769D2)];
      icon = Icons.shopping_bag_rounded;
      badgeText = 'TİKİNTİ';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white.withOpacity(0.95)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> prod) {
    final String? docId = prod['id']?.toString();
    final String favKey = (docId ?? prod['sampleId'] ?? prod['title']).toString();
    final bool isFav = _favoriteIds.contains(favKey);
    final currentUser = _authService.currentUser;
    final bool isOwner = docId != null &&
        currentUser != null &&
        (prod['ownerId'] == currentUser.uid ||
            prod['userId'] == currentUser.uid ||
            currentUser.email?.toLowerCase() == 'mirze3838@gmail.com');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: prod),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: prod['isVip'] == true ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
            width: prod['isVip'] == true ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 7, offset: const Offset(0, 3)),
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
                    child: _buildProductVisual(prod),
                  ),
                  // Üst-sağ Seçilmişlər düyməsi
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isFav) {
                            _favoriteIds.remove(favKey);
                          } else {
                            _favoriteIds.add(favKey);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF1769D2),
                        ),
                      ),
                    ),
                  ),

                  // Alt-sol "Mağaza" nişanı (Nümunə Şəkil 1-ə tam uyğun)
                  if ((prod['store'] ?? prod['storeName'] ?? '').toString().isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Mağaza',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // Alt-sağ VIP Ulduz nişanı (Nümunə Şəkil 1 & 2-yə tam uyğun)
                  if (prod['isVip'] == true)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1769D2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                  if (isOwner)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _showProductFormSheet(existingProduct: prod),
                            child: Container(
                              padding: const EdgeInsets.all(4.5),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle),
                              child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1769D2)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _deleteListing(docId, isStore: false),
                            child: Container(
                              padding: const EdgeInsets.all(4.5),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle),
                              child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Məlumat sahəsi
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      prod['unit']?.toString() ?? '1 ədəd',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prod['price']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1769D2)),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final sName = (prod['store'] ?? prod['storeName'] ?? 'Mağaza').toString();
                              final sOwner = (prod['ownerId'] ?? prod['userId'] ?? '').toString();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoreDetailScreen(
                                    store: {
                                      'title': sName,
                                      'ownerId': sOwner,
                                      'userId': sOwner,
                                      'phone': prod['phone'] ?? '',
                                      'whatsapp': prod['whatsapp'] ?? prod['phone'] ?? '',
                                      'address': prod['address'] ?? prod['city'] ?? 'Bakı',
                                      'city': prod['city'] ?? 'Bakı',
                                      'category': prod['category'] ?? 'Tikinti Materialları',
                                      'description': 'Bu mağazanın aktiv məhsul və elanları.',
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 11.5, color: Color(0xFF1769D2)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    prod['store']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF1769D2), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF94A3B8)),
                        Text(
                          prod['city']?.toString() ?? 'Bakı',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1769D2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                        label: const Text(
                          'Səbətə əlavə et',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _addToCart(prod),
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

  void _showProductDetailSheet(Map<String, dynamic> prod) {
    final String phone = prod['phone']?.toString() ?? '';
    final String wa = (prod['whatsapp']?.toString().isNotEmpty == true) ? prod['whatsapp'].toString() : phone;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(height: 150, width: double.infinity, child: _buildProductVisual(prod)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prod['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  prod['price']?.toString() ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${prod['unit'] ?? '1 ədəd'} • ${prod['store'] ?? ''} • ${prod['city'] ?? 'Bakı'}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            if ((prod['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(prod['description'].toString(), style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _makeCall(phone);
                    },
                    icon: const Icon(Icons.call, size: 17),
                    label: const Text('Zəng et'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openWhatsApp(wa, message: 'Salam, ${prod['title']} (${prod['price']}) haqqında məlumat almaq istəyirəm.');
                    },
                    icon: const Icon(Icons.chat, size: 17),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1769D2), foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addToCart(prod);
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                    label: const Text('Səbətə at'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
