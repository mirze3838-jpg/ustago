const fs = require('fs');
const { execSync } = require('child_process');

const cwd = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago';
const filePath = `${cwd}/lib/screens/home_screen.dart`;

// 1. Get base content from f960958
let content = execSync('git show f960958:lib/screens/home_screen.dart', { cwd }).toString();

const isCRLF = content.includes('\r\n');
if (isCRLF) content = content.replace(/\r\n/g, '\n');

// 2. In _buildProfileTab, cut from `// Usta rolundakı istifadəçilər` up to `void _showProfileOptionsMenu`
const targetLegacyProfileStart = '        // Usta rolundakı istifadəçilər üçün yeni premium dizayn (Təqdim olunmuş dizayna tam uyğun)\n        if (userRole == \'usta\') {\n          return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);\n        }\n\n        return ListView(';
const targetProfileOptions = '  void _showProfileOptionsMenu(';

const idxStart = content.indexOf(targetLegacyProfileStart);
const idxEnd = content.indexOf(targetProfileOptions, idxStart);

if (idxStart === -1 || idxEnd === -1) {
  console.error('Indices not found:', { idxStart, idxEnd });
  process.exit(1);
}

// Find the doc comment before _showProfileOptionsMenu
const docComment = '  /// İnstaqram Sağ Yuxarı 3 Nöqtə (⋮) menyusu';
const idxDoc = content.lastIndexOf(docComment, idxEnd);
const cutEnd = idxDoc !== -1 ? idxDoc : idxEnd;

const replacement = `        // Bütün rollar üçün (Usta, Fəhlə, Satıcı, Müştəri) vahid modern premium profil dizaynı
        return _buildModernUstaProfile(user, userData, isAdmin, avatarImage, displayName, userRole);
      },
    );
  }

`;

content = content.slice(0, idxStart) + replacement + content.slice(cutEnd);
console.log('Legacy profile replaced cleanly without touching any helper methods.');

// 3. In _buildModernUstaProfile, enhance role title and bio defaults
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
  console.error('targetProfileHeader not found!');
  process.exit(1);
}
content = content.replace(targetProfileHeader, replaceProfileHeader);
console.log('Profile header role defaults updated.');

// 4. In _buildUstaUnifiedGrid, remove temporary Firestore posts delete block
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

// 5. Verification checks
const requiredSymbols = [
  '_cleanTikTokHandle',
  '_cleanInstagramHandle',
  '_showProfileOptionsMenu',
  '_buildUstaStatItem',
  '_showUserStoreModal',
  '_showUserListingsModal',
  '_buildModernUstaProfile',
  '_buildUstaUnifiedGrid'
];

for (const sym of requiredSymbols) {
  if (!content.includes(sym)) {
    console.error(`MISSING CRITICAL SYMBOL: ${sym}`);
    process.exit(1);
  }
}
console.log('All critical symbols verified present!');

if (isCRLF) content = content.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, content, 'utf8');
console.log('lib/screens/home_screen.dart written and verified perfectly!');
