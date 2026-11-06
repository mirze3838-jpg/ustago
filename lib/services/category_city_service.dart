import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryCityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Standart Başlanğıc Kateqoriyalar
  static final List<Map<String, dynamic>> defaultCategories = [
    {
      'id': 'def_tikinti',
      'title': 'Tikinti',
      'icon': Icons.foundation,
      'color': const Color(0xFFE65100),
      'bgColor': const Color(0xFFFBE9E7),
      'isCustom': false,
    },
    {
      'id': 'def_santexnik',
      'title': 'Santexnik',
      'icon': Icons.water_drop,
      'color': const Color(0xFF1976D2),
      'bgColor': const Color(0xFFE3F2FD),
      'isCustom': false,
    },
    {
      'id': 'def_elektrik',
      'title': 'Elektrik',
      'icon': Icons.bolt,
      'color': const Color(0xFFFBC02D),
      'bgColor': const Color(0xFFFFFDE7),
      'isCustom': false,
    },
    {
      'id': 'def_temir',
      'title': 'Təmir və\nQuraşdırma',
      'icon': Icons.build_rounded,
      'color': const Color(0xFF0288D1),
      'bgColor': const Color(0xFFE1F5FE),
      'isCustom': false,
    },
    {
      'id': 'def_avto',
      'title': 'Avtomobil\nUstası',
      'icon': Icons.directions_car_filled,
      'color': const Color(0xFF0277BD),
      'bgColor': const Color(0xFFE1F5FE),
      'isCustom': false,
    },
    {
      'id': 'def_mebel',
      'title': 'Mebel\nUstası',
      'icon': Icons.chair,
      'color': const Color(0xFFE67E22),
      'bgColor': const Color(0xFFFDF2E9),
      'isCustom': false,
    },
    {
      'id': 'def_kondisioner',
      'title': 'Kondisioner\nUstası',
      'icon': Icons.ac_unit,
      'color': const Color(0xFF29B6F6),
      'bgColor': const Color(0xFFE1F5FE),
      'isCustom': false,
    },
    {
      'id': 'def_dulger',
      'title': 'Dülgər',
      'icon': Icons.hardware,
      'color': const Color(0xFF8D6E63),
      'bgColor': const Color(0xFFEFEBE9),
      'isCustom': false,
    },
    {
      'id': 'def_rengsaz',
      'title': 'Rəngsaz',
      'icon': Icons.format_paint,
      'color': const Color(0xFFFF7043),
      'bgColor': const Color(0xFFFBE9E7),
      'isCustom': false,
    },
    {
      'id': 'def_diger',
      'title': 'Digər\nKateqoriyalar',
      'icon': Icons.more_horiz,
      'color': const Color(0xFF1565C0),
      'bgColor': const Color(0xFFE8EAF6),
      'isCustom': false,
    },
  ];

  // Standart Başlanğıc Şəhərlər
  static const List<String> defaultCities = [
    'Bakı',
    'Sumqayıt',
    'Gəncə',
    'Xırdalan',
    'Mingəçevir',
    'Şirvan',
    'Naxçıvan',
    'Şəki',
    'Quba',
    'Lənkəran',
  ];

  // Sabit ikon uyğunluğu (Tree shaking xətalarının qarşısını alır)
  static IconData getIconByCode(int? code) {
    if (code == null) return Icons.handyman;
    if (code == Icons.handyman.codePoint) return Icons.handyman;
    if (code == Icons.cleaning_services.codePoint) return Icons.cleaning_services;
    if (code == Icons.roofing.codePoint) return Icons.roofing;
    if (code == Icons.yard.codePoint) return Icons.yard;
    if (code == Icons.plumbing.codePoint) return Icons.plumbing;
    if (code == Icons.kitchen.codePoint) return Icons.kitchen;
    if (code == Icons.tv.codePoint) return Icons.tv;
    if (code == Icons.security.codePoint) return Icons.security;
    if (code == Icons.local_shipping.codePoint) return Icons.local_shipping;
    if (code == Icons.brush.codePoint) return Icons.brush;
    if (code == Icons.solar_power.codePoint) return Icons.solar_power;
    if (code == Icons.lock.codePoint) return Icons.lock;
    if (code == Icons.pest_control.codePoint) return Icons.pest_control;
    if (code == Icons.camera_alt.codePoint) return Icons.camera_alt;
    return Icons.handyman;
  }

  // Canlı Kateqoriyalar axını (Standart + Firestore-dan Admin tərəfindən əlavə edilmişlər)
  static Stream<List<Map<String, dynamic>>> getCategoriesStream() {
    return _firestore
        .collection('categories')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<Map<String, dynamic>> list = List.from(defaultCategories);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String title = data['title'] ?? data['name'] ?? '';
        if (title.isEmpty) continue;

        // Eyni adda təkrar olmasın
        final cleanTitle = title.replaceAll('\n', ' ').trim().toLowerCase();
        final exists = list.any(
          (c) => (c['title'] as String).replaceAll('\n', ' ').trim().toLowerCase() == cleanTitle,
        );
        if (exists) continue;

        int? iconCode = data['iconCode'];
        int colorValue = data['color'] ?? 0xFF1976D2;
        int bgColorValue = data['bgColor'] ?? 0xFFE3F2FD;

        list.add({
          'id': doc.id,
          'title': title,
          'icon': getIconByCode(iconCode),
          'color': Color(colorValue),
          'bgColor': Color(bgColorValue),
          'isCustom': true,
        });
      }

      return list;
    });
  }

  // Canlı Şəhərlər axını (Standart + Admin əlavələri)
  static Stream<List<String>> getCitiesStream() {
    return _firestore
        .collection('cities')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final Set<String> citySet = Set.from(defaultCities);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String name = (data['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          citySet.add(name);
        }
      }

      return citySet.toList();
    });
  }

  // Admin: Yeni kateqoriya əlavə et
  static Future<void> addCategory({
    required String title,
    IconData icon = Icons.handyman,
    Color color = const Color(0xFF1976D2),
    Color bgColor = const Color(0xFFE3F2FD),
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;

    await _firestore.collection('categories').add({
      'title': clean,
      'iconCode': icon.codePoint,
      'color': color.value,
      'bgColor': bgColor.value,
      'isCustom': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Admin: Kateqoriyanı sil
  static Future<void> deleteCategory(String docId) async {
    await _firestore.collection('categories').doc(docId).delete();
  }

  // Admin: Yeni şəhər əlavə et
  static Future<void> addCity(String cityName) async {
    final clean = cityName.trim();
    if (clean.isEmpty) return;

    final docId = clean.replaceAll(' ', '_').toLowerCase();
    await _firestore.collection('cities').doc(docId).set({
      'name': clean,
      'isCustom': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Admin: Şəhəri sil
  static Future<void> deleteCity(String cityName) async {
    final docId = cityName.trim().replaceAll(' ', '_').toLowerCase();
    await _firestore.collection('cities').doc(docId).delete();
  }
}
