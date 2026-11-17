const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) {
  content = content.replace(/\r\n/g, '\n');
}

// 1. In _showEditProfileDialog:
// Update initial loading of selectedSpecialtyIds to respect max 4 and check both specialties and category
const targetPrePop = `    // Mövcud ixtisas ID-lərini təyin edirik
    final Set<String> selectedSpecialtyIds = {};
    if (userData?['specialtyIds'] is List) {
      for (final item in (userData!['specialtyIds'] as List)) {
        if (item != null && item.toString().trim().isNotEmpty) {
          selectedSpecialtyIds.add(item.toString().trim());
        }
      }
    }
    // Əgər specialtyIds yoxdursa, köhnə category sahəsinə görə ilkin ixtisası təyin edirik
    if (selectedSpecialtyIds.isEmpty && userData?['category'] != null) {
      final catLower = (userData!['category'] as String).toLowerCase();
      for (final g in CategoryCityService.specialtyGroups) {
        final items = g['items'] as List<Map<String, String>>;
        for (final it in items) {
          if (catLower.contains(it['title']!.toLowerCase()) || it['title']!.toLowerCase().contains(catLower)) {
            selectedSpecialtyIds.add(it['id']!);
            break;
          }
        }
        if (selectedSpecialtyIds.isNotEmpty) break;
      }
    }`;

const replacePrePop = `    // Mövcud ixtisas ID-lərini təyin edirik (Maksimum 4 sahə)
    final Set<String> selectedSpecialtyIds = {};
    if (userData?['specialtyIds'] is List) {
      for (final item in (userData!['specialtyIds'] as List)) {
        if (item != null && item.toString().trim().isNotEmpty) {
          if (selectedSpecialtyIds.length < 4) {
            selectedSpecialtyIds.add(item.toString().trim());
          }
        }
      }
    }
    // Əgər specialtyIds yoxdursa, specialties və ya category sahəsinə görə ilkin ixtisasları təyin edirik
    if (selectedSpecialtyIds.isEmpty && userData?['specialties'] is List) {
      for (final spTitle in (userData!['specialties'] as List)) {
        if (spTitle == null) continue;
        final t = spTitle.toString().trim().toLowerCase();
        for (final g in CategoryCityService.specialtyGroups) {
          final items = g['items'] as List<Map<String, String>>;
          for (final it in items) {
            if (it['title']!.toLowerCase() == t) {
              if (selectedSpecialtyIds.length < 4) selectedSpecialtyIds.add(it['id']!);
              break;
            }
          }
        }
      }
    }
    if (selectedSpecialtyIds.isEmpty && userData?['category'] != null) {
      final rawCat = (userData!['category'] as String);
      final catParts = rawCat.split(',').map((e) => e.trim().toLowerCase()).toList();
      for (final part in catParts) {
        for (final g in CategoryCityService.specialtyGroups) {
          final items = g['items'] as List<Map<String, String>>;
          for (final it in items) {
            final tLower = it['title']!.toLowerCase();
            if (part == tLower || part.contains(tLower) || tLower.contains(part)) {
              if (selectedSpecialtyIds.length < 4) {
                selectedSpecialtyIds.add(it['id']!);
              }
              break;
            }
          }
        }
      }
    }`;

if (!content.includes(targetPrePop)) {
  console.error('targetPrePop not found!');
  process.exit(1);
}
content = content.replace(targetPrePop, replacePrePop);
console.log('PrePop replaced successfully.');

// 2. In _showEditProfileDialog:
// Update header counter badge, subtitle, and FilterChip onSelected (max 4 check)
const targetHeaderBadge = `                                const Text(
                                  'İxtisas və Fəaliyyət Sahələri',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const Spacer(),
                                if (selectedSpecialtyIds.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1769D2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '\${selectedSpecialtyIds.length} seçilib',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gördüyünüz işləri seçin (qeydiyyatdakı kimi bir və ya bir neçə ixtisas seçə bilərsiniz):',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),`;

const replaceHeaderBadge = `                                const Text(
                                  'İxtisas və Fəaliyyət Sahələri (Maksimum 4)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: selectedSpecialtyIds.length >= 4 ? const Color(0xFF10B981) : const Color(0xFF1769D2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '\${selectedSpecialtyIds.length}/4 seçilib',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gördüyünüz işləri seçin (profilinizdə görünməsi üçün maksimum 4 sahə seçə bilərsiniz):',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),`;

if (!content.includes(targetHeaderBadge)) {
  console.error('targetHeaderBadge not found!');
  process.exit(1);
}
content = content.replace(targetHeaderBadge, replaceHeaderBadge);
console.log('HeaderBadge replaced successfully.');

// 3. Update FilterChip onSelected to enforce max 4 limit
const targetFilterChipOnSelected = `                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    selectedSpecialtyIds.add(itemId);
                                                  } else {
                                                    selectedSpecialtyIds.remove(itemId);
                                                  }
                                                });
                                              },`;

const replaceFilterChipOnSelected = `                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    if (selectedSpecialtyIds.length >= 4) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Maksimum 4 ixtisas sahəsi seçə bilərsiniz!'),
                                                          backgroundColor: Color(0xFFE11D48),
                                                          duration: Duration(seconds: 2),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    selectedSpecialtyIds.add(itemId);
                                                  } else {
                                                    selectedSpecialtyIds.remove(itemId);
                                                  }
                                                });
                                              },`;

if (!content.includes(targetFilterChipOnSelected)) {
  console.error('targetFilterChipOnSelected not found!');
  process.exit(1);
}
content = content.replace(targetFilterChipOnSelected, replaceFilterChipOnSelected);
console.log('FilterChipOnSelected replaced successfully.');

// 4. Update save logic in _showEditProfileDialog to save all 4 specialties in category/trade joined by comma
const targetSaveTrade = `                              // Seçilmiş ixtisas adları və kateqoriyaları
                              final specialtyTitles = <String>[];
                              final specialtyCategoryTitles = <String>{};
                              for (final sId in selectedSpecialtyIds) {
                                final sp = CategoryCityService.findSpecialtyById(sId);
                                if (sp != null) {
                                  specialtyTitles.add(sp['title']!);
                                  specialtyCategoryTitles.add(sp['groupTitle']!);
                                }
                              }

                              final legacyCategory = CategoryCityService.legacyCategoryFor(
                                selectedSpecialtyIds.toList(),
                                specialtyTitles,
                              );

                              final updatedTrade = selectedRole == 'usta'
                                  ? (legacyCategory.isNotEmpty ? legacyCategory : (specialtyTitles.isNotEmpty ? specialtyTitles.first : selectedUstaCategory))
                                  : (selectedRole == 'worker' ? 'Fəhlə (Köməkçi işlər)' : '');`;

const replaceSaveTrade = `                              // Seçilmiş ixtisas adları və kateqoriyaları (maksimum 4 sahə)
                              final specialtyTitles = <String>[];
                              final specialtyCategoryTitles = <String>{};
                              for (final sId in selectedSpecialtyIds.take(4)) {
                                final sp = CategoryCityService.findSpecialtyById(sId);
                                if (sp != null) {
                                  specialtyTitles.add(sp['title']!);
                                  specialtyCategoryTitles.add(sp['groupTitle']!);
                                }
                              }

                              // Bütün seçilmiş ixtisaslar profilin başlığında ardıcıl görünür (məs: Santexnik, Tikinti, Elektrik ustası)
                              final updatedTrade = selectedRole == 'usta'
                                  ? (specialtyTitles.isNotEmpty ? specialtyTitles.join(', ') : selectedUstaCategory)
                                  : (selectedRole == 'worker' ? (specialtyTitles.isNotEmpty ? specialtyTitles.join(', ') : 'Fəhlə (Köməkçi işlər)') : '');`;

if (!content.includes(targetSaveTrade)) {
  console.error('targetSaveTrade not found!');
  process.exit(1);
}
content = content.replace(targetSaveTrade, replaceSaveTrade);
console.log('SaveTrade replaced successfully.');

// 5. In _buildModernUstaProfile:
// Extract userSpecialties and display under name joined by comma
const targetProfileCategory = `    final String phone = (userData?['phone'] ?? user.phoneNumber ?? '').toString().trim();
    final String category = (userData?['category'] ?? userData?['trade'] ?? 'Tikinti və Təmir').toString();
    final String rating = (userData?['rating'] != null) ? userData!['rating'].toString() : '5.0';`;

const replaceProfileCategory = `    final String phone = (userData?['phone'] ?? user.phoneNumber ?? '').toString().trim();
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
    final String displaySpecialtiesText = userSpecialties.isNotEmpty ? userSpecialties.take(4).join(', ') : category;`;

if (!content.includes(targetProfileCategory)) {
  console.error('targetProfileCategory not found!');
  process.exit(1);
}
content = content.replace(targetProfileCategory, replaceProfileCategory);
console.log('ProfileCategory replaced successfully.');

// 6. Replace text under name to show displaySpecialtiesText
const targetCategoryText = `                      // Peşə / İxtisas (Boz rəngdə kateqoriya)
                      Text(
                        category,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),`;

const replaceCategoryText = `                      // Peşə / İxtisaslar (Seçilmiş bütün sahələr: məs: Santexnik, Tikinti, Elektrik)
                      Text(
                        displaySpecialtiesText,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),`;

if (!content.includes(targetCategoryText)) {
  console.error('targetCategoryText not found!');
  process.exit(1);
}
content = content.replace(targetCategoryText, replaceCategoryText);
console.log('CategoryText replaced successfully.');

// 7. Update _showServicesModal and _buildServiceChips
const targetServicesModal = `  /// Xidmətlər modal pəncərəsi
  void _showServicesModal(BuildContext context, String category, Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xidmət Sahələri və Bacarıqlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildServiceChips(category, userData),
              ),
            ],
          ),
        ),
      ),
    );
  }`;

const replaceServicesModal = `  /// Xidmətlər modal pəncərəsi (Ustanın seçdiyi bütün ixtisaslar)
  void _showServicesModal(BuildContext context, String category, Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Color(0xFF1769D2), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xidmət Sahələri və İxtisaslar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ustanın təklif etdiyi peşəkar fəaliyyət sahələri',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildServiceChips(category, userData),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1769D2), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1769D2)),
                  label: const Text(
                    'İxtisasları Dəyişdir (Maksimum 4)',
                    style: TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      _showEditProfileDialog(user.uid, userData);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }`;

if (!content.includes(targetServicesModal)) {
  console.error('targetServicesModal not found!');
  process.exit(1);
}
content = content.replace(targetServicesModal, replaceServicesModal);
console.log('ServicesModal replaced successfully.');

// 8. Update _buildServiceChips to use userSpecialties dynamically with matching icons
const targetServiceChipsStart = '  /// Ustanın ixtisasına uyğun peşəkar xidmət teqləri (şəkildəki kimi zərif mavi həb formalı)\n  List<Widget> _buildServiceChips(String category, Map<String, dynamic>? userData) {';
const targetServiceChipsEnd = '    return skills.map((s) {\n      return Container(\n        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),\n        decoration: BoxDecoration(\n          color: const Color(0xFFEFF6FF),\n          borderRadius: BorderRadius.circular(10),\n          border: Border.all(color: const Color(0xFFDBEAFE)),\n        ),\n        child: Row(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            Icon(s[\'icon\'] as IconData, size: 14, color: const Color(0xFF1769D2)),\n            const SizedBox(width: 5),\n            Text(\n              s[\'name\'] as String,\n              style: const TextStyle(\n                color: Color(0xFF1769D2),\n                fontSize: 12,\n                fontWeight: FontWeight.w600,\n              ),\n            ),\n          ],\n        ),\n      );\n    }).toList();\n  }';

const idxChipsStart = content.indexOf(targetServiceChipsStart);
if (idxChipsStart === -1) {
  console.error('targetServiceChipsStart not found!');
  process.exit(1);
}
const idxChipsEnd = content.indexOf(targetServiceChipsEnd, idxChipsStart);
if (idxChipsEnd === -1) {
  console.error('targetServiceChipsEnd not found!');
  process.exit(1);
}

const replaceServiceChips = `  /// Ustanın ixtisasına uyğun peşəkar xidmət teqləri (seçilmiş maksimum 4 ixtisas əsasında)
  List<Widget> _buildServiceChips(String category, Map<String, dynamic>? userData) {
    List<String> rawSkills = [];
    if (userData?['specialties'] is List && (userData!['specialties'] as List).isNotEmpty) {
      rawSkills = (userData!['specialties'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (userData?['specialtyIds'] is List && (userData!['specialtyIds'] as List).isNotEmpty) {
      for (final id in (userData!['specialtyIds'] as List)) {
        final sp = CategoryCityService.findSpecialtyById(id.toString());
        if (sp != null) rawSkills.add(sp['title']!);
      }
    }
    if (rawSkills.isEmpty && category.isNotEmpty) {
      if (category.contains(',')) {
        rawSkills = category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else {
        rawSkills = [category];
      }
    }

    if (rawSkills.isEmpty) {
      rawSkills = ['Tikinti', 'Təmir', 'Rəngləmə', 'Dizayn'];
    }

    IconData getSkillIcon(String title) {
      final t = title.toLowerCase();
      if (t.contains('santexnik') || t.contains('boru') || t.contains('kran')) return Icons.plumbing_rounded;
      if (t.contains('elektrik') || t.contains('şit') || t.contains('naqil')) return Icons.bolt_rounded;
      if (t.contains('kafel') || t.contains('metlax')) return Icons.grid_view_rounded;
      if (t.contains('malyar') || t.contains('rəng')) return Icons.format_paint_rounded;
      if (t.contains('alçıpan') || t.contains('alcipan')) return Icons.architecture_rounded;
      if (t.contains('mebel') || t.contains('dülgər')) return Icons.chair_rounded;
      if (t.contains('qapı') || t.contains('pəncərə')) return Icons.door_front_door_rounded;
      if (t.contains('dam') || t.contains('fasad') || t.contains('beton')) return Icons.roofing_rounded;
      if (t.contains('telefon') || t.contains('iphone') || t.contains('android')) return Icons.smartphone_rounded;
      if (t.contains('kompüter') || t.contains('noutbuk')) return Icons.laptop_rounded;
      if (t.contains('televizor') || t.contains('tv')) return Icons.tv_rounded;
      if (t.contains('playstation') || t.contains('ps') || t.contains('xbox') || t.contains('konsol')) return Icons.sports_esports_rounded;
      if (t.contains('kondisioner') || t.contains('iqlim') || t.contains('soyuducu')) return Icons.ac_unit_rounded;
      if (t.contains('kombi') || t.contains('istilik') || t.contains('radiator')) return Icons.hvac_rounded;
      if (t.contains('paltaryuyan') || t.contains('qabyuyan')) return Icons.local_laundry_service_rounded;
      if (t.contains('avto') || t.contains('maşın') || t.contains('motor')) return Icons.directions_car_rounded;
      return Icons.handyman_rounded;
    }

    return rawSkills.take(4).map((s) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(getSkillIcon(s), size: 16, color: const Color(0xFF1769D2)),
            const SizedBox(width: 6),
            Text(
              s,
              style: const TextStyle(
                color: Color(0xFF1769D2),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }`;

content = content.slice(0, idxChipsStart) + replaceServiceChips + content.slice(idxChipsEnd + targetServiceChipsEnd.length);
console.log('ServiceChips replaced successfully.');

if (isCRLF) {
  content = content.replace(/\n/g, '\r\n');
}

fs.writeFileSync(filePath, content, 'utf8');
console.log('All changes applied successfully!');
