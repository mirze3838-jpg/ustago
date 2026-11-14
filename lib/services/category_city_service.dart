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
      'Qobu',
      'Hökməli',
      'Xocasən',
      'Keşlə',
      '8-ci km',
      'Ağ Şəhər',
      'Bayıl',
      'İçərişəhər',
      'Yeni Yasamal',
      'Montin',
      'Neftçilər',
      'Xalqlar Dostluğu',
      'Həzi Aslanov',
      'Koroğlu',
      'Qara Qarayev',
      'Yeni Suraxanı',
    ],
    'Sumqayıt': [
      'Mərkəz',
      'Corat',
      'Hacı Zeynalabdin',
      'Saray',
      'Novxanı',
      'Ceyranbatan',
      'Qobu',
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

  // ===================================================================
  // ÇOXSEÇİMLİ İXTİSAS KATALOQU (Usta və Fəhlə qeydiyyatı üçün)
  // Hər ixtisasın sabit ID-si bazada `specialtyIds` siyahısında saxlanılır.
  // ===================================================================
  static final List<Map<String, dynamic>> specialtyGroups = [
    {
      'id': 'grp_tikinti',
      'title': 'Tikinti və təmir',
      'icon': Icons.construction_rounded,
      'color': const Color(0xFFE65100),
      'bgColor': const Color(0xFFFBE9E7),
      'items': <Map<String, String>>[
        {'id': 'sp_umumi_tikinti', 'title': 'Ümumi tikinti ustası'},
        {'id': 'sp_santexnik', 'title': 'Santexnik'},
        {'id': 'sp_elektrik', 'title': 'Elektrik ustası'},
        {'id': 'sp_kafel', 'title': 'Kafel-metlax ustası'},
        {'id': 'sp_suvaq', 'title': 'Suvaq ustası'},
        {'id': 'sp_malyar', 'title': 'Malyar və rəngsaz'},
        {'id': 'sp_qaynaq', 'title': 'Qaynaq (svarka) ustası'},
        {'id': 'sp_alcipan', 'title': 'Alçıpan ustası'},
        {'id': 'sp_dam', 'title': 'Dam örtüyü ustası'},
        {'id': 'sp_beton', 'title': 'Beton ustası'},
        {'id': 'sp_armatur', 'title': 'Armatur ustası'},
        {'id': 'sp_fasad', 'title': 'Fasad ustası'},
        {'id': 'sp_laminat', 'title': 'Laminat ustası'},
        {'id': 'sp_parket', 'title': 'Parket ustası'},
        {'id': 'sp_dulger', 'title': 'Dülgər'},
        {'id': 'sp_mebel', 'title': 'Mebel ustası'},
        {'id': 'sp_qapi_pencere', 'title': 'Qapı-pəncərə ustası'},
        {'id': 'sp_izolyasiya', 'title': 'İzolyasiya ustası'},
      ],
    },
    {
      'id': 'grp_elektronika',
      'title': 'Telefon və elektronika',
      'icon': Icons.smartphone_rounded,
      'color': const Color(0xFF1565C0),
      'bgColor': const Color(0xFFE3F2FD),
      'items': <Map<String, String>>[
        {'id': 'sp_telefon', 'title': 'Telefon ustası'},
        {'id': 'sp_iphone', 'title': 'iPhone təmiri'},
        {'id': 'sp_android', 'title': 'Android telefon təmiri'},
        {'id': 'sp_ekran_sensor', 'title': 'Telefon ekranı və sensor dəyişimi'},
        {'id': 'sp_telefon_proqram', 'title': 'Telefon proqram təminatı'},
        {'id': 'sp_planset', 'title': 'Planşet ustası'},
        {'id': 'sp_komputer', 'title': 'Kompüter ustası'},
        {'id': 'sp_noutbuk', 'title': 'Noutbuk ustası'},
        {'id': 'sp_tv', 'title': 'Televizor (TV) ustası'},
        {'id': 'sp_monitor', 'title': 'Monitor ustası'},
        {'id': 'sp_printer', 'title': 'Printer ustası'},
        {'id': 'sp_audio', 'title': 'Audio və səs avadanlıqları ustası'},
      ],
    },
    {
      'id': 'grp_konsol',
      'title': 'Oyun konsolları',
      'icon': Icons.sports_esports_rounded,
      'color': const Color(0xFF6A1B9A),
      'bgColor': const Color(0xFFF3E5F5),
      'items': <Map<String, String>>[
        {'id': 'sp_playstation', 'title': 'PlayStation ustası'},
        {'id': 'sp_ps4', 'title': 'PS4 təmiri'},
        {'id': 'sp_ps5', 'title': 'PS5 təmiri'},
        {'id': 'sp_xbox', 'title': 'Xbox ustası'},
        {'id': 'sp_pult', 'title': 'Oyun pultu təmiri'},
        {'id': 'sp_konsol_proqram', 'title': 'Oyun konsolu proqram təminatı'},
      ],
    },
    {
      'id': 'grp_meiset',
      'title': 'Məişət avadanlıqları',
      'icon': Icons.kitchen_rounded,
      'color': const Color(0xFF00838F),
      'bgColor': const Color(0xFFE0F7FA),
      'items': <Map<String, String>>[
        {'id': 'sp_soyuducu', 'title': 'Soyuducu ustası'},
        {'id': 'sp_paltaryuyan', 'title': 'Paltaryuyan ustası'},
        {'id': 'sp_qabyuyan', 'title': 'Qabyuyan ustası'},
        {'id': 'sp_kondisioner', 'title': 'Kondisioner ustası'},
        {'id': 'sp_kombi', 'title': 'Kombi ustası'},
        {'id': 'sp_su_qizdirici', 'title': 'Su qızdırıcısı ustası'},
        {'id': 'sp_mikrodalga', 'title': 'Mikrodalğalı soba ustası'},
        {'id': 'sp_elektrik_soba', 'title': 'Elektrik sobası ustası'},
        {'id': 'sp_tozsoran', 'title': 'Tozsoran ustası'},
      ],
    },
    {
      'id': 'grp_avto',
      'title': 'Avtomobil təmiri',
      'icon': Icons.directions_car_filled_rounded,
      'color': const Color(0xFF0277BD),
      'bgColor': const Color(0xFFE1F5FE),
      'items': <Map<String, String>>[
        {'id': 'sp_avtoelektrik', 'title': 'Avtoelektrik'},
        {'id': 'sp_motor', 'title': 'Motor ustası'},
        {'id': 'sp_suretler_qutusu', 'title': 'Sürətlər qutusu ustası'},
        {'id': 'sp_diaqnostika', 'title': 'Avtomobil diaqnostikası'},
        {'id': 'sp_avto_rengsaz', 'title': 'Avtomobil rəngsazı'},
        {'id': 'sp_kuzov', 'title': 'Kuzov ustası'},
        {'id': 'sp_teker', 'title': 'Təkər ustası'},
        {'id': 'sp_avto_kondisioner', 'title': 'Avtomobil kondisioneri ustası'},
        {'id': 'sp_avto_qaynaq', 'title': 'Avtomobil qaynaq ustası'},
      ],
    },
    {
      'id': 'grp_diger',
      'title': 'Digər xidmətlər',
      'icon': Icons.miscellaneous_services_rounded,
      'color': const Color(0xFF2E7D32),
      'bgColor': const Color(0xFFE8F5E9),
      'items': <Map<String, String>>[
        {'id': 'sp_kilid', 'title': 'Kilid ustası'},
        {'id': 'sp_suse', 'title': 'Şüşə ustası'},
        {'id': 'sp_jaluz', 'title': 'Jalüz və pərdə ustası'},
        {'id': 'sp_mebel_yigilmasi', 'title': 'Mebel yığılması'},
        {'id': 'sp_kamera', 'title': 'Kamera və müşahidə sistemi ustası'},
        {'id': 'sp_internet', 'title': 'İnternet və şəbəkə ustası'},
        {'id': 'sp_gunes_paneli', 'title': 'Günəş paneli ustası'},
        {'id': 'sp_su_nasosu', 'title': 'Su nasosu ustası'},
        {'id': 'sp_heyet_bag', 'title': 'Həyət və bağ işləri'},
      ],
    },
  ];

  /// İxtisas ID-si üzrə {id, title, groupId, groupTitle} qaytarır
  static Map<String, String>? findSpecialtyById(String id) {
    for (final g in specialtyGroups) {
      for (final item in (g['items'] as List<Map<String, String>>)) {
        if (item['id'] == id) {
          return {
            'id': id,
            'title': item['title']!,
            'groupId': g['id'] as String,
            'groupTitle': g['title'] as String,
          };
        }
      }
    }
    return null;
  }

  /// Seçilmiş ixtisaslardan köhnə tək `category` sahəsi üçün uyğun dəyər çıxarır
  /// (mövcud axtarış/kateqoriya ekranları pozulmasın deyə).
  static String legacyCategoryFor(List<String> specialtyIds, List<String> titles) {
    const map = {
      'sp_santexnik': 'Santexnik',
      'sp_elektrik': 'Elektrik',
      'sp_dulger': 'Dülgər',
      'sp_malyar': 'Rəngsaz',
      'sp_mebel': 'Mebel Ustası',
      'sp_mebel_yigilmasi': 'Mebel Ustası',
      'sp_kondisioner': 'Kondisioner Ustası',
    };
    for (final id in specialtyIds) {
      if (map.containsKey(id)) return map[id]!;
    }
    for (final id in specialtyIds) {
      final sp = findSpecialtyById(id);
      if (sp == null) continue;
      switch (sp['groupId']) {
        case 'grp_tikinti':
          return 'Tikinti';
        case 'grp_avto':
          return 'Avtomobil Ustası';
        case 'grp_elektronika':
        case 'grp_konsol':
        case 'grp_meiset':
          return 'Təmir və Quraşdırma';
      }
    }
    if (titles.isNotEmpty) return titles.first;
    return 'Tikinti';
  }

  // Bakı şəhərinin 12 inzibati rayonu
  static const List<String> bakuDistricts = [
    'Binəqədi',
    'Xətai',
    'Xəzər',
    'Qaradağ',
    'Nərimanov',
    'Nəsimi',
    'Nizami',
    'Pirallahı',
    'Sabunçu',
    'Səbail',
    'Suraxanı',
    'Yasamal',
  ];

  // Bakı rayonlarına aid qəsəbələr, kəndlər və yaşayış massivləri
  static const Map<String, List<String>> bakuSettlementsByDistrict = {
    'Binəqədi': [
      'Binəqədi qəsəbəsi', 'Biləcəri', 'Xocəsən', 'Sulutəpə', 'Rəsulzadə', 'Novxanı',
      '28 May', 'Masazır yolu', '7-ci mkr', '8-ci mkr', '9-cu mkr', 'Dərnəgül', 'Azadlıq',
    ],
    'Xətai': ['Əhmədli', 'Həzi Aslanov', 'Ağ Şəhər', 'Xalqlar Dostluğu', 'Köhnə Günəşli', '8-ci km'],
    'Xəzər': [
      'Mərdəkan', 'Şüvəlan', 'Buzovna', 'Şağan', 'Qala', 'Türkan', 'Zirə', 'Binə', 'Dübəndi', 'Gürgan',
    ],
    'Qaradağ': [
      'Lökbatan', 'Qızıldaş', 'Puta', 'Şıxov', 'Sahil', 'Səngəçal', 'Ələt', 'Ümid', 'Müşfiqabad', 'Korgöz', 'Qobustan qəs.',
    ],
    'Nərimanov': ['Montin', 'Gənclik', 'Böyükşor', 'Təbriz küçəsi ətrafı'],
    'Nəsimi': ['20 Yanvar', 'Kubinka', 'Nəsimi bazarı ətrafı', 'Yeni Nəsimi'],
    'Nizami': ['Keşlə', '8-ci km', 'Qara Qarayev', 'Neftçilər', 'Koroğlu'],
    'Pirallahı': ['Pirallahı qəsəbəsi', 'Gürgən'],
    'Sabunçu': [
      'Bakıxanov', 'Balaxanı', 'Bilgəh', 'Kürdəxanı', 'Maştağa', 'Nardaran', 'Pirşağı',
      'Ramana', 'Sabunçu qəsəbəsi', 'Savalan', 'Zabrat', 'Yeni Balaxanı',
    ],
    'Səbail': ['İçərişəhər', 'Bayıl', 'Badamdar', '20-ci sahə', 'Bibiheybət', 'Səbail qəsəbəsi'],
    'Suraxanı': [
      'Qaraçuxur', 'Hövsan', 'Əmircan', 'Bülbülə', 'Zığ', 'Günəşli', 'Yeni Suraxanı', 'Dədə Qorqud', 'Massiv A', 'Yeni Günəşli',
    ],
    'Yasamal': ['Yeni Yasamal', 'Elmlər', 'İnşaatçılar', 'Memar Əcəmi', 'Yasamal qəsəbəsi'],
  };

  static List<String> getSettlementsForBakuDistrict(String district) {
    final norm = normalizeAz(district);
    for (final e in bakuSettlementsByDistrict.entries) {
      if (normalizeAz(e.key) == norm) return e.value;
    }
    return const [];
  }

  // ===================================================================
  // İSTİFADƏÇİ TƏRƏFİNDƏN TƏKLİF OLUNAN YENİ İXTİSASLAR (Admin təsdiqi ilə)
  // ===================================================================
  static String _customSpecialtyDocId(String title) {
    final base = normalizeAz(title).replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'csp_${base.replaceAll(RegExp(r'^_+|_+$'), '')}';
  }

  /// Yeni ixtisas təklifi göndərir. Eyni adlı ixtisas təkrar yaradılmır.
  /// Qaytarır: yaradılmış/mövcud sənədin ID-si.
  static Future<String> submitCustomSpecialty({
    required String title,
    String groupId = 'grp_diger',
    String groupTitle = 'Digər xidmətlər',
    String? submittedBy,
  }) async {
    final clean = title.trim();
    final docId = _customSpecialtyDocId(clean);
    final ref = _firestore.collection('custom_specialties').doc(docId);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        'title': clean,
        'groupId': groupId,
        'groupTitle': groupTitle,
        'isApproved': false,
        'submittedBy': submittedBy ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return docId;
  }

  static Stream<List<Map<String, dynamic>>> _customSpecialtiesStream(bool approved) {
    return _firestore
        .collection('custom_specialties')
        .where('isApproved', isEqualTo: approved)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  static Stream<List<Map<String, dynamic>>> getApprovedCustomSpecialtiesStream() => _customSpecialtiesStream(true);

  static Stream<List<Map<String, dynamic>>> getPendingCustomSpecialtiesStream() => _customSpecialtiesStream(false);

  static Future<void> approveCustomSpecialty(String docId) async {
    await _firestore.collection('custom_specialties').doc(docId).set({
      'isApproved': true,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteCustomSpecialty(String docId) async {
    await _firestore.collection('custom_specialties').doc(docId).delete();
  }

  /// Azərbaycan dilindəki hərfləri axtarış üçün standartlaşdırır (məs: Maştağa == mastaga)
  static String normalizeAz(String input) {
    return input
        .toLowerCase()
        .replaceAll('ə', 'e')
        .replaceAll('?', 'e')
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

  /// Azərbaycanın şəhər və rayonlarının real coğrafi koordinatları [lat, lng]
  static const Map<String, List<double>> regionCoordinates = {
    'Bakı': [40.4093, 49.8671],
    'Sumqayıt': [40.5897, 49.6686],
    'Gəncə': [40.6828, 46.3606],
    'Xırdalan': [40.4481, 49.7550],
    'Mingəçevir': [40.7640, 47.0595],
    'Şirvan': [39.9378, 48.9290],
    'Naxçıvan': [39.2089, 45.4122],
    'Şəki': [41.1919, 47.1706],
    'Quba': [41.3611, 48.5136],
    'Lənkəran': [38.7543, 48.8506],
    'Xankəndi': [39.8265, 46.7656],
    'Şuşa': [39.7601, 46.7496],
    'Qusar': [41.4275, 48.4302],
    'Xaçmaz': [41.4644, 48.8056],
    'Qəbələ': [40.9814, 47.8458],
    'İsmayıllı': [40.7849, 48.1514],
    'Şamaxı': [40.6314, 48.6414],
    'Masallı': [39.0353, 48.6654],
    'Cəlilabad': [39.2052, 48.4919],
    'Astara': [38.4560, 48.8750],
    'Lerik': [38.7739, 48.4150],
    'Yardımlı': [38.9056, 48.2405],
    'Bərdə': [40.3744, 47.1267],
    'Ağcabədi': [40.0502, 47.4594],
    'Ağdam': [39.9910, 46.9274],
    'Tərtər': [40.3450, 46.9289],
    'Füzuli': [39.6003, 47.1431],
    'Laçın': [39.6383, 46.5461],
    'Kəlbəcər': [40.1068, 46.0383],
    'Zaqatala': [41.6316, 46.6448],
    'Balakən': [41.7258, 46.4044],
    'Qax': [41.4183, 46.9204],
    'Oğuz': [41.0713, 47.4651],
    'Göyçay': [40.6525, 47.7406],
    'Ağdaş': [40.6470, 47.4738],
    'Ucar': [40.5190, 47.6542],
    'Kürdəmir': [40.3453, 48.1509],
    'Zərdab': [40.2184, 47.7121],
    'Ağsu': [40.5703, 48.4009],
    'Qobustan': [40.5336, 48.9282],
    'Yevlax': [40.6183, 47.1501],
    'Goranboy': [40.6103, 46.7897],
    'Şəmkir': [40.8297, 46.0178],
    'Tovuz': [40.9922, 45.6289],
    'Ağstafa': [41.1189, 45.4539],
    'Qazax': [41.0925, 45.3656],
    'Gədəbəy': [40.5698, 45.8147],
    'Daşkəsən': [40.5202, 46.0779],
    'Göygöl': [40.5858, 46.3189],
    'Samux': [40.7642, 46.4087],
    'Sabirabad': [40.0087, 48.4770],
    'Saatlı': [39.9321, 48.3689],
    'İmişli': [39.8710, 48.0600],
    'Beyləqan': [39.7756, 47.6186],
    'Salyan': [39.5962, 48.9848],
    'Neftçala': [39.3768, 49.2470],
    'Biləsuvar': [39.4583, 48.5450],
    'Hacıqabul': [40.0433, 48.9356],
    'Siyəzən': [41.0761, 49.1120],
    'Şabran': [41.2012, 48.9860],
    'Xızı': [40.9085, 49.0748],
    'Babək': [39.1508, 45.4485],
    'Culfa': [38.9539, 45.6308],
    'Ordubad': [38.9096, 46.0227],
    'Şərur': [39.5528, 44.9799],
    'Şahbuz': [39.4072, 45.5739],
    'Kəngərli': [39.3872, 45.1640],
    'Sədərək': [39.7142, 44.8856],
  };

  /// Bakı rayonları, qəsəbələr və məşhur kəndlərin real koordinatları [lat, lng]
  static const Map<String, List<double>> villageCoordinates = {
    'Yasamal': [40.3860, 49.8050],
    'Nəsimi': [40.4025, 49.8325],
    'Nərimanov': [40.4065, 49.8730],
    'Nizami': [40.4130, 49.9270],
    'Xətai': [40.3865, 49.9145],
    'Səbail': [40.3585, 49.8320],
    'Binəqədi': [40.4640, 49.8260],
    'Sabunçu': [40.4430, 49.9470],
    'Suraxanı': [40.4210, 50.0080],
    'Xəzər': [40.4910, 50.1450],
    'Qaradağ': [40.3050, 49.7080],
    'Pirallahı': [40.4710, 50.3260],
    'Maştağa': [40.5290, 49.9970],
    'Bilgəh': [40.5690, 50.0360],
    'Buzovna': [40.5190, 50.1140],
    'Mərdəkan': [40.4920, 50.1450],
    'Şüvəlan': [40.4830, 50.1940],
    'Binə': [40.4460, 50.0880],
    'Hövsan': [40.3690, 50.0720],
    'Qaraçuxur': [40.4060, 49.9720],
    'Bakıxanov': [40.4200, 49.9560],
    'Zabrat': [40.4780, 49.9480],
    'Mehdiabad': [40.4930, 49.8830],
    'Badamdar': [40.3430, 49.8050],
    'Lökbatan': [40.3250, 49.7330],
    'Sulutəpə': [40.4360, 49.7540],
    'Biləcəri': [40.4220, 49.8030],
    'Pirşağı': [40.5480, 49.9080],
    'Nardaran': [40.5580, 50.0080],
    'Kürdəxanı': [40.5540, 49.9460],
    'Balaxanı': [40.4640, 49.9190],
    'Ramana': [40.4530, 49.9760],
    'Zirə': [40.3710, 50.2910],
    'Türkan': [40.3660, 50.2050],
    'Qala': [40.4420, 50.1650],
    'Əhmədli': [40.3860, 49.9540],
    'Günəşli': [40.3770, 49.9830],
    'Əmircan': [40.4260, 49.9840],
    'Bülbülə': [40.4270, 50.0030],
    'Zığ': [40.3660, 49.9760],
    'Şağan': [40.4950, 50.1230],
    'Şıxov': [40.3120, 49.8190],
    'Sahil': [40.2280, 49.5750],
    'Səngəçal': [40.1720, 49.4580],
    'Ələt': [39.9410, 49.4060],
    'Qobu': [40.4047, 49.7131],
    'Qobu Park': [40.3950, 49.7180],
    'Hökməli': [40.4244, 49.7228],
    'Xocasən': [40.4150, 49.7660],
    'Ceyranbatan': [40.5419, 49.6908],
    'Digah': [40.4925, 49.8747],
    'Məmmədli': [40.5064, 49.9142],
    'Fatmayı': [40.5567, 49.8469],
    'Görədil': [40.5625, 49.8189],
    'Müşfiqabad': [40.4439, 49.6203],
    '28 May': [40.4414, 49.6692],
    'Güzdək': [40.3742, 49.6803],
    'Aşağı Güzdək': [40.4578, 49.6872],
    'Keşlə': [40.4050, 49.9030],
    '8-ci km': [40.4060, 49.9440],
    'Qaraşəhər': [40.3820, 49.8820],
    'Ağ Şəhər': [40.3825, 49.8950],
    'Bayıl': [40.3420, 49.8350],
    '20-ci sahə': [40.3310, 49.8180],
    'İçərişəhər': [40.3661, 49.8352],
    'Yeni Yasamal': [40.3910, 49.7820],
    '20 Yanvar': [40.4042, 49.8075],
    'Elmlər': [40.3753, 49.8156],
    'İnşaatçılar': [40.3892, 49.8025],
    'Gənclik': [40.4003, 49.8519],
    'Montin': [40.4120, 49.8680],
    'Memar Əcəmi': [40.4150, 49.8140],
    'Neftçilər': [40.4117, 49.9425],
    'Xalqlar Dostluğu': [40.3972, 49.9531],
    'Həzi Aslanov': [40.3731, 49.9536],
    'Koroğlu': [40.4208, 49.9181],
    'Qara Qarayev': [40.4183, 49.9347],
    'Dərnəgül': [40.4256, 49.8617],
    'Azadlıq': [40.4261, 49.8417],
    '7-ci mkr': [40.4280, 49.8520],
    '8-ci mkr': [40.4240, 49.8380],
    '9-cu mkr': [40.4220, 49.8080],
    'Rəsulzadə': [40.4380, 49.8380],
    'Binəqədi kəndi': [40.4640, 49.8260],
    'Yeni Suraxanı': [40.4320, 50.0320],
    'Qobustan qəs.': [40.0820, 49.4120],
    'Puta': [40.2960, 49.6600],
    'Qızıldaş': [40.3520, 49.6780],
    'Masazır': [40.4710, 49.7660],
    'Saray': [40.5330, 49.7180],
    'Novxanı': [40.5310, 49.7820],
    'Corat': [40.5730, 49.7080],
    'Hacı Zeynalabdin': [40.6180, 49.5760],
    'Lahıc': [40.8489, 48.3831],
    'Basqal': [40.7525, 48.3869],
    'Qırmızı Qəsəbə': [41.3700, 48.5180],
    'Xınalıq': [41.1783, 48.1258],
    'Şahdağ': [41.3210, 48.1480],
    'Nabran': [41.7620, 48.7280],
    'Xudat': [41.6306, 48.6789],
    'Vəndam': [40.9610, 47.9260],
    'Nic': [40.8960, 47.6510],
    'Kiş': [41.2530, 47.1930],
    'İstisu': [40.0050, 45.9500],
    'Quzanlı': [40.1650, 47.1520],
    'Horadiz': [39.4486, 47.3397],
  };

  /// Seçilmiş şəhər/rayon və kənd üçün dəqiq [lat, lng] qaytarır
  static List<double> getCoordinates(String region, [String village = '']) {
    final normV = normalizeAz(village);
    if (normV.isNotEmpty) {
      for (final entry in villageCoordinates.entries) {
        if (normalizeAz(entry.key) == normV) {
          return entry.value;
        }
      }
      for (final entry in villageCoordinates.entries) {
        final kNorm = normalizeAz(entry.key);
        if (normV.contains(kNorm) || kNorm.contains(normV)) {
          return entry.value;
        }
      }
    }

    final normR = normalizeAz(region);
    for (final entry in regionCoordinates.entries) {
      if (normalizeAz(entry.key) == normR) {
        return entry.value;
      }
    }

    return const [40.4093, 49.8671];
  }

  /// Ustanın saxlanmış koordinatlarına və ya profil ünvanına ("Şəhər, Kənd") uyğun dəqiq koordinat qaytarır
  static List<double> resolveArtisanCoordinates(
    String cityField,
    String uid, {
    double? lat,
    double? lng,
  }) {
    if (lat != null && lng != null && lat >= 38.0 && lat <= 42.5 && lng >= 44.0 && lng <= 51.5) {
      return [lat, lng];
    }

    final parts = cityField.split(',');
    final String rawRegion = parts.isNotEmpty ? parts[0].trim() : 'Bakı';
    final String rawVillage = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';

    String matchedRegion = rawRegion;
    final normField = normalizeAz(cityField);
    if (matchedRegion.isEmpty) matchedRegion = 'Bakı';

    for (final region in defaultCities) {
      if (normalizeAz(rawRegion) == normalizeAz(region)) {
        matchedRegion = region;
        break;
      }
      if (normField.contains(normalizeAz(region))) {
        matchedRegion = region;
      }
    }

    String matchedVillage = rawVillage;
    if (matchedVillage.isEmpty) {
      for (final vKey in villageCoordinates.keys) {
        if (normField.contains(normalizeAz(vKey))) {
          matchedVillage = vKey;
          break;
        }
      }
    }

    return getCoordinates(matchedRegion, matchedVillage);
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
