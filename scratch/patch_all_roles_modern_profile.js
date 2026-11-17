const fs = require('fs');
const homePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(homePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) content = content.replace(/\r\n/g, '\n');

// 1. In _buildProfileTab, return _buildModernUstaProfile for all roles, removing the legacy ListView fallback
const targetLegacyProfileStart = '        // Usta rolundakı istifadəçilər üçün yeni premium dizayn (Təqdim olunmuş dizayna tam uyğun)\n        if (userRole == \'usta\') {\n          return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);\n        }\n\n        return ListView(';
const targetLegacyProfileEnd = '  /// Yeni İnstaqram Stilində Premium Usta Profil Səhifəsi (İstifadəçinin tələbinə tam uyğun)\n  Widget _buildModernUstaProfile(';

const idxStart = content.indexOf(targetLegacyProfileStart);
const idxEnd = content.indexOf(targetLegacyProfileEnd);

if (idxStart === -1 || idxEnd === -1) {
  console.error('Could not find legacy profile block in home_screen.dart', { idxStart, idxEnd });
  process.exit(1);
}

const modernForAllRoles = `        // Bütün rollar üçün (Usta, Fəhlə, Satıcı, Müştəri) vahid modern premium profil dizaynı
        return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);
      },
    );
  }

`;

content = content.slice(0, idxStart) + modernForAllRoles + content.slice(idxEnd);
console.log('Profile tab updated to use modern profile for all roles.');

// 2. In _buildModernUstaProfile, enhance role title and bio defaults
const targetProfileHeader = `  Widget _buildModernUstaProfile(
    User user,
    Map<String, dynamic>? userData,
    bool isAdmin,
    ImageProvider? avatarImage,
    String displayName,
    String userRole,
  ) {
    final String phone = (userData?['phone'] ?? user.phoneNumber ?? '').toString().trim();
    final String category = (userData?['category'] ?? userData?['trade'] ?? 'Tikinti və Təmir').toString();
    final String rating = (userData?['rating'] != null) ? userData!['rating'].toString() : '5.0';

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
    if (userSpecialties.isEmpty && category.isNotEmpty) {
      if (category.contains(',')) {
        userSpecialties = category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else {
        userSpecialties = [category];
      }
    }
    final String displaySpecialtiesText = userSpecialties.isNotEmpty ? userSpecialties.take(4).join(', ') : category;
    final String bio = (userData?['bio'] != null && (userData!['bio'] as String).trim().isNotEmpty)
        ? userData!['bio'] as String
        : 'Keyfiyyətli və peşəkar təmir xidməti. Təcrübə: 10+ il. Hər növ tikinti və təmir işləri.';`;

const replaceProfileHeader = `  Widget _buildModernUstaProfile(
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
        : defaultBio;`;

if (!content.includes(targetProfileHeader)) {
  console.error('Could not find targetProfileHeader in home_screen.dart');
  process.exit(1);
}

content = content.replace(targetProfileHeader, replaceProfileHeader);
console.log('Profile header role defaults updated.');

// 3. In _buildUstaUnifiedGrid, remove temporary Firestore posts delete block
const targetGridDelete = `  Widget _buildUstaUnifiedGrid(String uid, String authorName, String role) {
    // Köhnə test fotoşəkillərini Firestore-dan təmizləyirik (istifadəçi tələbi)
    FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get()
        .then((snap) {
      for (final doc in snap.docs) {
        doc.reference.delete();
      }
    }).catchError((_) {});

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(`;

const replaceGridClean = `  Widget _buildUstaUnifiedGrid(String uid, String authorName, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(`;

if (content.includes(targetGridDelete)) {
  content = content.replace(targetGridDelete, replaceGridClean);
  console.log('Unified grid auto-delete cleaned up.');
}

if (isCRLF) content = content.replace(/\n/g, '\r\n');
fs.writeFileSync(homePath, content, 'utf8');
console.log('home_screen.dart saved successfully.');
