const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

// Normalize line endings to LF for consistent matching
const isCRLF = content.includes('\r\n');
if (isCRLF) {
  content = content.replace(/\r\n/g, '\n');
}

// 1. Stats Bar Update (replace lines 6524-6568)
const target1 = `                      // 3 Göstərici: İşlərim (Portfolio) • Video İşlər (Shorts) • Reytinq
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, postSnap) {
                            final postCount = postSnap.data?.docs.where((d) => d.data()['isVideo'] != true).length ?? 0;
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('shorts')
                                  .where('userId', isEqualTo: user.uid)
                                  .snapshots(),
                              builder: (context, shortSnap) {
                                final shortCount = shortSnap.data?.docs.length ?? 0;
                                final cleanRating = rating.replaceAll('★', '').trim();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildUstaStatItem(
                                      count: '$postCount',
                                      label: 'İşlərim',
                                      icon: Icons.photo_library_outlined,
                                      iconColor: const Color(0xFF1769D2),
                                    ),
                                    _buildUstaStatItem(
                                      count: '$shortCount',
                                      label: 'Video İşlər',
                                      icon: Icons.play_circle_outline_rounded,
                                      iconColor: const Color(0xFFE11D48),
                                    ),
                                    _buildUstaStatItem(
                                      count: cleanRating,
                                      label: 'Reytinq',
                                      icon: Icons.star_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),`;

const replace1 = `                      // 3 Göstərici: Göndəri (vahid foto və videolar) • Video • Reytinq
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, postSnap) {
                            final postCount = postSnap.data?.docs.length ?? 0;
                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('shorts')
                                  .where('userId', isEqualTo: user.uid)
                                  .snapshots(),
                              builder: (context, shortSnap) {
                                final shortCount = shortSnap.data?.docs.length ?? 0;
                                final totalCount = postCount + shortCount;
                                final cleanRating = rating.replaceAll('★', '').trim();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildUstaStatItem(
                                      count: '$totalCount',
                                      label: 'göndəri',
                                      icon: Icons.grid_on_rounded,
                                      iconColor: const Color(0xFF1769D2),
                                    ),
                                    _buildUstaStatItem(
                                      count: '$shortCount',
                                      label: 'video',
                                      icon: Icons.play_circle_outline_rounded,
                                      iconColor: const Color(0xFFFE2C55),
                                    ),
                                    _buildUstaStatItem(
                                      count: cleanRating,
                                      label: 'reytinq',
                                      icon: Icons.star_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),`;

if (!content.includes(target1)) {
  console.error('Target 1 not found!');
  process.exit(1);
}
content = content.replace(target1, replace1);
console.log('Target 1 replaced successfully.');

// 2. Tab Bar Replacement in _buildModernUstaProfile (lines 6783-6881)
const target2 = `                // UstaGo Brend Tab Bar (Foto Portfolio / Video İşlər)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Tab 0: Foto Portfolio
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _ustaProfileGalleryTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _ustaProfileGalleryTab == 0 ? Colors.white : Colors.transparent,
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
                                  Icons.photo_library_rounded,
                                  color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Foto Portfolio',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _ustaProfileGalleryTab == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _ustaProfileGalleryTab == 0 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: Video İşlər (Shorts / TikTok)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _ustaProfileGalleryTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _ustaProfileGalleryTab == 1 ? Colors.white : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: _ustaProfileGalleryTab == 1 ? const Color(0xFF1769D2) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: _ustaProfileGalleryTab == 1 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Video İşlər',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _ustaProfileGalleryTab == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _ustaProfileGalleryTab == 1 ? const Color(0xFF1769D2) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Tab Kontenti
                if (_ustaProfileGalleryTab == 0)
                  _buildUstaPortfolioGrid(user.uid, displayName, userRole)
                else
                  _buildUstaShortsGrid(user.uid, displayName, userRole),`;

const replace2 = `                // Instagram Üslubunda Tək Şəbəkə (Grid) İndikatoru
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

if (!content.includes(target2)) {
  console.error('Target 2 not found!');
  process.exit(1);
}
content = content.replace(target2, replace2);
console.log('Target 2 replaced successfully.');

// 3. Replace _buildUstaPortfolioGrid and _buildUstaShortsGrid (lines 6952-7421) with _buildUstaUnifiedGrid
const target3Start = '  /// Gördüyüm İşlər (Portfolio) — 3 sütunlu fotoşəkillər şəbəkəsi (yeni dizayn)\n  Widget _buildUstaPortfolioGrid(';
const target3End = '    );\n  }\n}';

const idxStart = content.indexOf(target3Start);
if (idxStart === -1) {
  console.error('Target 3 start not found!');
  process.exit(1);
}
const idxEnd = content.indexOf(target3End, idxStart);
if (idxEnd === -1) {
  console.error('Target 3 end not found!');
  process.exit(1);
}

const replace3 = `  /// Vahid Qalereya (Foto və Videolar birgə, İnstagram üslubunda)
  Widget _buildUstaUnifiedGrid(String uid, String authorName, String role) {
    // Köhnə test fotoşəkillərini Firestore-dan təmizləyirik (istifadəçi tələbi)
    FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get()
        .then((snap) {
      for (final doc in snap.docs) {
        doc.reference.delete();
      }
    }).catchError((_) {});

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shorts')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, shortSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, postSnap) {
            final shortDocs = shortSnap.data?.docs ?? [];
            final postDocs = postSnap.data?.docs ?? [];

            // Bütün elementləri vahid siyahıda birləşdiririk
            final List<_UnifiedGridItem> allItems = [];

            for (final doc in shortDocs) {
              allItems.add(_UnifiedGridItem(
                id: doc.id,
                isVideo: true,
                data: doc.data(),
                createdAt: doc.data()['createdAt'],
              ));
            }

            for (final doc in postDocs) {
              final data = doc.data();
              final isVid = data['isVideo'] == true ||
                  (data['videoUrl'] != null && data['videoUrl'].toString().trim().isNotEmpty);
              allItems.add(_UnifiedGridItem(
                id: doc.id,
                isVideo: isVid,
                data: data,
                createdAt: data['createdAt'],
              ));
            }

            // Tarixə görə sıralayırıq (ən yeni birinci)
            allItems.sort((a, b) {
              final ta = a.createdAt;
              final tb = b.createdAt;
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });

            // Əgər hələ heç bir foto və ya video yoxdursa → İnstagram "Başlarkən" kartı (Şəkil 1)
            if (allItems.isEmpty) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Başlarkən',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Dairəvi kamera ikonu outline
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1E293B), width: 1.8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 38,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Fotoğraflar Paylaş',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Paylaştığın fotoğraflar profilinde gözükür.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 220,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _showTikTokSyncDialog(context),
                              child: const Text(
                                'TikTok Hesabını Bağla',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Grid dolu olduqda: 3 sütunlu kvadrat şəbəkə
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '\${allItems.length} paylaşım',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showTikTokSyncDialog(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'TikTok Sinxron',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final data = item.data;
                      final isVideo = item.isVideo;

                      if (isVideo) {
                        final videoUrl = (data['videoUrl'] ?? '').toString();
                        final coverBase64 = data['thumbnailBase64']?.toString();
                        final isTikTok = data['isTikTok'] == true || videoUrl.contains('tiktok.com');

                        return InkWell(
                          onTap: () async {
                            if (videoUrl.isNotEmpty) {
                              _ShortsVideoThumbnail.pauseAndReleaseAll();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenVideoViewer(
                                    videoUrl: videoUrl,
                                    title: data['title'] ?? 'Usta İşi',
                                    category: data['trade'] ?? 'Shorts',
                                    postId: item.id,
                                    coverBase64: coverBase64,
                                    isOwner: true,
                                  ),
                                ),
                              );
                              _ShortsVideoThumbnail.resumeAll();
                            }
                          },
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_HomeScreenState._decodeB64(coverBase64) != null)
                                  Image.memory(
                                    _HomeScreenState._decodeB64(coverBase64)!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                else if (data['thumbnailUrl'] != null && (data['thumbnailUrl'] as String).isNotEmpty && !(data['thumbnailUrl'] as String).contains('unsplash.com'))
                                  Image.network(
                                    data['thumbnailUrl'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                else if (videoUrl.isNotEmpty && index < 6)
                                  _ShortsVideoThumbnail(
                                    key: ValueKey('short_thumb_\${item.id}'),
                                    videoUrl: videoUrl,
                                    shortDocId: item.id,
                                    collectionName: 'shorts',
                                    ownerId: (data['userId'] ?? '').toString(),
                                    fallback: const SizedBox.shrink(),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.35),
                                      ],
                                    ),
                                  ),
                                ),
                                // Instagram Video / Reel Badge (yuxarı sağda)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                                if (isTikTok)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFE2C55), width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.music_note, color: Color(0xFFFE2C55), size: 10),
                                          SizedBox(width: 3),
                                          Text('TikTok', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Foto
                        String? base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
                        if ((base64Img == null || base64Img.isEmpty) && data['imagesBase64'] is List && (data['imagesBase64'] as List).isNotEmpty) {
                          base64Img = (data['imagesBase64'] as List).first.toString();
                        }
                        final bool hasImage = (base64Img != null && base64Img.isNotEmpty) ||
                            (data['thumbnailUrl']?.toString().isNotEmpty == true &&
                                !data['thumbnailUrl'].toString().contains('unsplash.com'));

                        return GestureDetector(
                          onTap: hasImage ? () => _showPostDetailModal(item.id, data) : null,
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: Builder(
                              builder: (context) {
                                final pBytes = _decodeB64(base64Img);
                                if (pBytes != null) {
                                  return Image.memory(pBytes, fit: BoxFit.cover, gaplessPlayback: true);
                                }
                                final thumbUrl = data['thumbnailUrl']?.toString();
                                if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                                  return Image.network(thumbUrl, fit: BoxFit.cover);
                                }
                                return const Center(
                                  child: Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 28),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Vahid Qalereya üçün element modeli
class _UnifiedGridItem {
  final String id;
  final bool isVideo;
  final Map<String, dynamic> data;
  final dynamic createdAt;

  _UnifiedGridItem({
    required this.id,
    required this.isVideo,
    required this.data,
    required this.createdAt,
  });
}`;

content = content.slice(0, idxStart) + replace3 + content.slice(idxEnd + target3End.length);
console.log('Target 3 replaced successfully.');

if (isCRLF) {
  content = content.replace(/\n/g, '\r\n');
}

fs.writeFileSync(filePath, content, 'utf8');
console.log('File saved successfully.');
