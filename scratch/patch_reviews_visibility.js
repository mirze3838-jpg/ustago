const fs = require('fs');

// 1. Update lib/screens/artisan_detail_screen.dart
let artisan = fs.readFileSync('lib/screens/artisan_detail_screen.dart', 'utf8');

// Make reytinq stat clickable
const oldArtisanRatingStat = `_buildStatItem(count: cleanRating, label: 'reytinq', icon: Icons.star_rounded, iconColor: const Color(0xFFF59E0B)),`;
const newArtisanRatingStat = `InkWell(
                                          onTap: () => setState(() => _selectedTabIndex = 1),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: _buildStatItem(count: cleanRating, label: 'reytinq', icon: Icons.star_rounded, iconColor: const Color(0xFFF59E0B)),
                                          ),
                                        ),`;

if (artisan.includes(oldArtisanRatingStat)) {
  artisan = artisan.replace(oldArtisanRatingStat, newArtisanRatingStat);
  console.log('Made reytinq stat clickable in artisan_detail_screen.dart');
}

// Auto-switch to reviews tab after submitting review
const oldReviewSuccess = `                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rəyiniz uğurla əlavə edildi! Təşəkkür edirik.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }`;
const newReviewSuccess = `                  if (mounted) {
                    setState(() => _selectedTabIndex = 1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rəyiniz uğurla əlavə edildi! Təşəkkür edirik.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }`;
if (artisan.includes(oldReviewSuccess)) {
  artisan = artisan.replace(oldReviewSuccess, newReviewSuccess);
  console.log('Added auto-switch to reviews tab after submission');
}

// Replace icon-only Tab Bar with clear labeled Tabs + live review count
const oldArtisanTabBar = `                    // Tab Bar (Grid vs Rəylər)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTabIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTabIndex == 0 ? const Color(0xFF0F172A) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.grid_on_rounded,
                                  color: _selectedTabIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedTabIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTabIndex == 1 ? const Color(0xFF0F172A) : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.star_outline_rounded,
                                  color: _selectedTabIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),`;

const newArtisanTabBar = `                    // Tab Bar (İşlər vs Rəylər - Aydın yazı və say ilə)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: userId.isNotEmpty
                          ? FirebaseFirestore.instance.collection('users').doc(userId).collection('reviews').snapshots()
                          : const Stream.empty(),
                      builder: (context, revCountSnap) {
                        final int revCount = revCountSnap.data?.docs.length ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTabIndex = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.grid_on_rounded,
                                          color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'İşlər',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabIndex == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTabIndex = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _selectedTabIndex == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: _selectedTabIndex == 1 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Rəylər ($revCount)',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTabIndex == 1 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),`;

if (artisan.includes(oldArtisanTabBar)) {
  artisan = artisan.replace(oldArtisanTabBar, newArtisanTabBar);
  console.log('Updated Tab Bar in artisan_detail_screen.dart');
}

fs.writeFileSync('lib/screens/artisan_detail_screen.dart', artisan, 'utf8');

// 2. Update lib/screens/home_screen.dart (_buildModernUstaProfile)
let home = fs.readFileSync('lib/screens/home_screen.dart', 'utf8');

const oldOwnRatingStat = `                                    _buildUstaStatItem(
                                      count: cleanRating,
                                      label: 'reytinq',
                                      icon: Icons.star_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                    ),`;

const newOwnRatingStat = `                                    InkWell(
                                      onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: _buildUstaStatItem(
                                          count: cleanRating,
                                          label: 'reytinq',
                                          icon: Icons.star_rounded,
                                          iconColor: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),`;

if (home.includes(oldOwnRatingStat)) {
  home = home.replace(oldOwnRatingStat, newOwnRatingStat);
  console.log('Made reytinq stat clickable in home_screen.dart');
}

const oldOwnGridBar = `                // Instagram Üslubunda Tək Şəbəkə (Grid) İndikatoru
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Icon(
                        Icons.grid_on_rounded,
                        color: Color(0xFF0F172A),
                        size: 24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Vahid Qalereya (Foto və Videolar bir yerdə)
                _buildUstaUnifiedGrid(user.uid, displayName, userRole),`;

const newOwnGridBar = `                // İşlər və Müştəri Rəyləri Tabları
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('reviews').snapshots(),
                  builder: (context, revCountSnap) {
                    final int revCount = revCountSnap.data?.docs.length ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _ustaProfileGalleryTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.grid_on_rounded,
                                      color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'İşlər',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _ustaProfileGalleryTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: _ustaProfileGalleryTab == 1 ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Rəylər ($revCount)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _ustaProfileGalleryTab == 1 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 6),

                if (_ustaProfileGalleryTab == 0)
                  _buildUstaUnifiedGrid(user.uid, displayName, userRole)
                else
                  _buildOwnProfileReviewsTab(user.uid, rating.replaceAll('★', '').trim()),`;

if (home.includes(oldOwnGridBar)) {
  home = home.replace(oldOwnGridBar, newOwnGridBar);
  console.log('Added İşlər & Rəylər tabs to _buildModernUstaProfile in home_screen.dart');
}

// Add _buildOwnProfileReviewsTab helper right before _buildServiceChips
const helperTarget = '  /// Ustanın ixtisasına uyğun peşəkar xidmət teqləri';
const helperCode = `  Widget _buildOwnProfileReviewsTab(String userId, String ratingStr) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 34),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$ratingStr / 5.0',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Ümumi \${docs.length} müştəri rəyi',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Hələlik sizin haqqınızda rəy yazılmayıb.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final r = docs[idx].data();
                    final revName = (r['reviewerName'] ?? 'Müştəri').toString();
                    final revComment = (r['comment'] ?? '').toString();
                    final revRating = (r['rating'] as num?)?.toInt() ?? 5;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    child: Text(
                                      revName.isNotEmpty ? revName[0].toUpperCase() : 'M',
                                      style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(revName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                ],
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < revRating ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(revComment, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35)),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

`;

if (home.includes(helperTarget) && !home.includes('_buildOwnProfileReviewsTab(')) {
  home = home.replace(helperTarget, helperCode + helperTarget);
  console.log('Added _buildOwnProfileReviewsTab helper to home_screen.dart');
}

fs.writeFileSync('lib/screens/home_screen.dart', home, 'utf8');
console.log('Saved home_screen.dart');
