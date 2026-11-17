const fs = require('fs');

let content = fs.readFileSync('lib/screens/home_screen.dart', 'utf8');

// 1. Add pDaysLeft and pIsExpired to _showUserStoreModal
const oldPDataDecl = `                          ...productDocs.map((pDoc) {
                            final pData = pDoc.data();
                            final imgB64 = pData['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);`;

const newPDataDecl = `                          ...productDocs.map((pDoc) {
                            final pData = pDoc.data();
                            final imgB64 = pData['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);
                            int pDaysLeft = 30;
                            bool pIsExpired = false;
                            if (pData['createdAt'] is Timestamp) {
                              final dt = (pData['createdAt'] as Timestamp).toDate();
                              final passed = DateTime.now().difference(dt).inDays;
                              pDaysLeft = (30 - passed).clamp(0, 30);
                              pIsExpired = passed >= 30;
                            }`;

if (content.includes(oldPDataDecl)) {
  content = content.replace(oldPDataDecl, newPDataDecl);
  console.log('Added pDaysLeft and pIsExpired in _showUserStoreModal');
}

// 2. Fix the renewal button in _showUserStoreModal to use pIsExpired and pDoc.id
const oldStoreAction = `                                  if (isOwner)
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
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': pDoc.id, ...pData},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),`;

const newStoreAction = `                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (pIsExpired)
                                          InkWell(
                                            onTap: () async {
                                              await FirebaseFirestore.instance.collection('market_stores').doc(pDoc.id).update({
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
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': pDoc.id, ...pData},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),`;

if (content.includes(oldStoreAction)) {
  content = content.replace(oldStoreAction, newStoreAction);
  console.log('Fixed renewal button in _showUserStoreModal');
}

// 3. Add renewal button in _showUserListingsModal
const oldListingsBtn = `                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': doc.id, ...data},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),`;

const newListingsBtn = `                                  if (isOwner)
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
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            MarketScreen.showProductFormSheet(
                                              rootContext,
                                              existingProduct: {'id': doc.id, ...data},
                                              defaultPhone: userPhone,
                                              defaultAddress: userAddress,
                                            );
                                          },
                                        ),`;

if (content.includes(oldListingsBtn)) {
  content = content.replace(oldListingsBtn, newListingsBtn);
  console.log('Added renewal button in _showUserListingsModal');
}

fs.writeFileSync('lib/screens/home_screen.dart', content, 'utf8');
console.log('Saved home_screen.dart');
