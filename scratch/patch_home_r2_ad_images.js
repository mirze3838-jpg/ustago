const fs = require('fs');

let content = fs.readFileSync('lib/screens/home_screen.dart', 'utf8');

// 1. Store logo in _showUserStoreModal
const oldStoreLogo = `                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: _HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                        ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                        : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30),
                                  ),`;

const newStoreLogo = `                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: (storeData?['logoUrl'] ?? '').toString().startsWith('http')
                                        ? ClipOval(
                                            child: Image.network(
                                              storeData!['logoUrl'].toString(),
                                              fit: BoxFit.cover,
                                              width: 56,
                                              height: 56,
                                              errorBuilder: (_, __, ___) => _HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                                  ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                                  : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30),
                                            ),
                                          )
                                        : (_HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                            ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                            : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30)),
                                  ),`;

if (content.includes(oldStoreLogo)) {
  content = content.replace(oldStoreLogo, newStoreLogo);
  console.log('Updated store logo in home_screen.dart');
}

// 2. Product in _showUserStoreModal
const oldStoreProdImg = `                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),`;

const newStoreProdImg = `                                      child: (pData['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              pData['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => imgBytes != null
                                                  ? Image.memory(imgBytes, fit: BoxFit.cover)
                                                  : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
                                            )
                                          : (imgBytes != null
                                              ? Image.memory(imgBytes, fit: BoxFit.cover)
                                              : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8))),`;

if (content.includes(oldStoreProdImg)) {
  content = content.replace(oldStoreProdImg, newStoreProdImg);
  console.log('Updated store products in home_screen.dart');
}

// 3. Listings in _showUserListingsModal
const oldListingsImg = `                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),`;

const newListingsImg = `                                      child: (data['imageUrl'] ?? '').toString().startsWith('http')
                                          ? Image.network(
                                              data['imageUrl'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => imgBytes != null
                                                  ? Image.memory(imgBytes, fit: BoxFit.cover)
                                                  : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),
                                            )
                                          : (imgBytes != null
                                              ? Image.memory(imgBytes, fit: BoxFit.cover)
                                              : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28)),`;

if (content.includes(oldListingsImg)) {
  content = content.replace(oldListingsImg, newListingsImg);
  console.log('Updated listings in home_screen.dart');
}

fs.writeFileSync('lib/screens/home_screen.dart', content, 'utf8');
console.log('Saved home_screen.dart');
