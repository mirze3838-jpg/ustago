const fs = require('fs');

// 1. Update lib/screens/market_screen.dart
const marketPath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/market_screen.dart';
let marketContent = fs.readFileSync(marketPath, 'utf8');

const isMarketCRLF = marketContent.includes('\r\n');
if (isMarketCRLF) marketContent = marketContent.replace(/\r\n/g, '\n');

// Add import for market_detail_screens.dart
if (!marketContent.includes("import 'market_detail_screens.dart';")) {
  marketContent = marketContent.replace(
    "import 'login_screen.dart';",
    "import 'login_screen.dart';\nimport 'market_detail_screens.dart';"
  );
  console.log('Added market_detail_screens.dart import to market_screen.dart');
}

// In firestoreProducts.add, include isVip, bumpedAt, createdAt, views
const targetFirestoreAdd = `              if (data['listingType']?.toString() == 'product') {
                firestoreProducts.add({
                  'id': d.id,
                  'ownerId': data['ownerId'] ?? data['userId'],
                  'userId': data['userId'] ?? data['ownerId'],
                  'title': data['title'] ?? '',
                  'unit': (data['unit']?.toString().isNotEmpty == true) ? data['unit'].toString() : '1 ədəd',
                  'price': (data['price']?.toString().isNotEmpty == true) ? data['price'].toString() : 'Razılaşma',
                  'store': (data['storeName']?.toString().isNotEmpty == true)
                      ? data['storeName'].toString()
                      : (data['address']?.toString().isNotEmpty == true ? data['address'].toString() : 'Mağaza'),
                  'city': (data['city']?.toString().isNotEmpty == true) ? data['city'].toString() : 'Bakı',
                  'address': data['address'] ?? '',
                  'phone': data['phone'] ?? '',
                  'whatsapp': data['whatsapp'] ?? data['phone'] ?? '',
                  'category': data['category'] ?? 'Tikinti Materialları',
                  'description': data['description'] ?? '',
                  'imageBase64': data['imageBase64'] ?? '',
                });
              }`;

const replaceFirestoreAdd = `              if (data['listingType']?.toString() == 'product') {
                final sName = (data['store']?.toString().isNotEmpty == true)
                    ? data['store'].toString()
                    : (data['storeName']?.toString().isNotEmpty == true ? data['storeName'].toString() : 'Mağaza');
                firestoreProducts.add({
                  'id': d.id,
                  'ownerId': data['ownerId'] ?? data['userId'],
                  'userId': data['userId'] ?? data['ownerId'],
                  'title': data['title'] ?? '',
                  'unit': (data['unit']?.toString().isNotEmpty == true) ? data['unit'].toString() : '1 ədəd',
                  'price': (data['price']?.toString().isNotEmpty == true) ? data['price'].toString() : 'Razılaşma',
                  'store': sName,
                  'storeName': sName,
                  'city': (data['city']?.toString().isNotEmpty == true) ? data['city'].toString() : 'Bakı',
                  'address': data['address'] ?? '',
                  'phone': data['phone'] ?? '',
                  'whatsapp': data['whatsapp'] ?? data['phone'] ?? '',
                  'category': data['category'] ?? 'Tikinti Materialları',
                  'description': data['description'] ?? '',
                  'imageBase64': data['imageBase64'] ?? '',
                  'isVip': data['isVip'] == true,
                  'vipUntil': data['vipUntil'],
                  'bumpedAt': data['bumpedAt'],
                  'createdAt': data['createdAt'],
                  'views': data['views'] ?? 48,
                });
              }`;

if (marketContent.includes(targetFirestoreAdd)) {
  marketContent = marketContent.replace(targetFirestoreAdd, replaceFirestoreAdd);
  console.log('Updated firestoreProducts mapping in market_screen.dart');
} else {
  console.warn('Could not find targetFirestoreAdd in market_screen.dart');
}

// In filtered sorting, sort VIP and bumped first
const targetSortBlock = `            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(`;

const replaceSortBlock = `            // VIP və İrəli çəkilmiş elanları ən önə qaldırırıq
            filtered.sort((a, b) {
              if (a['isVip'] == true && b['isVip'] != true) return -1;
              if (b['isVip'] == true && a['isVip'] != true) return 1;
              final ta = a['bumpedAt'] ?? a['createdAt'];
              final tb = b['bumpedAt'] ?? b['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });

            if (filtered.isEmpty) {
              return const SliverToBoxAdapter(`;

if (marketContent.includes(targetSortBlock)) {
  marketContent = marketContent.replace(targetSortBlock, replaceSortBlock);
  console.log('Added VIP/Bump sorting to market_screen.dart');
} else {
  console.warn('Could not find targetSortBlock in market_screen.dart');
}

// Update _buildProductGridCard: onTap to ProductDetailScreen and add badges & store link
const targetGridCardOnTap = `    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showProductDetailSheet(prod),`;

const replaceGridCardOnTap = `    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: prod),
          ),
        );
      },`;

if (marketContent.includes(targetGridCardOnTap)) {
  marketContent = marketContent.replace(targetGridCardOnTap, replaceGridCardOnTap);
  console.log('Updated _buildProductGridCard onTap to ProductDetailScreen');
} else {
  console.warn('Could not find targetGridCardOnTap');
}

// Update _buildStoreCard: onTap to StoreDetailScreen
const targetStoreCardOnTap = `    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showStoreDetailSheet(store),`;

const replaceStoreCardOnTap = `    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDetailScreen(store: store),
          ),
        );
      },`;

if (marketContent.includes(targetStoreCardOnTap)) {
  marketContent = marketContent.replace(targetStoreCardOnTap, replaceStoreCardOnTap);
  console.log('Updated _buildStoreCard onTap to StoreDetailScreen');
} else {
  console.warn('Could not find targetStoreCardOnTap');
}

if (isMarketCRLF) marketContent = marketContent.replace(/\n/g, '\r\n');
fs.writeFileSync(marketPath, marketContent, 'utf8');
console.log('market_screen.dart written successfully.');


// 2. Update lib/screens/home_screen.dart
const homePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let homeContent = fs.readFileSync(homePath, 'utf8');

const isHomeCRLF = homeContent.includes('\r\n');
if (isHomeCRLF) homeContent = homeContent.replace(/\r\n/g, '\n');

// Add import for market_detail_screens.dart
if (!homeContent.includes("import 'market_detail_screens.dart';")) {
  homeContent = homeContent.replace(
    "import 'market_screen.dart';",
    "import 'market_screen.dart';\nimport 'market_detail_screens.dart';"
  );
  console.log('Added market_detail_screens.dart import to home_screen.dart');
}

// In _showUserStoreModal, make store card and products open StoreDetailScreen and ProductDetailScreen
const targetHomeStoreCard = `                        // Mağaza Kartı
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                          ),
                          child: Column(`;

const replaceHomeStoreCard = `                        // Mağaza Kartı
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => StoreDetailScreen(
                                  store: {'id': storeId, ...storeData!},
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
                            ),
                            child: Column(`;

// Also need closing paren for InkWell
const targetHomeStoreCardEnd = `                                if (isOwner)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6), size: 20),
                                    tooltip: 'Mağazanı Redaktə Et',
                                    onPressed: () {
                                      MarketScreen.showStoreFormSheet(
                                        rootContext,
                                        existingStore: {'id': storeId, ...storeData!},
                                        defaultPhone: userPhone,
                                        defaultAddress: userAddress,
                                      );
                                    },
                                  ),
                              ],
                            ),
                            if ((storeData?['description'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                storeData!['description'].toString(),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                              ),
                            ],
                          ],
                        ),
                      ),`;

const replaceHomeStoreCardEnd = `                                if (isOwner)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6), size: 20),
                                    tooltip: 'Mağazanı Redaktə Et',
                                    onPressed: () {
                                      MarketScreen.showStoreFormSheet(
                                        rootContext,
                                        existingStore: {'id': storeId, ...storeData!},
                                        defaultPhone: userPhone,
                                        defaultAddress: userAddress,
                                      );
                                    },
                                  ),
                              ],
                            ),
                            if ((storeData?['description'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                storeData!['description'].toString(),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: const [
                                Text('Mağazaya və bütün elanlara bax →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),`;

if (homeContent.includes(targetHomeStoreCard) && homeContent.includes(targetHomeStoreCardEnd)) {
  homeContent = homeContent.replace(targetHomeStoreCard, replaceHomeStoreCard);
  homeContent = homeContent.replace(targetHomeStoreCardEnd, replaceHomeStoreCardEnd);
  console.log('Updated store card in _showUserStoreModal with tap navigation.');
} else {
  console.warn('Could not find store card in home_screen.dart');
}

// In _showUserStoreModal, make each product card open ProductDetailScreen on tap
const targetStoreProdTap = `                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),`;

const replaceStoreProdTap = `                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  rootContext,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: {'id': pDoc.id, ...pData},
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),`;

// and closing paren
const targetStoreProdTapEnd = `                                ],
                              ),
                            );
                          }),`;

const replaceStoreProdTapEnd = `                                ],
                              ),
                            ),
                          );
                        }),`;

if (homeContent.includes(targetStoreProdTap) && homeContent.includes(targetStoreProdTapEnd)) {
  homeContent = homeContent.replace(targetStoreProdTap, replaceStoreProdTap);
  homeContent = homeContent.replace(targetStoreProdTapEnd, replaceStoreProdTapEnd);
  console.log('Updated product cards in _showUserStoreModal with tap navigation.');
} else {
  console.warn('Could not find targetStoreProdTap in home_screen.dart');
}

// In _showUserListingsModal, make each listing card open ProductDetailScreen on tap
const targetListingCardTap = `                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                              ),`;

const replaceListingCardTap = `                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  rootContext,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: {'id': doc.id, ...data},
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                                ),`;

// and closing paren for listing
const targetListingCardTapEnd = `                                ],
                              ),
                            );
                          },
                        ),`;

const replaceListingCardTapEnd = `                                ],
                              ),
                            ),
                          );
                        },
                      ),`;

if (homeContent.includes(targetListingCardTap) && homeContent.includes(targetListingCardTapEnd)) {
  homeContent = homeContent.replace(targetListingCardTap, replaceListingCardTap);
  homeContent = homeContent.replace(targetListingCardTapEnd, replaceListingCardTapEnd);
  console.log('Updated listing cards in _showUserListingsModal with tap navigation.');
} else {
  console.warn('Could not find targetListingCardTap in home_screen.dart');
}

if (isHomeCRLF) homeContent = homeContent.replace(/\n/g, '\r\n');
fs.writeFileSync(homePath, homeContent, 'utf8');
console.log('home_screen.dart written successfully.');
