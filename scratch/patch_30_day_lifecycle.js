const fs = require('fs');

// 1. In market_screen.dart: filter out ads older than 30 days
let marketContent = fs.readFileSync('lib/screens/market_screen.dart', 'utf8');

// In VIP filter:
const oldVipDocLoop = `            for (final d in docs) {
              final data = d.data();
              if (data['listingType']?.toString() == 'product' && data['isVip'] == true) {`;

const newVipDocLoop = `            for (final d in docs) {
              final data = d.data();
              if (data['listingType']?.toString() == 'product' && data['isVip'] == true) {
                // 30 gündən köhnə elanlar avtomatik gizlədilir
                if (data['createdAt'] is Timestamp) {
                  final passed = DateTime.now().difference((data['createdAt'] as Timestamp).toDate()).inDays;
                  if (passed >= 30) continue;
                }`;

if (marketContent.includes(oldVipDocLoop)) {
  marketContent = marketContent.replace(oldVipDocLoop, newVipDocLoop);
  console.log('Added 30-day filter to VIP section in market_screen.dart');
}

// In general product filter:
const oldFilterCheck = `              final favKey = (p['id'] ?? p['sampleId'] ?? p['title']).toString();
              if (_onlyFavorites && !_favoriteIds.contains(favKey)) return false;`;

const newFilterCheck = `              // 30 gündən köhnə elanlar siyahıdan avtomatik çıxarılır
              if (p['createdAt'] is Timestamp) {
                final passed = DateTime.now().difference((p['createdAt'] as Timestamp).toDate()).inDays;
                if (passed >= 30) return false;
              }

              final favKey = (p['id'] ?? p['sampleId'] ?? p['title']).toString();
              if (_onlyFavorites && !_favoriteIds.contains(favKey)) return false;`;

if (marketContent.includes(oldFilterCheck)) {
  marketContent = marketContent.replace(oldFilterCheck, newFilterCheck);
  console.log('Added 30-day filter to general product feed in market_screen.dart');
}

fs.writeFileSync('lib/screens/market_screen.dart', marketContent, 'utf8');
console.log('Saved market_screen.dart');

// 2. In market_detail_screens.dart: show days left and 30-day expiration renewal
let detailContent = fs.readFileSync('lib/screens/market_detail_screens.dart', 'utf8');

const oldStatBlock = `                        _buildStatRow('Baxış sayı:', '$_viewsCount'),
                        const SizedBox(height: 6),
                        _buildStatRow('Elan nömrəsi:', adNumber),
                        const SizedBox(height: 6),
                        _buildStatRow('Tarix:', formattedDate),`;

const newStatBlock = `                        _buildStatRow('Baxış sayı:', '$_viewsCount'),
                        const SizedBox(height: 6),
                        _buildStatRow('Elan nömrəsi:', adNumber),
                        const SizedBox(height: 6),
                        _buildStatRow('Tarix:', formattedDate),
                        const SizedBox(height: 6),
                        _buildStatRow('Müddət:', isExpired ? 'Müddəti bitib' : '$daysLeft gün qalıb (Maks. 30 gün)'),`;

if (detailContent.includes(oldStatBlock)) {
  detailContent = detailContent.replace(
    "String formattedDate = '17.Nov.2026';",
    `String formattedDate = '17.Nov.2026';
    int daysLeft = 30;
    bool isExpired = false;
    if (_prod['createdAt'] is Timestamp) {
      final dt = (_prod['createdAt'] as Timestamp).toDate();
      final passed = DateTime.now().difference(dt).inDays;
      daysLeft = (30 - passed).clamp(0, 30);
      isExpired = passed >= 30;
    }`
  );
  detailContent = detailContent.replace(oldStatBlock, newStatBlock);

  // Add Expired Banner if isExpired
  const oldPriceBlock = `                  // Qiymət
                  Text(
                    price.contains('AZN') ? price : '$price AZN',`;

  const newPriceBlock = `                  // Müddəti bitmiş elan xəbərdarlığı
                  if (isExpired)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Bu elanın 30 günlük nümayiş müddəti bitib. Elanı yeniləyərək yenidən aktiv edin.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B)),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final docId = _prod['id']?.toString();
                              if (docId != null && docId.isNotEmpty) {
                                await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'bumpedAt': FieldValue.serverTimestamp(),
                                });
                                setState(() {
                                  _prod['createdAt'] = Timestamp.now();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Elanın müddəti 30 gün uzadıldı və ən ön sıraya keçirildi! 🚀')),
                                );
                              }
                            },
                            child: const Text('30 gün uzat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Qiymət
                  Text(
                    price.contains('AZN') ? price : '$price AZN',`;

  detailContent = detailContent.replace(oldPriceBlock, newPriceBlock);
  console.log('Added 30-day expiration check and renewal to ProductDetailScreen');
}

fs.writeFileSync('lib/screens/market_detail_screens.dart', detailContent, 'utf8');
console.log('Saved market_detail_screens.dart');

// 3. In home_screen.dart: show days left and renewal button in _showUserListingsModal
let homeContent = fs.readFileSync('lib/screens/home_screen.dart', 'utf8');

const oldListingCardRow = `                                        const SizedBox(height: 3),
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
                                        ),`;

const newListingCardRow = `                                        const SizedBox(height: 3),
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
                                              const SizedBox(width: 8),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isExpired ? 'Bitib' : '$daysLeft gün',
                                                style: TextStyle(
                                                  color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),`;

if (homeContent.includes(oldListingCardRow)) {
  homeContent = homeContent.replace(
    "final phone = (data['phone'] ?? '').toString();",
    `final phone = (data['phone'] ?? '').toString();
                            int daysLeft = 30;
                            bool isExpired = false;
                            if (data['createdAt'] is Timestamp) {
                              final dt = (data['createdAt'] as Timestamp).toDate();
                              final passed = DateTime.now().difference(dt).inDays;
                              daysLeft = (30 - passed).clamp(0, 30);
                              isExpired = passed >= 30;
                            }`
  );
  homeContent = homeContent.replace(oldListingCardRow, newListingCardRow);

  // Add renewal button next to edit and delete
  const oldEditBtn = `                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),`;

  const newEditBtn = `                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isExpired)
                                          InkWell(
                                            onTap: () async {
                                              await FirebaseFirestore.instance.collection('market_stores').doc(doc.id).update({
                                                'createdAt': FieldValue.serverTimestamp(),
                                                'bumpedAt': FieldValue.serverTimestamp(),
                                              });
                                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                                const SnackBar(content: Text('Elanın müddəti 30 gün uzadıldı! 🚀')),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              margin: const EdgeInsets.only(right: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('🔄 Uzat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),`;

  homeContent = homeContent.replace(oldEditBtn, newEditBtn);
  console.log('Added 30-day expiration check and renewal to home_screen.dart listings');
}

fs.writeFileSync('lib/screens/home_screen.dart', homeContent, 'utf8');
console.log('Saved home_screen.dart');
