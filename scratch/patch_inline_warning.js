const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) {
  content = content.replace(/\r\n/g, '\n');
}

// 1. Declare specialtyLimitWarning in _showEditProfileDialog
const targetVar = `    final specialtySearchController = TextEditingController();
    String specialtySearchQuery = '';`;

const replaceVar = `    final specialtySearchController = TextEditingController();
    String specialtySearchQuery = '';
    String specialtyLimitWarning = '';`;

if (!content.includes(targetVar)) {
  console.error('targetVar not found!');
  process.exit(1);
}
content = content.replace(targetVar, replaceVar);
console.log('specialtyLimitWarning declared successfully.');

// 2. Clear warning on remove or clear
const targetClear = `                                        GestureDetector(
                                          onTap: () => setDialogState(() => selectedSpecialtyIds.clear()),
                                          child: const Text(
                                            'Hamısını təmizlə',
                                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                          ),
                                        ),`;

const replaceClear = `                                        GestureDetector(
                                          onTap: () => setDialogState(() {
                                            specialtyLimitWarning = '';
                                            selectedSpecialtyIds.clear();
                                          }),
                                          child: const Text(
                                            'Hamısını təmizlə',
                                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                          ),
                                        ),`;

if (!content.includes(targetClear)) {
  console.error('targetClear not found!');
  process.exit(1);
}
content = content.replace(targetClear, replaceClear);
console.log('Clear updated successfully.');

const targetChipDelete = `                                          onDeleted: () => setDialogState(() => selectedSpecialtyIds.remove(sId)),`;
const replaceChipDelete = `                                          onDeleted: () => setDialogState(() {
                                            specialtyLimitWarning = '';
                                            selectedSpecialtyIds.remove(sId);
                                          }),`;

if (!content.includes(targetChipDelete)) {
  console.error('targetChipDelete not found!');
  process.exit(1);
}
content = content.replace(targetChipDelete, replaceChipDelete);
console.log('ChipDelete updated successfully.');

// 3. Add inline warning banner right above the accordion groups
const targetAboveAccordion = `                            // Qeydiyyatdakı Kateqoriya Qrupları Akordeon Şəklində`;

const replaceAboveAccordion = `                            // 5-ci ixtisas seçilərkən birbaşa bölmə daxilində görünən xəbərdarlıq banneri
                            if (specialtyLimitWarning.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        specialtyLimitWarning,
                                        style: const TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setDialogState(() => specialtyLimitWarning = ''),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Qeydiyyatdakı Kateqoriya Qrupları Akordeon Şəklində`;

if (!content.includes(targetAboveAccordion)) {
  console.error('targetAboveAccordion not found!');
  process.exit(1);
}
content = content.replace(targetAboveAccordion, replaceAboveAccordion);
console.log('AboveAccordion replaced successfully.');

// 4. In expanded group, add inside-group warning and update FilterChip onSelected
const targetFilterChip = `                                    if (isExpanded) ...[
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
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],`;

const replaceFilterChip = `                                    if (isExpanded) ...[
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      if (specialtyLimitWarning.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFECDD3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  specialtyLimitWarning,
                                                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11.5, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => setDialogState(() => specialtyLimitWarning = ''),
                                                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                                              ),
                                            ],
                                          ),
                                        ),
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
                                                    if (selectedSpecialtyIds.length >= 4) {
                                                      specialtyLimitWarning = 'Maksimum 4 ixtisas sahəsi seçə bilərsiniz!';
                                                      return;
                                                    }
                                                    specialtyLimitWarning = '';
                                                    selectedSpecialtyIds.add(itemId);
                                                  } else {
                                                    specialtyLimitWarning = '';
                                                    selectedSpecialtyIds.remove(itemId);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],`;

if (!content.includes(targetFilterChip)) {
  console.error('targetFilterChip not found!');
  process.exit(1);
}
content = content.replace(targetFilterChip, replaceFilterChip);
console.log('FilterChip updated successfully.');

if (isCRLF) {
  content = content.replace(/\n/g, '\r\n');
}

fs.writeFileSync(filePath, content, 'utf8');
console.log('All changes applied successfully!');
