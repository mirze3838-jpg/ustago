const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) {
  content = content.replace(/\r\n/g, '\n');
}

const targetStart = '  // Profil məlumatlarını redaktə etmək üçün dialoq\n  void _showEditProfileDialog(String uid, Map<String, dynamic>? userData) {';
const targetEnd = '    );\n  }\n\n  // Ustanın Haqqında məlumatını tez dəyişməsi üçün xüsusi dialoq';

const idxStart = content.indexOf(targetStart);
if (idxStart === -1) {
  console.error('Target start not found!');
  process.exit(1);
}

const idxEnd = content.indexOf(targetEnd, idxStart);
if (idxEnd === -1) {
  console.error('Target end not found!');
  process.exit(1);
}

const newMethod = `  // Profil məlumatlarını redaktə etmək üçün müasir dizaynlı dialoq
  void _showEditProfileDialog(String uid, Map<String, dynamic>? userData) {
    final nameController = TextEditingController(text: userData?['fullName'] ?? '');
    final phoneController = TextEditingController(text: userData?['phone'] ?? '');
    final bioController = TextEditingController(text: userData?['bio'] ?? '');
    final tiktokController = TextEditingController(text: userData?['tiktokHandle'] ?? '');
    final instagramController = TextEditingController(text: userData?['instagramHandle'] ?? '');
    final websiteController = TextEditingController(text: userData?['websiteUrl'] ?? userData?['website'] ?? '');
    final specialtySearchController = TextEditingController();
    String specialtySearchQuery = '';

    String selectedRole = userData?['role'] ?? 'usta';
    String selectedUstaCategory = userData?['category'] ?? 'Tikinti';
    bool isWorkingStatus = userData?['isWorking'] == true;

    // Mövcud ixtisas ID-lərini təyin edirik
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
    }

    final Set<String> expandedGroupIds = {};

    final rawCity = (userData?['city'] ?? 'Bakı').toString();
    String selectedCityVal = 'Bakı';
    String districtText = '';
    if (rawCity.contains(',')) {
      final parts = rawCity.split(',');
      selectedCityVal = parts[0].trim();
      districtText = parts.sublist(1).join(',').trim();
    } else {
      selectedCityVal = rawCity.trim();
    }
    if (!_cities.contains(selectedCityVal) && _cities.isNotEmpty) {
      selectedCityVal = _cities.first;
    }
    final districtController = TextEditingController(text: districtText);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = specialtySearchQuery.trim().toLowerCase();

          return Dialog(
            backgroundColor: Colors.white,
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Pinned Header (Müasir Üst Başlıq)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF1769D2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profil Məlumatlarını Redaktə Et',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Məlumatlarınızı və göstərdiyiniz xidmətləri yeniləyin',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                          onPressed: () => Navigator.pop(ctx),
                          tooltip: 'Bağla',
                        ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BÖLMƏ 1: Əsas Məlumatlar
                          const Text(
                            'Əsas Məlumatlar',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),

                          // Ad və Soyad
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Ad və Soyad',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1769D2), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mobil Nömrə
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Mobil Nömrə',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF10B981), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Hesab Növü (Rol)
                          DropdownButtonFormField<String>(
                            value: ['usta', 'worker', 'customer', 'seller'].contains(selectedRole) ? selectedRole : 'usta',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Hesab Növü',
                              labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF8B5CF6), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'usta', child: Text('Usta kimi (Peşəkar usta)')),
                              DropdownMenuItem(value: 'worker', child: Text('Fəhlə kimi (Köməkçi işçi)')),
                              DropdownMenuItem(value: 'customer', child: Text('Müştəri kimi')),
                              DropdownMenuItem(value: 'seller', child: Text('Satıcı / Mağaza')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedRole = val);
                            },
                          ),
                          const SizedBox(height: 18),

                          // BÖLMƏ 2: Məkan və Ünvan
                          const Text(
                            'Məkan və Ünvan',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  value: _cities.contains(selectedCityVal) ? selectedCityVal : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Şəhər / Rayon',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF1769D2), size: 19),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                                  ),
                                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedCityVal = val;
                                        districtController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 6,
                                child: TextField(
                                  controller: districtController,
                                  onChanged: (_) => setDialogState(() {}),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Kənd / Qəsəbə / Ərazi',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: 'Məs: Yasamal, Qobu...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.pin_drop_outlined, color: Color(0xFFEA580C), size: 19),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Sürətli Qəsəbə Seçimləri (Çiplər)
                          SizedBox(
                            height: 32,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: CategoryCityService.getVillagesForRegion(selectedCityVal).map((v) {
                                final isPicked = districtController.text.trim().toLowerCase() == v.toLowerCase();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      v,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isPicked ? Colors.white : const Color(0xFF1E293B),
                                        fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    backgroundColor: isPicked ? const Color(0xFF1769D2) : const Color(0xFFF1F5F9),
                                    side: BorderSide(color: isPicked ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0)),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setDialogState(() {
                                        districtController.text = v;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // BÖLMƏ 3: İXTİSAS SEÇİMİ (Qeydiyyatdakı kimi zəngin və geniş)
                          if (selectedRole == 'usta' || selectedRole == 'worker') ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.handyman_rounded, color: Color(0xFF1769D2), size: 18),
                                ),
                                const SizedBox(width: 8),
                                const Text(
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
                            ),
                            const SizedBox(height: 10),

                            // Axtarış Xanası
                            TextField(
                              controller: specialtySearchController,
                              onChanged: (val) => setDialogState(() => specialtySearchQuery = val),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'İxtisas axtar (Santexnik, Malyar, PlayStation, Kafel)...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                suffixIcon: specialtySearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                        onPressed: () {
                                          specialtySearchController.clear();
                                          setDialogState(() => specialtySearchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Seçilmiş İxtisasların Həbləri (Badges)
                            if (selectedSpecialtyIds.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Seçilmiş İxtisaslarınız:',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                        GestureDetector(
                                          onTap: () => setDialogState(() => selectedSpecialtyIds.clear()),
                                          child: const Text(
                                            'Hamısını təmizlə',
                                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: selectedSpecialtyIds.map((sId) {
                                        final sp = CategoryCityService.findSpecialtyById(sId);
                                        final title = sp != null ? sp['title']! : sId;
                                        return Chip(
                                          backgroundColor: const Color(0xFFEFF6FF),
                                          deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1769D2)),
                                          onDeleted: () => setDialogState(() => selectedSpecialtyIds.remove(sId)),
                                          label: Text(
                                            title,
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                          ),
                                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Qeydiyyatdakı Kateqoriya Qrupları Akordeon Şəklində
                            ...CategoryCityService.specialtyGroups.map((g) {
                              final gId = g['id'] as String;
                              final gTitle = g['title'] as String;
                              final gIcon = g['icon'] as IconData;
                              final gColor = g['color'] as Color;
                              final items = (g['items'] as List<Map<String, String>>);

                              final matchingItems = query.isEmpty
                                  ? items
                                  : items.where((it) => it['title']!.toLowerCase().contains(query)).toList();

                              if (query.isNotEmpty && matchingItems.isEmpty) return const SizedBox.shrink();

                              final selectedCountInGroup = items.where((it) => selectedSpecialtyIds.contains(it['id'])).length;
                              final isExpanded = expandedGroupIds.contains(gId) || query.isNotEmpty;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selectedCountInGroup > 0 ? gColor : const Color(0xFFE2E8F0),
                                    width: selectedCountInGroup > 0 ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        setDialogState(() {
                                          if (expandedGroupIds.contains(gId)) {
                                            expandedGroupIds.remove(gId);
                                          } else {
                                            expandedGroupIds.add(gId);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: gColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(gIcon, color: gColor, size: 18),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                gTitle,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: selectedCountInGroup > 0 ? gColor : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (selectedCountInGroup > 0)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: gColor,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '\$selectedCountInGroup',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            Icon(
                                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                              color: const Color(0xFF64748B),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded) ...[
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: matchingItems.map((item) {
                                            final itemId = item['id']!;
                                            final itemTitle = item['title']!;
                                            final isChecked = selectedSpecialtyIds.contains(itemId);

                                            return FilterChip(
                                              label: Text(
                                                itemTitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                                  color: isChecked ? Colors.white : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              selected: isChecked,
                                              selectedColor: gColor,
                                              backgroundColor: const Color(0xFFF8FAFC),
                                              checkmarkColor: Colors.white,
                                              showCheckmark: true,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: BorderSide(
                                                  color: isChecked ? gColor : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  if (selected) {
                                                    selectedSpecialtyIds.add(itemId);
                                                  } else {
                                                    selectedSpecialtyIds.remove(itemId);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 14),

                            // Usta Haqqında Məlumat (Bio / Təcrübə)
                            const Text(
                              'Haqqında Məlumat',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: bioController,
                              maxLines: 4,
                              maxLength: 500,
                              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                labelText: 'Gördüyünüz işlər, təcrübəniz və xidmət şərtləriniz...',
                                labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 50),
                                  child: Icon(Icons.info_outline_rounded, color: Color(0xFF1769D2), size: 20),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.6)),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Müasir İş Statusu Kartı (Sərbəstəm / Məşğulam)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isWorkingStatus ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isWorkingStatus ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isWorkingStatus ? const Color(0xFFF43F5E).withOpacity(0.12) : const Color(0xFF10B981).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isWorkingStatus ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                                      color: isWorkingStatus ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isWorkingStatus ? 'Hal-hazırda işləyirəm (Məşğulam)' : 'Sərbəstəm (İş təkliflərinə açığam)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isWorkingStatus ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isWorkingStatus ? 'Profilinizdə qırmızı "Məşğul" statusu görünəcək' : 'Profilinizdə yaşıl "Sərbəstəm" statusu görünəcək',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isWorkingStatus ? const Color(0xFFE11D48).withOpacity(0.8) : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: !isWorkingStatus,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) => setDialogState(() => isWorkingStatus = !val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // BÖLMƏ 4: Sosial Linklər (Maksimum 3 link)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.link_rounded, color: Color(0xFF1769D2), size: 19),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sosial Şəbəkələr və Linklər (Maksimum 3 ədəd)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hesabınızı silmək üçün xananı boşaldın və ya (✕) işarəsinə vurun.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 12),

                                // 1. TikTok
                                TextField(
                                  controller: tiktokController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '1. TikTok Hesabı',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: '@istifadəçi_adı və ya link',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.music_note_rounded, color: Color(0xFFFE2C55), size: 18),
                                    suffixIcon: tiktokController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => tiktokController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                                const SizedBox(height: 10),

                                // 2. Instagram
                                TextField(
                                  controller: instagramController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '2. Instagram Hesabı',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: '@istifadəçi_adı və ya link',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 18),
                                    suffixIcon: instagramController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => instagramController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                                const SizedBox(height: 10),

                                // 3. Veb-sayt / Digər link
                                TextField(
                                  controller: websiteController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    labelText: '3. Veb-sayt və ya Digər link',
                                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    hintText: 'sayt.az, youtube, facebook...',
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF1769D2), size: 18),
                                    suffixIcon: websiteController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => setDialogState(() => websiteController.clear()),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5)),
                                  ),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Pinned Footer Actions (Bərkidilmiş Alt Düymələr)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Ləğv et',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1769D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text(
                              'Yadda Saxla',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            onPressed: () async {
                              final String district = districtController.text.trim();
                              if ((selectedRole == 'usta' || selectedRole == 'worker') && district.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Usta və fəhlə üçün kənd / qəsəbə / ərazi göstərmək vacibdir!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final String initialRole = _normalizeRoleKey(userData?['role']?.toString() ?? 'usta');
                              if (initialRole == 'seller' && _normalizeRoleKey(selectedRole) != 'seller') {
                                final allowed = await _canSwitchFromSellerRole(uid, popParentOnNavigate: true);
                                if (!allowed) return;
                              }
                              final String fullCity = district.isNotEmpty ? '\$selectedCityVal, \$district' : selectedCityVal;
                              final coords = CategoryCityService.getCoordinates(selectedCityVal, district);
                              final updatedName = nameController.text.trim();
                              final updatedPhone = phoneController.text.trim();

                              // Seçilmiş ixtisas adları və kateqoriyaları
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
                                  : (selectedRole == 'worker' ? 'Fəhlə (Köməkçi işlər)' : '');

                              final cleanedTikTok = _cleanTikTokHandle(tiktokController.text.trim());
                              final cleanedInsta = _cleanInstagramHandle(instagramController.text.trim());
                              final rawWeb = websiteController.text.trim();

                              final currentConsent = userData?['locationSharingConsent'] == true;
                              final bool shareCoords = currentConsent;

                              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                'fullName': updatedName,
                                'phone': updatedPhone,
                                'role': selectedRole,
                                'category': updatedTrade,
                                'specialtyIds': selectedSpecialtyIds.toList(),
                                'specialties': specialtyTitles,
                                'specialtyCategories': specialtyCategoryTitles.toList(),
                                'city': fullCity,
                                'isWorking': (selectedRole == 'usta' || selectedRole == 'worker') ? isWorkingStatus : false,
                                'bio': (selectedRole == 'usta' || selectedRole == 'worker') ? bioController.text.trim() : (userData?['bio'] ?? ''),
                                'tiktokHandle': cleanedTikTok,
                                'tiktokConnected': cleanedTikTok.isNotEmpty,
                                'instagramHandle': cleanedInsta,
                                'websiteUrl': rawWeb,
                                if (shareCoords) 'lat': coords[0],
                                if (shareCoords) 'lng': coords[1],
                                if (shareCoords) 'latitude': coords[0],
                                if (shareCoords) 'longitude': coords[1],
                              }, SetOptions(merge: true));

                              // Mövcud Shorts və Post-ları yeni ad və ixtisas ilə sinxronlaşdır
                              await _syncUserDataAcrossCollections(
                                uid,
                                newName: updatedName,
                                newPhone: updatedPhone,
                                newTrade: updatedTrade,
                              );

                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profil məlumatları uğurla yeniləndi! 🎉'), backgroundColor: Colors.green),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }`;

content = content.slice(0, idxStart) + newMethod + content.slice(idxEnd + targetEnd.length);

if (isCRLF) {
  content = content.replace(/\n/g, '\r\n');
}

fs.writeFileSync(filePath, content, 'utf8');
console.log('Successfully replaced _showEditProfileDialog!');
