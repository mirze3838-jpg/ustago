const fs = require('fs');

let content = fs.readFileSync('lib/screens/market_screen.dart', 'utf8');

// 1. Add "Mağaza" badge and Star badge to the product photo stack in _buildProductGridCard
const oldStackChild = `                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isFav) {
                            _favoriteIds.remove(favKey);
                          } else {
                            _favoriteIds.add(favKey);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF1769D2),
                        ),
                      ),
                    ),
                  ),`;

const newStackChild = `                  // Üst-sağ Seçilmişlər düyməsi
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isFav) {
                            _favoriteIds.remove(favKey);
                          } else {
                            _favoriteIds.add(favKey);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF1769D2),
                        ),
                      ),
                    ),
                  ),

                  // Alt-sol "Mağaza" nişanı (Nümunə Şəkil 1-ə tam uyğun)
                  if ((prod['store'] ?? prod['storeName'] ?? '').toString().isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Mağaza',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // Alt-sağ VIP Ulduz nişanı (Nümunə Şəkil 1 & 2-yə tam uyğun)
                  if (prod['isVip'] == true)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1769D2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                      ),
                    ),`;

if (content.includes(oldStackChild)) {
  content = content.replace(oldStackChild, newStackChild);
  console.log('Successfully added Mağaza and VIP star badges to product photo');
} else {
  console.error('Could not find oldStackChild');
}

// 2. Make the store name clickable in the card to open StoreDetailScreen
const oldStoreRow = `                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 11.5, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            prod['store']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF94A3B8)),
                        Text(
                          prod['city']?.toString() ?? 'Bakı',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),`;

const newStoreRow = `                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final sName = (prod['store'] ?? prod['storeName'] ?? 'Mağaza').toString();
                              final sOwner = (prod['ownerId'] ?? prod['userId'] ?? '').toString();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoreDetailScreen(
                                    store: {
                                      'title': sName,
                                      'ownerId': sOwner,
                                      'userId': sOwner,
                                      'phone': prod['phone'] ?? '',
                                      'whatsapp': prod['whatsapp'] ?? prod['phone'] ?? '',
                                      'address': prod['address'] ?? prod['city'] ?? 'Bakı',
                                      'city': prod['city'] ?? 'Bakı',
                                      'category': prod['category'] ?? 'Tikinti Materialları',
                                      'description': 'Bu mağazanın aktiv məhsul və elanları.',
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 11.5, color: Color(0xFF1769D2)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    prod['store']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF1769D2), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF94A3B8)),
                        Text(
                          prod['city']?.toString() ?? 'Bakı',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),`;

if (content.includes(oldStoreRow)) {
  content = content.replace(oldStoreRow, newStoreRow);
  console.log('Successfully made store name clickable to StoreDetailScreen');
} else {
  console.error('Could not find oldStoreRow');
}

fs.writeFileSync('lib/screens/market_screen.dart', content, 'utf8');
console.log('Updated market_screen.dart');
