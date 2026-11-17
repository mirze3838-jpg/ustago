const fs = require('fs');

// 1. Update _sampleProducts in market_screen.dart to have isVip: true for a few items
let marketContent = fs.readFileSync('lib/screens/market_screen.dart', 'utf8');

// Update sample products to include isVip
marketContent = marketContent.replace(
  "'visualType': 'brick',",
  "'visualType': 'brick',\n      'isVip': true,"
);
marketContent = marketContent.replace(
  "'visualType': 'cement',",
  "'visualType': 'cement',\n      'isVip': true,"
);

// Add VIP carousel builder to _buildProductsTab
const vipSectionCode = `
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
                          '\${_selectedProductCategory == 'Hamısı' ? 'Bütün məhsullar' : _selectedProductCategory}',
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
`;

const targetGridComment = '// 2. 2 Sütunlu Məhsul Gridi';
if (marketContent.includes(targetGridComment)) {
  marketContent = marketContent.replace(targetGridComment, vipSectionCode + '\n        ' + targetGridComment);
  console.log('Successfully inserted VIP section and Elanlar header into market_screen.dart');
} else {
  console.error('Could not find targetGridComment in market_screen.dart');
}

fs.writeFileSync('lib/screens/market_screen.dart', marketContent, 'utf8');

// 2. In home_screen.dart, ensure store card in _showUserStoreModal is tapable to open StoreDetailScreen
let homeContent = fs.readFileSync('lib/screens/home_screen.dart', 'utf8');

const targetStoreCard = `                        // Mağaza Kartı
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                          ),`;

const replacementStoreCard = `                        // Mağaza Kartı
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => StoreDetailScreen(
                                  store: {
                                    'id': storeId,
                                    ...?storeData,
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                            ),`;

if (homeContent.includes(targetStoreCard)) {
  // Replace the open Container and close InkWell
  // Find where this container closes before "const SizedBox(height: 18),"
  const endIdx = homeContent.indexOf('const SizedBox(height: 18),\n\n                        // Vitrindəki Məhsullar');
  if (endIdx !== -1) {
    const cardPart = homeContent.substring(homeContent.indexOf(targetStoreCard), endIdx);
    const updatedCardPart = cardPart.replace(targetStoreCard, replacementStoreCard) + ')\n                        ';
    homeContent = homeContent.substring(0, homeContent.indexOf(targetStoreCard)) + updatedCardPart + homeContent.substring(endIdx);
    console.log('Successfully made store card clickable to StoreDetailScreen in home_screen.dart');
  }
}

fs.writeFileSync('lib/screens/home_screen.dart', homeContent, 'utf8');
console.log('Done patching.');
