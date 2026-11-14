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

  // Standart Başlanğıc Şəhər və Rayonlar (Azərbaycanın bütün bölgələri)
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
    'Xankəndi',
    'Şuşa',
    'Qusar',
    'Xaçmaz',
    'Qəbələ',
    'İsmayıllı',
    'Şamaxı',
    'Masallı',
    'Cəlilabad',
    'Astara',
    'Lerik',
    'Yardımlı',
    'Bərdə',
    'Ağcabədi',
    'Ağdam',
    'Tərtər',
    'Füzuli',
    'Laçın',
    'Kəlbəcər',
    'Zaqatala',
    'Balakən',
    'Qax',
    'Oğuz',
    'Göyçay',
    'Ağdaş',
    'Ucar',
    'Kürdəmir',
    'Zərdab',
    'Ağsu',
    'Qobustan',
    'Yevlax',
    'Goranboy',
    'Şəmkir',
    'Tovuz',
    'Ağstafa',
    'Qazax',
    'Gədəbəy',
    'Daşkəsən',
    'Göygöl',
    'Samux',
    'Sabirabad',
    'Saatlı',
    'İmişli',
    'Beyləqan',
    'Salyan',
    'Neftçala',
    'Biləsuvar',
    'Hacıqabul',
    'Siyəzən',
    'Şabran',
    'Xızı',
    'Babək',
    'Culfa',
    'Ordubad',
    'Şərur',
    'Şahbuz',
    'Kəngərli',
    'Sədərək',
  ];

  // Şəhər / Rayonlar üzrə Rayon, Qəsəbə və Kəndlər
  static const Map<String, List<String>> villagesByRegion = {
    'Bakı': [
      'Yasamal',
      'Nəsimi',
      'Nərimanov',
      'Nizami',
      'Xətai',
      'Səbail',
      'Binəqədi',
      'Sabunçu',
      'Suraxanı',
      'Xəzər',
      'Qaradağ',
      'Pirallahı',
      'Maştağa',
      'Bilgəh',
      'Buzovna',
      'Mərdəkan',
      'Şüvəlan',
      'Binə',
      'Hövsan',
      'Qaraçuxur',
      'Bakıxanov',
      'Zabrat',
      'Mehdiabad',
      'Badamdar',
      'Lökbatan',
      'Sulutəpə',
      'Biləcəri',
      'Pirşağı',
      'Nardaran',
      'Kürdəxanı',
      'Balaxanı',
      'Ramana',
      'Zirə',
      'Türkan',
      'Qala',
      'Əhmədli',
      'Günəşli',
      'Əmircan',
      'Bülbülə',
      'Zığ',
      'Şağan',
      'Şıxov',
      'Sahil',
      'Səngəçal',
      'Ələt',
    ],
    'Sumqayıt': [
      'Mərkəz',
      'Corat',
      'Hacı Zeynalabdin',
      'Saray',
      'Novxanı',
      'Yaşma',
      '17-ci mikrorayon',
      '9-cu mikrorayon',
      'Kimyaçılar qəsəbəsi',
    ],
    'Xırdalan': [
      'Mərkəz',
      'Masazır',
      'Saray',
      'Novxanı',
      'Mehdiabad',
      'Digah',
      'Məmmədli',
      'Görədil',
      'Fatmayı',
      'Hökməli',
      'Qobu',
      'Güzdək',
      'Aşağı Güzdək',
      'Ceyranbatan',
      'Pereküşkül',
    ],
    'Gəncə': [
      'Mərkəz',
      'Kəpəz',
      'Nizami',
      'Gülüstan',
      'Yeni Gəncə',
      'Bağmanlar',
      'Cavadbəyli',
      'Hacıkənd',
      'Məhsəti qəsəbəsi',
      'Natəvan qəsəbəsi',
    ],
    'Mingəçevir': ['Mərkəz', 'Energetiklər', 'Günəşli', 'Kür qırağı', 'Həzi Aslanov'],
    'Şirvan': ['Mərkəz', 'Bayramlı', 'Hacıqəhrəmanlı', 'Çılpaqlı', 'Kür'],
    'Naxçıvan': ['Mərkəz', 'Əliabad', 'Qaraçuq', 'Bulqan', 'Tumbul', 'Xəlilli'],
    'Şəki': [
      'Mərkəz',
      'Kiş',
      'Oxud',
      'Baş Göynük',
      'Aşağı Göynük',
      'Baş Layısqı',
      'Cəfərabad',
      'Turut',
      'Orta Zəyzid',
      'Bideyiz',
      'Aydınbulaq',
      'Cumakənd',
    ],
    'Quba': [
      'Mərkəz',
      'Qırmızı Qəsəbə',
      'Xınalıq',
      'Qəçrəş',
      'Nügədi',
      'Birinci Nügədi',
      'İkinci Nügədi',
      'Amsar',
      'Alpan',
      'Rustov',
      'Zərdabi',
      'Təngəaltı',
      'Alekseyevka',
      'Vladimirovka',
    ],
    'Qusar': ['Mərkəz', 'Ləzə', 'Hil', 'Həzrə', 'Urva', 'Şahdağ', 'Bala Qusar', 'Kuzun'],
    'Xaçmaz': ['Mərkəz', 'Xudat', 'Nabran', 'Yalama', 'Nərəcan', 'Köhmə Xaçmaz', 'Qusarçay', 'Çarxı'],
    'Qəbələ': ['Mərkəz', 'Vəndam', 'Nic', 'Bum', 'Həzrə', 'Zarağan', 'Tüntül', 'Laza', 'Qəmərvan', 'Durca'],
    'İsmayıllı': ['Mərkəz', 'Lahıc', 'Basqal', 'İvanovka', 'Buynuz', 'Talıstan', 'Topçu', 'Qubaxəlilli', 'Təzəkənd'],
    'Şamaxı': ['Mərkəz', 'Pirqulu', 'Çuxuryurd', 'Məlhəm', 'Sabir qəsəbəsi', 'Dəmirçi', 'Avaxıl', 'Mədrəsə'],
    'Lənkəran': [
      'Mərkəz',
      'Liman',
      'Nərimanabad',
      'Xanbulan',
      'Separadi',
      'Kərgəlan',
      'Gərmətük',
      'Boladı',
      'Veravul',
      'Bürcəli',
      'Osaküçə',
      'Haftoni',
    ],
    'Masallı': ['Mərkəz', 'Ərkivan', 'Boradigah', 'Bədəlan', 'Hışkədərə', 'Viləş', 'Təklə', 'Qızılavar', 'Banbaşı'],
    'Cəlilabad': ['Mərkəz', 'Göytəpə', 'Alar', 'Privolnoye', 'Günəşli', 'Üçtəpə', 'Muğan', 'Qarazəncir'],
    'Astara': ['Mərkəz', 'Ərçivan', 'Şahağac', 'Pensər', 'Kijəbə', 'Kakalos', 'Sım', 'Siyaku'],
    'Lerik': ['Mərkəz', 'Piran', 'Hamarmişə', 'Cəngəmiran', 'Noda', 'Bürsülüm', 'Gürdəsər'],
    'Yardımlı': ['Mərkəz', 'Ostayırr', 'Bozayran', 'Alar', 'Şəfəqli', 'Arvana'],
    'Bərdə': ['Mərkəz', 'Lənbəran', 'Alpout', 'Gərənə', 'Kətəlparaq', 'Qarayusifli', 'Soğanverdilər', 'Nazırlı'],
    'Ağcabədi': ['Mərkəz', 'Hindarx', 'Boyat', 'Hüsülü', 'Muğanlı', 'Avşar', 'Salmanbəyli'],
    'Ağdam': ['Mərkəz', 'Quzanlı', 'Xındırıstan', 'Üçoğlan', 'Bənövşələr', 'Əhmədağalı', 'Zəngişalı'],
    'Tərtər': ['Mərkəz', 'Şıxarx', 'Seysulan', 'Borsunlu', 'Sarov', 'Qapanlı', 'Evoğlu'],
    'Füzuli': ['Mərkəz', 'Horadiz', 'Böyük Bəhmənli', 'Kürdmahmudlu', 'Qayıdış', 'Zobucuq'],
    'Laçın': ['Mərkəz', 'Zabux', 'Sus', 'Qorçu', 'Bəyik', 'Minkənd'],
    'Kəlbəcər': ['Mərkəz', 'İstisu', 'Zülfüqarlı', 'Vəng', 'Yanşaq'],
    'Şuşa': ['Mərkəz', 'Daşaltı', 'Turşsu', 'Xəlfəli', 'Malıbəyli'],
    'Xankəndi': ['Mərkəz', 'Kərkicahan'],
    'Zaqatala': ['Mərkəz', 'Car', 'Əliabad', 'Danaçı', 'Muğanlı', 'Yuxarı Tala', 'Aşağı Tala', 'Gözbarax', 'Kebəloba'],
    'Balakən': ['Mərkəz', 'Qabaqçöl', 'Mahamalar', 'Katex', 'Tülü', 'Hənifə', 'Gərəkli'],
    'Qax': ['Mərkəz', 'İlisu', 'Qum', 'Ləkit', 'Tasmalı', 'Almalı', 'Zərnə', 'Qaxbaş'],
    'Oğuz': ['Mərkəz', 'Xalxal', 'Böyük Söyüdlü', 'Padar', 'Qumlaq', 'Bucaq', 'Kərimli'],
    'Göyçay': ['Mərkəz', 'Qarabaqqal', 'Çərəkə', 'Potu', 'Bığır', 'Ləkçılpaq', 'İnçə', 'Şəhadət'],
    'Ağdaş': ['Mərkəz', 'Ləki', 'Türyançay', 'Pirəzə', 'Aşağı Ləki', 'Qülbəndə', 'Ağzıbir'],
    'Ucar': ['Mərkəz', 'Qazyan', 'Alpout', 'Bərgüşad', 'Lək', 'Müsüsü', 'Boyat'],
    'Kürdəmir': ['Mərkəz', 'Karrar', 'Atakişili', 'Şilyan', 'Mollakənd', 'Sığırlı', 'Qarasu'],
    'Zərdab': ['Mərkəz', 'Bəyimli', 'Dəkkəoba', 'Məlikli', 'Əlvənd', 'Şıxbağı'],
    'Ağsu': ['Mərkəz', 'Ləngəbiz', 'Padar', 'Bico', 'Gəgəli', 'Pirhəsənli'],
    'Qobustan': ['Mərkəz', 'Mərəzə', 'Cəngi', 'Təklə', 'Bədəlli', 'Sündü'],
    'Yevlax': ['Mərkəz', 'Aran', 'Xaldan', 'Qoyunbinəsi', 'Havərli', 'Səmədabad'],
    'Goranboy': ['Mərkəz', 'Dəliməmmədli', 'Qızılhacılı', 'Səfikürd', 'Borsunlu', 'Aşağı Ağcakənd'],
    'Şəmkir': ['Mərkəz', 'Dəllər', 'Çinarlı', 'Zəyəm', 'Kür', 'Təzəkənd', 'Düyərli', 'Könüllü', 'Morul'],
    'Tovuz': ['Mərkəz', 'Qovlar', 'Aşağı Quşçu', 'Düz Qırıqlı', 'Əlimərdanlı', 'Bozalqanlı', 'Dönük Qırıqlı', 'Əyyublu'],
    'Ağstafa': ['Mərkəz', 'Poylu', 'Dağ Kəsəmən', 'Qıraq Kəsəmən', 'Köçəsgər', 'Zəlimxan'],
    'Qazax': ['Mərkəz', 'Daş Salahlı', 'Çaylı', 'Aşağı Əskipara', 'Kəmərli', 'Qaymaqlı', 'Aslanbəyli'],
    'Gədəbəy': ['Mərkəz', 'Slavyanka', 'Şınıx', 'Novosaratovka', 'Söyüdlü', 'Zəhmət'],
    'Daşkəsən': ['Mərkəz', 'Xoşbulaq', 'Bayan', 'Quşçu', 'Zəylik'],
    'Göygöl': ['Mərkəz', 'Hacıməlik', 'Toğanalı', 'Çaykənd', 'Balçılı', 'Üçtəpə'],
    'Samux': ['Mərkəz', 'Nəbiağalı', 'Qarayeri', 'İnstitut qəsəbəsi', 'Alabaşlı'],
    'Sabirabad': ['Mərkəz', 'Cavadd', 'Qarağaclı', 'Qaratəpə', 'Şəhriyar', 'Ulacalı', 'Nizami'],
    'Saatlı': ['Mərkəz', 'Məzrəli', 'Qıraqlı', 'Nərimankənd', 'Varxankənd'],
    'İmişli': ['Mərkəz', 'Bəhramtəpə', 'Oruclu', 'Qaradonlu', 'Sarxanlı', 'Məzrəli'],
    'Beyləqan': ['Mərkəz', 'Milabad', 'Birinci Şahsevən', 'Kəbirli', 'Dünyamalılar', 'Örənqala'],
    'Salyan': ['Mərkəz', 'Qaraçala', 'Xıllı', 'Şorsulu', 'Babazənan', 'Marışlı', 'Arbatan'],
    'Neftçala': ['Mərkəz', 'Bankə', 'Xıllı', 'Həsənabad', 'Qoltuq', 'Tatarməhlə'],
    'Biləsuvar': ['Mərkəz', 'Xırmandalı', 'Bəydili', 'Bağbanlar', 'Əsgərabad', 'Nəsimi'],
    'Hacıqabul': ['Mərkəz', 'Navahı', 'Muğan', 'Qızılburun', 'Atbulaq', 'Rəncbər'],
    'Siyəzən': ['Mərkəz', 'Gilgilçay', 'Zarat', 'Beşdam', 'Eynibulaq'],
    'Şabran': ['Mərkəz', 'Gəndob', 'Pirəbədil', 'Rəhimli', 'Padar', 'Sözü'],
    'Xızı': ['Mərkəz', 'Altıağac', 'Giləzi', 'Şorabad', 'Baxışlı'],
    'Babək': ['Mərkəz', 'Nehrəm', 'Cəhri', 'Təzəkənd', 'Qahab', 'Şıxmahmud'],
    'Culfa': ['Mərkəz', 'Bənəniyar', 'Əbrəqunus', 'Yaycı', 'Kırna'],
    'Ordubad': ['Mərkəz', 'Vənənd', 'Dəstə', 'Aza', 'Nüsnüs', 'Sabirkənd'],
    'Şərur': ['Mərkəz', 'Püsyan', 'Yengicə', 'Cəlilkənd', 'Oğlanqala'],
    'Şahbuz': ['Mərkəz', 'Badamlı', 'Kükü', 'Biçənək', 'Kolani'],
    'Kəngərli': ['Qıvraq', 'Şahtaxtı', 'Qarabağlar', 'Xok'],
    'Sədərək': ['Heydərabad', 'Sədərək kəndi', 'Dəmirçi'],
  };

  /// Azərbaycan dilindəki hərfləri axtarış üçün standartlaşdırır (məs: Maştağa == mastaga)
  static String normalizeAz(String input) {
    return input
        .toLowerCase()
        .replaceAll('ə', 'e')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ı', 'i')
        .trim();
  }

  /// Seçilmiş şəhər/rayon üçün rayon, qəsəbə və kənd siyahısını qaytarır
  static List<String> getVillagesForRegion(String region) {
    final normTarget = normalizeAz(region);
    for (final entry in villagesByRegion.entries) {
      if (normalizeAz(entry.key) == normTarget) {
        return entry.value;
      }
    }
    return const ['Mərkəz', 'Qəsəbə', 'Kənd ərazisi'];
  }

  /// Axtarış sözünə görə Azərbaycanın rayon, qəsəbə və kəndlərini tapır
  static List<Map<String, String>> searchLocations(String query, {int maxResults = 15}) {
    final q = normalizeAz(query);
    if (q.isEmpty) return [];

    final List<Map<String, String>> results = [];
    final Set<String> seen = {};

    void addResult(String region, String village) {
      if (results.length >= maxResults) return;
      final key = '${normalizeAz(region)}|${normalizeAz(village)}';
      if (seen.contains(key)) return;
      seen.add(key);
      results.add({
        'region': region,
        'village': village,
        'display': village.isEmpty ? region : '$region, $village',
      });
    }

    // 1. Başlayan (exact prefix) uyğunluqlar ön sırada
    for (final region in defaultCities) {
      if (normalizeAz(region).startsWith(q)) {
        addResult(region, '');
      }
      final villages = villagesByRegion[region] ?? const <String>[];
      for (final v in villages) {
        if (normalizeAz(v).startsWith(q)) {
          addResult(region, v);
        }
      }
    }

    // 2. İçində keçən (contains) uyğunluqlar
    if (results.length < maxResults) {
      for (final region in defaultCities) {
        if (normalizeAz(region).contains(q)) {
          addResult(region, '');
        }
        final villages = villagesByRegion[region] ?? const <String>[];
        for (final v in villages) {
          if (normalizeAz(v).contains(q)) {
            addResult(region, v);
          }
        }
      }
    }

    return results;
  }

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

  /// Kateqoriyaya / peşəyə uyğun gözəl HD başlıq kadr fotosu (videolarda qaranlıq qalmamaq üçün)
  static String getCategoryPlaceholderImage(String? trade) {
    final t = (trade ?? '').toLowerCase();
    if (t.contains('santexnik') || t.contains('su') || t.contains('kafel') || t.contains('metlax')) {
      return 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('elektrik') || t.contains('şit') || t.contains('naqil')) {
      return 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('kondisioner') || t.contains('kombi') || t.contains('soyuducu') || t.contains('iqlim')) {
      return 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('mebel') || t.contains('dülgər')) {
      return 'https://images.unsplash.com/photo-1538688525198-9b88f6f53126?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('avto') || t.contains('avtomobil') || t.contains('maşın')) {
      return 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('rəngsaz') || t.contains('malyar') || t.contains('boya')) {
      return 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('qapı') || t.contains('pəncərə')) {
      return 'https://images.unsplash.com/photo-1509644851169-2acc08aa25b5?auto=format&fit=crop&w=600&q=80';
    } else if (t.contains('təmizlik') || t.contains('xadimə')) {
      return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80';
    }
    // Tikinti və ümumi usta işləri üçün keyfiyyətli real kadr
    return 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=600&q=80';
  }
}
