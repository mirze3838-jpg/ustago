const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) content = content.replace(/\r\n/g, '\n');

// 1. In _canSwitchFromSellerRole, return true always
const targetCanSwitchStart = '  Future<bool> _canSwitchFromSellerRole(';
const targetCanSwitchEnd = '  Future<bool> _hasActiveSellerListings(';

const idxCanStart = content.indexOf(targetCanSwitchStart);
const idxCanEnd = content.indexOf(targetCanSwitchEnd, idxCanStart);

if (idxCanStart !== -1 && idxCanEnd !== -1) {
  const replaceCanSwitch = `  Future<bool> _canSwitchFromSellerRole(
    String uid, {
    bool popParentOnNavigate = false,
  }) async {
    // İndi hər kəs (Usta, Fəhlə, Müştəri, Satıcı) mağaza və elan aça bildiyi üçün keçid hər zaman sərbəstdir
    return true;
  }

`;
  content = content.slice(0, idxCanStart) + replaceCanSwitch + content.slice(idxCanEnd);
  console.log('_canSwitchFromSellerRole updated successfully.');
}

// 2. In _showProfileOptionsMenu, replace Mağazam / Elanlarım with separate Mağazamı İdarə Et & Elanlarımı İdarə Et
const targetMenuOptions = `                  // 6. Mağazam / Elanlarım
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.storefront_outlined, color: Color(0xFF0D9488), size: 20),
                    ),
                    title: const Text('Mağazam / Elanlarım', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Alış-satış bölməsindəki elanlarınız', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentIndex = 2;
                        _openMyListingsSignal++;
                      });
                    },
                  ),`;

const replaceMenuOptions = `                  // 6. Mağazamı İdarə Et
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    title: const Text('Mağazamı İdarə Et', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Mağazanızı açın, məhsullarınızı vitrinə qoyun və idarə edin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUserStoreModal(context, uid, userData?['fullName'] ?? '', isOwner: true);
                    },
                  ),

                  // 6.1 Elanlarımı İdarə Et
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFFEA580C), size: 20),
                    ),
                    title: const Text('Elanlarımı İdarə Et', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Fərdi alış-satış elanlarınızı yerləşdirin, redaktə edin və ya silin', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showUserListingsModal(context, uid, userData?['fullName'] ?? '', isOwner: true);
                    },
                  ),`;

if (!content.includes(targetMenuOptions)) {
  console.error('targetMenuOptions not found!');
  process.exit(1);
}
content = content.replace(targetMenuOptions, replaceMenuOptions);
console.log('Menu options replaced successfully.');

// 3. In _buildModernUstaProfile, add Mağaza and Elanlar highlight circles
const targetHighlights = `                      _buildHighlightCircle(
                        icon: Icons.location_on_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFFEF3C7),
                        borderColor: const Color(0xFFF59E0B),
                        label: 'Məkan',
                        onTap: () => _showLocationPickerModal(user.uid, userData),
                      ),
                    ],
                  ),
                ),`;

const replaceHighlights = `                      _buildHighlightCircle(
                        icon: Icons.location_on_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFFEF3C7),
                        borderColor: const Color(0xFFF59E0B),
                        label: 'Məkan',
                        onTap: () => _showLocationPickerModal(user.uid, userData),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.storefront_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        bgColor: const Color(0xFFF5F3FF),
                        borderColor: const Color(0xFF8B5CF6),
                        label: 'Mağaza',
                        onTap: () => _showUserStoreModal(context, user.uid, displayName, isOwner: true),
                      ),
                      _buildHighlightCircle(
                        icon: Icons.campaign_rounded,
                        iconColor: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFF7ED),
                        borderColor: const Color(0xFFEA580C),
                        label: 'Elanlar',
                        onTap: () => _showUserListingsModal(context, user.uid, displayName, isOwner: true),
                      ),
                    ],
                  ),
                ),`;

if (!content.includes(targetHighlights)) {
  console.error('targetHighlights not found!');
  process.exit(1);
}
content = content.replace(targetHighlights, replaceHighlights);
console.log('Highlights replaced successfully.');

// 4. Add _showUserStoreModal and _showUserListingsModal methods
const targetBeforeUstaUnifiedGrid = '  /// Vahid Qalereya (Foto və Videolar birgə, İnstagram üslubunda)\n  Widget _buildUstaUnifiedGrid(';

const replaceWithModals = `  /// İstifadəçinin mağaza profilini və məhsullarını göstərən modal
  void _showUserStoreModal(BuildContext context, String targetUid, String authorName, {bool isOwner = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('market_stores')
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final userDocs = allDocs.where((d) {
              final data = d.data();
              return data['ownerId'] == targetUid || data['userId'] == targetUid;
            }).toList();

            final storeDocs = userDocs.where((d) => (d.data()['listingType'] ?? 'store') == 'store').toList();
            final productDocs = userDocs.where((d) => d.data()['listingType'] == 'product' && (d.data()['store'] != null && d.data()['store'].toString().isNotEmpty)).toList();

            final hasStore = storeDocs.isNotEmpty;
            final storeData = hasStore ? storeDocs.first.data() : null;
            final storeId = hasStore ? storeDocs.first.id : null;

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner ? 'Mənim Mağazam' : '\$authorName — Mağazası',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasStore ? (storeData?['category'] ?? 'Tikinti və Təmir Mağazası').toString() : 'Mağaza bölməsi',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner && hasStore)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            MarketScreen.showProductFormSheet(context);
                          },
                          icon: const Icon(Icons.add, size: 17, color: Color(0xFF1769D2)),
                          label: const Text('+ Məhsul', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1769D2))),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!hasStore) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.storefront_outlined, size: 36, color: Color(0xFF8B5CF6)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Mağaza elanı yoxdur',
                                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isOwner
                                    ? 'Hələlik heç bir mağaza yaratmamısınız. Öz mağazanızı açaraq tikinti malları və alətlərinizi UstaGo-da satın!'
                                    : 'Bu istifadəçinin hələlik heç bir aktiv mağaza elanı yoxdur.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                              ),
                              if (isOwner) ...[
                                const SizedBox(height: 18),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.add_business_rounded, size: 18),
                                  label: const Text('Mağaza Aç və Məhsul Yerləşdir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    MarketScreen.showStoreFormSheet(context);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Mağaza Kartı
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: _HomeScreenState._decodeB64(storeData?['logoBase64']?.toString()) != null
                                        ? ClipOval(child: Image.memory(_HomeScreenState._decodeB64(storeData!['logoBase64'].toString())!, fit: BoxFit.cover, width: 56, height: 56))
                                        : const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6), size: 30),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (storeData?['title'] ?? 'Mağaza').toString(),
                                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (storeData?['address'] ?? 'Ünvan qeyd olunmayıb').toString(),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Əlaqə: \${storeData?['phone'] ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6), size: 20),
                                      tooltip: 'Mağazanı Redaktə Et',
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        MarketScreen.showStoreFormSheet(context, existingStore: {'id': storeId, ...storeData!});
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
                        ),
                        const SizedBox(height: 18),

                        // Vitrindəki Məhsullar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vitrindəki Məhsullar (\${productDocs.length})',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (isOwner)
                              InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  MarketScreen.showProductFormSheet(context);
                                },
                                child: const Text(
                                  '+ Məhsul Əlavə Et',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (productDocs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 36),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Mağazanın vitrinində hələlik məhsul yoxdur',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                  if (isOwner) ...[
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        MarketScreen.showProductFormSheet(context);
                                      },
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('İlk Məhsulunu Əlavə Et'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else
                          ...productDocs.map((pDoc) {
                            final pData = pDoc.data();
                            final imgB64 = pData['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFF1F5F9),
                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (pData['title'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '\${pData['price'] ?? ''} (\${pData['unit'] ?? '1 ədəd'})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (pData['category'] ?? '').toString(),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            MarketScreen.showProductFormSheet(context, existingProduct: {'id': pDoc.id, ...pData});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('market_stores').doc(pDoc.id).delete();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Məhsul silindi.')));
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// İstifadəçinin fərdi alış-satış elanlarını göstərən modal
  void _showUserListingsModal(BuildContext context, String targetUid, String authorName, {bool isOwner = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollCtrl) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('market_stores')
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final listings = allDocs.where((d) {
              final data = d.data();
              final isMatchingUser = data['ownerId'] == targetUid || data['userId'] == targetUid;
              final isListing = data['listingType'] != 'store';
              return isMatchingUser && isListing;
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Color(0xFFEA580C), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner ? 'Mənim Elanlarım' : '\$authorName — Elanları',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\${listings.length} aktiv elan mövcuddur',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            MarketScreen.showProductFormSheet(context);
                          },
                          icon: const Icon(Icons.add, size: 17, color: Color(0xFFEA580C)),
                          label: const Text('+ Yeni Elan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFEA580C))),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: listings.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.campaign_outlined, size: 36, color: Color(0xFFEA580C)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Elan yoxdur',
                                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isOwner
                                      ? 'Hələlik heç bir alış-satış elanı yerləşdirməmisiniz. Məhsul, alət və ya material satmaq üçün elan verin!'
                                      : 'Bu istifadəçinin hələlik heç bir aktiv alış-satış elanı yoxdur.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                                ),
                                if (isOwner) ...[
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA580C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text('Yeni Elan Yerləşdir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      MarketScreen.showProductFormSheet(context);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: listings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final doc = listings[idx];
                            final data = doc.data();
                            final imgB64 = data['imageBase64']?.toString();
                            final imgBytes = _HomeScreenState._decodeB64(imgB64);
                            final title = (data['title'] ?? '').toString();
                            final price = (data['price'] ?? '').toString();
                            final city = (data['city'] ?? '').toString();
                            final phone = (data['phone'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: const Color(0xFFF1F5F9),
                                      child: imgBytes != null
                                          ? Image.memory(imgBytes, fit: BoxFit.cover)
                                          : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          price,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(height: 3),
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
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1769D2)),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            MarketScreen.showProductFormSheet(context, existingProduct: {'id': doc.id, ...data});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('market_stores').doc(doc.id).delete();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elan silindi.')));
                                          },
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Vahid Qalereya (Foto və Videolar birgə, İnstagram üslubunda)
  Widget _buildUstaUnifiedGrid(`;

const idxGrid = content.indexOf(targetBeforeUstaUnifiedGrid);
if (idxGrid === -1) {
  console.error('targetBeforeUstaUnifiedGrid not found!');
  process.exit(1);
}

content = content.slice(0, idxGrid) + replaceWithModals + content.slice(idxGrid + targetBeforeUstaUnifiedGrid.length);
console.log('Modals added successfully.');

if (isCRLF) content = content.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, content, 'utf8');
console.log('home_screen.dart patched successfully.');
