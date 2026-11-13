import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../services/video_upload_service.dart';
import '../services/category_city_service.dart';
import '../services/shorts_social_service.dart';

class ShortsScreen extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onNavigateTab;
  final String? targetUserId;
  final Future<void> Function(Map<String, dynamic> artisanData)? onOpenArtisanProfile;
  const ShortsScreen({super.key, this.initialIndex = 0, this.onNavigateTab, this.targetUserId, this.onOpenArtisanProfile});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initializing = {};
  bool _muted = false;
  List<Map<String, dynamic>> _latestItems = []; // Qalereya sonrası reaktivasiya üçün

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _prepareVideo(int index, List<Map<String, dynamic>> items) async {
    if (index < 0 || index >= items.length) return;

    if (_controllers.containsKey(index)) {
      final existing = _initializing[index];
      if (existing != null) await existing;
      return;
    }

    final url = items[index]['videoUrl']?.toString().trim() ?? '';
    if (url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;

    final future = () async {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1.0);
    }();

    _initializing[index] = future;

    try {
      await future;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Video preload xətası (index $index): $error');
      _controllers.remove(index);
      try {
        await controller.dispose();
      } catch (_) {}
    } finally {
      _initializing.remove(index);
    }
  }

  Future<void> _activateVideo(int index, List<Map<String, dynamic>> items) async {
    if (index < 0 || index >= items.length) return;

    _currentIndex = index;
    if (mounted) setState(() {});

    // 1. Digər bütün videoları dayandırırıq və başa çəkirik
    for (final entry in _controllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        try {
          await entry.value.pause();
          await entry.value.seekTo(Duration.zero);
        } catch (_) {}
      }
    }

    // 2. Cari videonu hazırlayırıq
    await _prepareVideo(index, items);

    if (!mounted || _currentIndex != index) return;

    final controller = _controllers[index];
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setVolume(_muted ? 0 : 1.0);
        await controller.seekTo(Duration.zero);
        await controller.play();
      } catch (_) {}
    }

    // 3. Növbəti videonu arxada səssizcə hazırlayırıq (TikTok preloading)
    if (index + 1 < items.length) {
      _prepareVideo(index + 1, items);
    }
    if (index - 1 >= 0) {
      _prepareVideo(index - 1, items);
    }

    // 4. Cari videodan 1 addımdan çox uzaqda olan köhnə videoları silirik (RAM qorunur)
    final oldIndexes = _controllers.keys
        .where((i) => (i - index).abs() > 1)
        .toList();

    for (final oldIndex in oldIndexes) {
      final oldController = _controllers.remove(oldIndex);
      if (oldController != null) {
        try {
          await oldController.dispose();
        } catch (_) {}
      }
    }
  }

  void _onPageChanged(int index, List<Map<String, dynamic>> items) {
    _activateVideo(index, items);
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized) {
        try {
          await controller.setVolume(_muted ? 0 : 1.0);
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
  }

  // Nümayiş üçün nümunə usta videoları
  final List<Map<String, dynamic>> _sampleShorts = [
    {
      'title': 'Kafel-metlax işinin incəlikləri 🔥',
      'artisanName': 'Rəşad Usta',
      'trade': 'Santexnik / Kafel ustası',
      'phone': '+994 50 123 45 67',
      'likes': '1.2K',
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-hands-of-a-carpenter-measuring-a-piece-of-wood-41006-large.mp4',
    },
    {
      'title': 'Elektrik şitinin düzgün yığılması ⚡',
      'artisanName': 'Tural Usta',
      'trade': 'Elektrik ustası',
      'phone': '+994 55 987 65 43',
      'likes': '950',
      'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-worker-welding-a-metal-part-in-a-workshop-41009-large.mp4',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      try {
        controller.pause();
        controller.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    _initializing.clear();
    super.dispose();
  }

  /// Qalereya açılmadan əvvəl BÜTÜN controller-ları dispose edir.
  /// Bu Android LMK (Low Memory Killer) crash-ını önləyir:
  /// video decoder-lar + GPU teksturaları çoxlu RAM tutur,
  /// Android bu yükü görüb Flutter prosesini kill edir.
  Future<void> _disposeAllControllers() async {
    final toDispose = _controllers.values.toList();
    _controllers.clear();
    _initializing.clear();
    for (final c in toDispose) {
      try {
        await c.pause();
        await c.dispose();
      } catch (_) {}
    }
  }

  /// Qalereya bağlandıqdan sonra cari videonu yenidən aktivləşdirir.
  /// [items] parametri Firestore-dan gələn video siyahısıdır.
  /// Bu metod yalnız `_items` dəyişəninə ehtiyac duyduğu üçün
  /// stream-dən keçən sonuncu `items`-ı saxlayan `_latestItems` istifadə olunur.
  void _reactivateAfterGallery() {
    if (!mounted) return;
    if (_latestItems.isNotEmpty) {
      _activateVideo(_currentIndex, _latestItems);
    }
  }

  /// Şəkili Firestore 1MB limitinə uyğun sıxışdırır (maks ~700KB)
  Future<Uint8List> _compressCoverImage(Uint8List bytes) async {
    // Thumbnail çox kiçik saxlanılmalıdır (max 150px genişlik, JPEG kimi)
    // ki sürətli yüklənsin
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      // RGBA raw bytes → PNG (flutter web-də rawRgba, digərlərində png)
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd != null) {
        // PNG artıq kiçikdir, istifadə edirik
        final compressed = bd.buffer.asUint8List();
        // Yalnız kiçilib-kiçilmədiyini yoxlayırıq
        return compressed.length < bytes.length ? compressed : bytes;
      }
    } catch (e) {
      debugPrint('Cover compress error: $e');
    }
    return bytes;
  }

  // Yeni Video / Shorts əlavə etmək pəncərəsi
  Future<void> _showUploadShortDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    final phoneController = TextEditingController();
    final tradeController = TextEditingController(text: 'Peşəkar Usta');

    XFile? pickedVideo;
    Uint8List? pickedVideoBytes;
    XFile? pickedCover;
    Uint8List? pickedCoverBytes;
    bool isUploading = false;
    double uploadProgress = 0.0;
    String uploadStatus = '0%';

    // İstifadəçinin telefonunu gətirməyə çalışırıq
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          phoneController.text = doc.data()?['phone'] ?? '';
          final role = doc.data()?['role'];
          if (role == 'usta') tradeController.text = 'Usta';
          if (role == 'seller') tradeController.text = 'Satıcı / Mağaza';
        }
      } catch (_) {}
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.video_library_rounded, color: Color(0xFF1769D2), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Shorts Video Əlavə Et',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gördüyünüz işin videosunu paylaşaraq müştərilərə canlı nümayiş etdirin.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Video seçimi (Fayl və ya Link)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      if (pickedVideo != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Video seçildi: ${pickedVideo!.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                setModalState(() {
                                  pickedVideo = null;
                                  pickedVideoBytes = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1769D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.video_file_outlined),
                          label: const Text('Qalereyadan Video Seç'),
                          onPressed: () async {
                            try {
                              // KRİTİK: Qalereya açılmadan BÜTÜN video controller-ları dispose edirik.
                              // Sadəcə pause etmək kifayət deyil — video decoder-lar + GPU teksturaları
                              // RAM-da qalır (100-300MB). Android LMK bu yükü görüb Flutter prosesini
                              // kill edir → istifadəçiyə "tətbiq bağlandı" kimi görünür.
                              await _disposeAllControllers();

                              final picker = ImagePicker();
                              XFile? video;
                              try {
                                video = await picker.pickVideo(
                                  source: ImageSource.gallery,
                                  maxDuration: const Duration(minutes: 5),
                                );
                              } catch (e) {
                                debugPrint('pickVideo xətası: $e');
                                // Qalereya bağlandıqdan sonra cari videonu yenidən başladırıq
                                _reactivateAfterGallery();
                                if (ctx.mounted) {
                                  setModalState(() {});
                                }
                                return;
                              }

                              // Qalereya bağlandı — cari videonu yenidən aktivləşdir
                              _reactivateAfterGallery();

                              if (video == null) {
                                // İstifadəçi seçim etmədi — normal hal
                                return;
                              }

                              // Fayl ölçüsünü yoxlayırıq (content:// URI üçün try-catch)
                              int length = 0;
                              try {
                                length = await video.length();
                              } catch (e) {
                                debugPrint('video.length() xətası (content URI?): $e');
                                // Ölçü oxuna bilmirsə, birbaşa qəbul edirik — upload zamanı yoxlanacaq
                              }

                              if (length > 150 * 1024 * 1024) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Video həcmi 150MB-dan çox olmamalıdır!')),
                                  );
                                }
                                return;
                              }

                              // ctx.mounted yoxlaması — dialog bağlanıbsa setModalState çağırılmır
                              if (ctx.mounted) {
                                setModalState(() {
                                  pickedVideo = video;
                                  pickedVideoBytes = null;
                                });
                              }
                            } catch (e) {
                              debugPrint('Video pick error: $e');
                              _reactivateAfterGallery();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Qalereyadan seçim zamanı xəta: $e')),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text('və ya', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: linkController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Video linki daxil edin (MP4, YouTube və s.)',
                            prefixIcon: Icon(Icons.link, size: 20),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Videonun Üz Qabığı Şəkli (Thumbnail / Başlıq fotosu)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: pickedCoverBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(pickedCoverBytes!, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.video_library_rounded, color: Color(0xFF1769D2)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pickedCoverBytes != null ? 'Xüsusi şəkil seçildi' : 'Başlıq Şəkli (Kover)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                if (pickedCoverBytes == null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Videonun öz kadrı', style: TextStyle(color: Color(0xFF1769D2), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            Text(
                              pickedCoverBytes != null
                                  ? pickedCover!.name
                                  : 'Videonun öz daxilindən avtomatik kadr çıxarılır',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            // Şəkil seçimi üçün controller-ları dispose etmək lazım deyil
                            // (şəkil picker çox az RAM istifadə edir), sadəcə pause edirik
                            for (var c in _controllers.values.toList()) {
                              try { c.pause(); } catch (_) {}
                            }
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                            if (img != null) {
                              final rawBytes = await img.readAsBytes();
                              // Firestore 1MB limit üçün şəkli sıxışdırırıq
                              final compressed = await _compressCoverImage(rawBytes);
                              if (ctx.mounted) {
                                setModalState(() {
                                  pickedCover = img;
                                  pickedCoverBytes = compressed;
                                });
                              }
                            }
                          } catch (e) {
                            debugPrint('Cover pick error: $e');
                          }
                        },
                        child: Text(pickedCoverBytes != null ? 'Dəyiş' : 'Seç'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Video haqqında qısa başlıq *',
                    hintText: 'Məsələn: Yasamalda kafel-metlax işi',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tradeController,
                        decoration: const InputDecoration(
                          labelText: 'Peşə / İxtisas',
                          prefixIcon: Icon(Icons.handyman_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Əlaqə nömrəsi *',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (isUploading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: uploadProgress > 0 ? uploadProgress : null,
                            minHeight: 10,
                            backgroundColor: Colors.blue.shade100,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1769D2)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Video Yüklənir: $uploadStatus',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1769D2)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Zəhmət olmasa gözləyin, video buluda yüklənir...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final link = linkController.text.trim();
                        final phone = phoneController.text.trim();

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zəhmət olmasa video başlığını yazın!')),
                          );
                          return;
                        }

                        if (pickedVideo == null && link.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zəhmət olmasa video seçin və ya link daxil edin!')),
                          );
                          return;
                        }

                        setModalState(() {
                          isUploading = true;
                          uploadStatus = 'Video hazırlanır...';
                        });

                        String finalVideoUrl = link;

                        // Əgər telefonun qalereyasından video seçilibsə, pulsuz bulud bazasına yükləyirik
                        if (pickedVideo != null) {
                          try {
                            setModalState(() {
                              uploadStatus = 'Video faylı oxunur...';
                              uploadProgress = 0.05;
                            });

                            // RAM-ın kəskin sıçrayışının qarşısını almaq üçün köhnə kontrollerləri dayandırırıq
                            for (var c in _controllers.values.toList()) {
                              try {
                                c.pause();
                              } catch (_) {}
                            }

                            // STREAMING UPLOAD: readAsBytes() çağırılmır, birbaşa fayl yolu ötürülür!
                            setModalState(() {
                              uploadStatus = 'Cloudflare R2-yə yüklənir...';
                              uploadProgress = 0.15;
                            });

                            final uploadedUrl = await VideoUploadService.uploadVideo(
                              filePath: pickedVideo!.path,
                              fileName: pickedVideo!.name,
                              onProgress: (p) {
                                // ctx.mounted yoxlaması: əgər dialog bağlanıbsa setModalState çağırılmır
                                // Bu olmasa dialog ctx-i ölmüş context-də setState çağırır → crash
                                if (ctx.mounted) {
                                  setModalState(() {
                                    uploadProgress = p;
                                    uploadStatus = '${(p * 100).toStringAsFixed(0)}%';
                                  });
                                }
                              },
                            );

                            finalVideoUrl = uploadedUrl;
                          } catch (e) {
                            debugPrint('Video upload error: $e');
                            if (ctx.mounted) {
                              setModalState(() => isUploading = false);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Video yükləmə xətası: $e\nZəhmət olmasa internet bağlantısını yoxlayın və ya video linki daxil edin.'),
                                  backgroundColor: Colors.orange.shade900,
                                  duration: const Duration(seconds: 7),
                                ),
                              );
                            }
                            return;
                          }
                        }

                        try {
                          String authorName = user?.displayName ?? 'UstaGo Ustası';
                          final uid = user?.uid ?? 'guest';
                          final tradeVal = tradeController.text.trim().isEmpty ? 'Tikinti' : tradeController.text.trim();
                          String authorPhone = phone.isEmpty ? '+994 50 000 00 00' : phone;

                          String? uPhoto;
                          if (user != null) {
                            try {
                              final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              if (uDoc.exists) {
                                final uData = uDoc.data();
                                uPhoto = uData?['photoBase64'];
                                final fn = uData?['fullName']?.toString().trim();
                                if (fn != null && fn.isNotEmpty) authorName = fn;
                                final ph = uData?['phone']?.toString().trim();
                                if (ph != null && ph.isNotEmpty) authorPhone = ph;
                              }
                            } catch (_) {}
                          }

                          final String coverBase64 = pickedCoverBytes != null ? base64Encode(pickedCoverBytes!) : '';

                          // 1. Shorts kolleksiyasına yazırıq
                          await FirebaseFirestore.instance.collection('shorts').add({
                            'userId': uid,
                            'title': title,
                            'videoUrl': finalVideoUrl,
                            'thumbnailBase64': coverBase64,
                            'thumbnailUrl': '',
                            'authorPhotoBase64': uPhoto ?? '',
                            'artisanName': authorName,
                            'trade': tradeVal,
                            'phone': authorPhone,
                            'likes': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          // 2. İstifadəçinin profil qalereyasına (posts) da video kimi əlavə edirik
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('posts').add({
                              'userId': uid,
                              'authorName': authorName,
                              'phone': authorPhone,
                              'authorRole': 'usta',
                              'title': title,
                              'category': tradeVal,
                              'videoUrl': finalVideoUrl,
                              'imageBase64': coverBase64,
                              'thumbnailBase64': coverBase64,
                              'thumbnailUrl': '',
                              'isVideo': true,
                              'createdAt': FieldValue.serverTimestamp(),
                              'likes': 0,
                            });
                          }

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Shorts videonuz uğurla paylaşıldı! 🎉'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isUploading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Videonu Paylaş',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: (widget.targetUserId != null && widget.targetUserId!.isNotEmpty)
                ? FirebaseFirestore.instance
                    .collection('shorts')
                    .where('userId', isEqualTo: widget.targetUserId)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('shorts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              final List<Map<String, dynamic>> items = [];
              if (docs.isNotEmpty) {
                for (var d in docs) {
                  final data = d.data();
                  items.add({
                    'id': d.id,
                    'userId': data['userId'] ?? '',
                    'title': data['title'] ?? 'Usta İşi',
                    'artisanName': data['artisanName'] ?? 'Usta',
                    'trade': data['trade'] ?? 'Usta',
                    'phone': data['phone'] ?? '',
                    'likes': (data['likes'] ?? 0).toString(),
                    'likedBy': data['likedBy'],
                    'videoUrl': data['videoUrl'] ?? '',
                    'authorPhotoBase64': data['authorPhotoBase64'],
                    'thumbnailBase64': data['thumbnailBase64'],
                    'thumbnailUrl': data['thumbnailUrl'],
                  });
                }
              }
              // Yalnız ümumi lentdə nümunə videoları göstəririk (fərdi usta profilində sample göstərilmir)
              if (items.isEmpty && snapshot.connectionState != ConnectionState.waiting && widget.targetUserId == null) {
                items.addAll(_sampleShorts);
              }

              // İlkin açılışda cari videonu dərhal aktivləşdiririk (TikTok axıcılığı)
              if (items.isNotEmpty) {
                _latestItems = items; // Qalereya sonrası reaktivasiya üçün saxlayırıq
              }
              if (items.isNotEmpty && _controllers.isEmpty && _initializing.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _controllers.isEmpty && _initializing.isEmpty) {
                    _activateVideo(_currentIndex, items);
                  }
                });
              }

              final bool hasNavShortcut = Navigator.canPop(context) && widget.onNavigateTab == null;
              final double bottomNavHeight = hasNavShortcut ? 52.0 : 0.0;

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                onPageChanged: (idx) => _onPageChanged(idx, items),
                itemBuilder: (context, index) {
                  final bool isCurrent = index == _currentIndex;
                  return _ShortVideoItem(
                    key: ValueKey(items[index]['id'] ?? index),
                    data: items[index],
                    controller: _controllers[index],
                    isCurrent: isCurrent,
                    muted: _muted,
                    onToggleMute: _toggleMute,
                    bottomInset: bottomNavHeight,
                    onNavigateTab: widget.onNavigateTab,
                    onOpenArtisanProfile: widget.onOpenArtisanProfile,
                  );
                },
              );
            },
          ),

          // Yuxarı Başlıq və "Shorts Əlavə Et" Düyməsi
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.bolt, color: Colors.amber, size: 20),
                            SizedBox(width: 4),
                            Text(
                              'UstaGo Shorts',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Video Əlavə Et', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: _showUploadShortDialog,
                  ),
                ],
              ),
            ),
          ),

          // Əgər ayrıca səhifə kimi açılıbsa (Navigator.push), ana menyu burada da göstərilir
          if (Navigator.canPop(context) && widget.onNavigateTab == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavShortcut(Icons.home_outlined, 'Ana səhifə', () {
                          Navigator.pop(context);
                        }),
                        _buildNavShortcut(Icons.play_circle_fill, 'Shorts', null, isActive: true),
                        _buildNavShortcut(Icons.storefront_outlined, 'Alış-Satış', () {
                          Navigator.pop(context, 2);
                        }),
                        _buildNavShortcut(Icons.chat_bubble_outline, 'Mesajlar', () {
                          Navigator.pop(context, 3);
                        }),
                        _buildNavShortcut(Icons.person_outline, 'Profil', () {
                          Navigator.pop(context, 4);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavShortcut(IconData icon, String label, VoidCallback? onTap, {bool isActive = false}) {
    final color = isActive ? Colors.white : Colors.white60;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _ShortVideoItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final VideoPlayerController? controller;
  final bool isCurrent;
  final bool muted;
  final VoidCallback? onToggleMute;
  final VoidCallback? onRetry;
  final double bottomInset;
  final ValueChanged<int>? onNavigateTab;
  final Future<void> Function(Map<String, dynamic> artisanData)? onOpenArtisanProfile;

  const _ShortVideoItem({
    super.key,
    required this.data,
    this.controller,
    this.isCurrent = true,
    this.muted = false,
    this.onToggleMute,
    this.onRetry,
    this.bottomInset = 0.0,
    this.onNavigateTab,
    this.onOpenArtisanProfile,
  });

  @override
  State<_ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<_ShortVideoItem> {
  bool _isPlaying = true;
  bool _isMuted = false;

  int _likeCount = 0;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  int _commentsCount = 0;
  bool _showHeartAnimation = false;
  Offset _heartAnimPosition = Offset.zero;

  String? _authorPhotoBase64;
  String? _authorPhotoUrl;
  String? _authorName;
  String? _authorTrade;
  String? _authorPhone;

  @override
  void initState() {
    super.initState();
    _likeCount = int.tryParse(widget.data['likes']?.toString() ?? '0') ?? 0;
    _commentsCount = int.tryParse(widget.data['commentsCount']?.toString() ?? '0') ?? 0;
    _authorName = widget.data['artisanName'];
    _authorTrade = widget.data['trade'];
    _authorPhone = widget.data['phone'];
    _checkSocialStates();
    _loadAuthorData();
    _attachListener(widget.controller);
    if (widget.isCurrent && widget.controller != null && widget.controller!.value.isInitialized) {
      widget.controller!.play();
      _isPlaying = true;
    }
  }

  void _checkSocialStates() async {
    final shortId = widget.data['id']?.toString() ?? '';
    final authorUid = widget.data['userId']?.toString() ?? '';

    // 1. Like yoxlanışı (həm likedBy massivi, həm likes alt-kolleksiyası)
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final likedBy = widget.data['likedBy'];
    if (uid != null && likedBy is List && likedBy.contains(uid)) {
      if (mounted) setState(() => _isLiked = true);
    } else if (shortId.isNotEmpty) {
      final isLikedSub = await ShortsSocialService.isVideoLiked(shortId);
      if (mounted && isLikedSub) setState(() => _isLiked = true);
    }

    // 2. Save (Seçilmişlər) yoxlanışı
    if (shortId.isNotEmpty) {
      final isSaved = await ShortsSocialService.isVideoSaved(shortId);
      if (mounted) setState(() => _isSaved = isSaved);
    }

    // 3. Follow (İzləmə) yoxlanışı
    if (authorUid.isNotEmpty && authorUid != 'guest') {
      final isFollow = await ShortsSocialService.isArtisanFollowed(authorUid);
      if (mounted) setState(() => _isFollowing = isFollow);
    }
  }

  @override
  void didUpdateWidget(covariant _ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachListener(oldWidget.controller);
      _attachListener(widget.controller);
    }
    if (widget.isCurrent && widget.controller != null && widget.controller!.value.isInitialized) {
      if (!widget.controller!.value.isPlaying) {
        widget.controller!.play();
      }
    } else if (!widget.isCurrent && widget.controller != null) {
      if (widget.controller!.value.isPlaying) {
        widget.controller!.pause();
      }
    }
  }

  void _attachListener(VideoPlayerController? c) {
    if (c == null) return;
    c.addListener(_videoListener);
  }

  void _detachListener(VideoPlayerController? c) {
    if (c == null) return;
    c.removeListener(_videoListener);
  }

  void _videoListener() {
    if (!mounted) return;
    final isPlaying = widget.controller?.value.isPlaying ?? false;
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }
  }

  @override
  void dispose() {
    _detachListener(widget.controller);
    super.dispose();
  }

  void _loadAuthorData() async {
    final photo = widget.data['authorPhotoBase64'] ?? widget.data['photoBase64'];
    if (photo != null && photo.toString().isNotEmpty) {
      if (mounted) setState(() => _authorPhotoBase64 = photo.toString());
    }
    final uid = widget.data['userId']?.toString() ?? '';
    if (uid.isNotEmpty && uid != 'guest') {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              if (data['photoBase64'] != null && data['photoBase64'].toString().isNotEmpty) {
                _authorPhotoBase64 = data['photoBase64'];
              }
              if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
                _authorPhotoUrl = data['photoUrl'];
              }
              final fn = data['fullName']?.toString().trim();
              if (fn != null && fn.isNotEmpty) {
                _authorName = fn;
              }
              final cat = data['category']?.toString().trim();
              if (cat != null && cat.isNotEmpty) {
                _authorTrade = cat;
              }
              final ph = data['phone']?.toString().trim();
              if (ph != null && ph.isNotEmpty) {
                _authorPhone = ph;
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _openArtisanProfile() async {
    final uid = widget.data['userId']?.toString() ?? '';
    final curUser = FirebaseAuth.instance.currentUser;

    // Əgər videonun sahibi hal-hazırda daxil olmuş istifadəçinin özüdürsə,
    // başqa istifadəçi kimi yox, birbaşa tətbiqin əsas Öz Profilinə yönləndiririk!
    if (curUser != null && uid.isNotEmpty && curUser.uid == uid) {
      if (mounted) {
        final wasPlaying = widget.controller?.value.isPlaying ?? false;
        if (wasPlaying) {
          widget.controller?.pause();
          setState(() => _isPlaying = false);
        }

        // Əgər onNavigateTab callback varsa onu çağırırıq
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(4);
          return;
        }

        // Navigator.push ilə açılmışsa, 4 dəyəri ilə geri dönürük (HomeScreen tab keçidi üçün)
        if (Navigator.canPop(context)) {
          Navigator.pop(context, 4);
          return;
        }
      }
    }

    final curName = _authorName ?? widget.data['artisanName'] ?? 'Usta';
    final curTrade = _authorTrade ?? widget.data['trade'] ?? 'Usta';
    final curPhone = _authorPhone ?? widget.data['phone'] ?? '';
    Map<String, dynamic> artisanMap = {
      'id': uid,
      'uid': uid,
      'fullName': curName,
      'category': curTrade,
      'phone': curPhone,
      'photoBase64': _authorPhotoBase64 ?? widget.data['authorPhotoBase64'],
      'photoUrl': _authorPhotoUrl ?? widget.data['photoUrl'],
      'videoUrl': widget.data['videoUrl'],
      'rating': 4.9,
      'reviewsCount': 10,
      'city': 'Bakı',
    };

    if (uid.isNotEmpty && uid != 'guest') {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          artisanMap = Map<String, dynamic>.from(doc.data()!);
          artisanMap['id'] = doc.id;
          artisanMap['uid'] = doc.id;
        }
      } catch (_) {}
    }

    if (mounted) {
      final wasPlaying = widget.controller?.value.isPlaying ?? false;
      if (wasPlaying) {
        widget.controller?.pause();
        setState(() => _isPlaying = false);
      }

      if (widget.onOpenArtisanProfile != null) {
        await widget.onOpenArtisanProfile!(artisanMap);
      }

      // Profil səhifəsindən geri qayıdanda videonu yenidən davam etdiririk
      if (mounted && widget.isCurrent && widget.controller != null && widget.controller!.value.isInitialized) {
        widget.controller?.play();
        setState(() => _isPlaying = true);
      }
    }
  }

  Future<void> _toggleLike({bool forceLike = false, Offset? tapPos}) async {
    final docId = widget.data['id']?.toString() ?? '';
    if (docId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bəyənmək üçün zəhmət olmasa daxil olun.'),
          backgroundColor: Color(0xFF1769D2),
        ),
      );
      return;
    }

    if (forceLike && _isLiked) {
      // Artıq bəyənilibsə, double-tap zamanı sadəcə ürək animasiyasını göstər
      _triggerHeartAnimation(tapPos);
      return;
    }

    // Əgər ikiqat toxunuşdursa (double-tap), animasiyanı işə sal
    if (forceLike || !_isLiked) {
      _triggerHeartAnimation(tapPos);
    }

    // Optimistic UI yenilənməsi
    final bool newLikedState = forceLike ? true : !_isLiked;
    if (_isLiked == newLikedState) return;

    setState(() {
      _isLiked = newLikedState;
      if (_isLiked) {
        _likeCount++;
      } else {
        if (_likeCount > 0) _likeCount--;
      }
    });

    try {
      await ShortsSocialService.toggleLikeVideo(docId);
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  void _triggerHeartAnimation(Offset? tapPos) {
    if (mounted) {
      setState(() {
        _heartAnimPosition = tapPos ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
        _showHeartAnimation = true;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showHeartAnimation = false);
      });
    }
  }

  Future<void> _toggleFollow() async {
    final authorUid = widget.data['userId']?.toString() ?? '';
    if (authorUid.isEmpty || authorUid == 'guest') return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ustanı izləmək üçün daxil olun.'),
          backgroundColor: Color(0xFF1769D2),
        ),
      );
      return;
    }

    if (user.uid == authorUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öz profilinizi izləyə bilməzsiniz.')),
      );
      return;
    }

    final bool newFollow = !_isFollowing;
    setState(() => _isFollowing = newFollow);

    try {
      final res = await ShortsSocialService.toggleFollowArtisan(authorUid);
      if (mounted) setState(() => _isFollowing = res);
    } catch (e) {
      if (mounted) setState(() => _isFollowing = !newFollow);
      debugPrint('Follow error: $e');
    }
  }

  Future<void> _toggleSave() async {
    final docId = widget.data['id']?.toString() ?? '';
    if (docId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videonu yadda saxlamaq üçün daxil olun.'),
          backgroundColor: Color(0xFF1769D2),
        ),
      );
      return;
    }

    final bool newSaved = !_isSaved;
    setState(() => _isSaved = newSaved);

    try {
      final res = await ShortsSocialService.toggleSaveVideo(docId, widget.data);
      if (mounted) {
        setState(() => _isSaved = res);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res ? 'Video seçilmişlərə əlavə edildi!' : 'Video seçilmişlərdən silindi.'),
            duration: const Duration(seconds: 1),
            backgroundColor: res ? const Color(0xFF1769D2) : Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSaved = !newSaved);
      debugPrint('Save error: $e');
    }
  }

  Future<void> _shareVideo() async {
    final title = widget.data['title']?.toString() ?? '';
    final name = _authorName ?? widget.data['artisanName'] ?? 'Usta';
    final url = widget.data['videoUrl']?.toString();

    try {
      await ShortsSocialService.shareVideo(
        title: title,
        artisanName: name,
        videoUrl: url,
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _showMoreMenu() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwnerOrAdmin = currentUser != null &&
        ((widget.data['userId'] != null && currentUser.uid == widget.data['userId']) ||
         currentUser.email == 'mirze3838@gmail.com');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Color(0xFF1769D2)),
              title: const Text('Paylaş'),
              onTap: () {
                Navigator.pop(ctx);
                _shareVideo();
              },
            ),
            ListTile(
              leading: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.amber.shade800),
              title: Text(_isSaved ? 'Seçilmişlərdən çıxart' : 'Seçilmişlərə saxla'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleSave();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Şikayət et'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            if (isOwnerOrAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Videonu Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteVideo();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Videonu Şikayət Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu video UstaGo qaydalarını pozursa, səbəbini qeyd edin:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Şikayət səbəbini yazın...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İmtina')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final docId = widget.data['id']?.toString() ?? '';
              await ShortsSocialService.reportVideo(shortId: docId, reason: reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şikayətiniz baxılması üçün qeydə alındı.'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Göndər'),
          ),
        ],
      ),
    );
  }

  void _showCommentsModal(String docId) {
    if (docId.isEmpty) return;
    final commentController = TextEditingController();
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.70,
            child: Column(
              children: [
                // Başlıq və Say
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Rəylər',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('shorts').doc(docId).collection('comments').snapshots(),
                            builder: (context, snap) {
                              final count = snap.data?.docs.length ?? _commentsCount;
                              return Text(
                                '($count)',
                                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal),
                              );
                            },
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Rəylər siyahısı
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shorts')
                        .doc(docId)
                        .collection('comments')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data?.docs ?? [];
                      if (comments.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Hələ ki rəy yazılmayıb', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              Text('İlk rəyi siz yazın! ✍️', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final cDoc = comments[index];
                          final cData = cDoc.data();
                          final String author = cData['userName'] ?? 'İstifadəçi';
                          final String text = cData['text'] ?? '';
                          final String? photoBase64 = cData['userPhotoBase64'];
                          final String commentUserId = (cData['userId'] ?? '').toString();
                          final String videoOwnerId = (widget.data['userId'] ?? '').toString();
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                          final int commentLikes = int.tryParse(cData['likes']?.toString() ?? '0') ?? 0;

                          // Həm rəy yazan şəxs, həm də videosuna rəy yazılan şəxs (video sahibi) rəyi silə bilər!
                          final bool canDelete = currentUserId.isNotEmpty &&
                              (currentUserId == commentUserId || currentUserId == videoOwnerId);

                          ImageProvider? cAvatar;
                          if (photoBase64 != null && photoBase64.isNotEmpty) {
                            try {
                              cAvatar = MemoryImage(base64Decode(photoBase64));
                            } catch (_) {}
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF1769D2).withOpacity(0.1),
                                backgroundImage: cAvatar,
                                child: cAvatar == null
                                    ? const Icon(Icons.person, size: 18, color: Color(0xFF1769D2))
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          author,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                        ),
                                        if (commentUserId == videoOwnerId) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1769D2).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Müəllif',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      text,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                              // Şərh Bəyənmə və Silmə menyusu
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      if (currentUserId.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Bəyənmək üçün daxil olun')),
                                        );
                                        return;
                                      }
                                      await ShortsSocialService.toggleLikeComment(docId, cDoc.id);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                                          if (commentLikes > 0)
                                            Text(
                                              '$commentLikes',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (canDelete) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (delCtx) => AlertDialog(
                                            title: const Text('Rəyi Sil'),
                                            content: const Text('Bu rəyi silmək istədiyinizdən əminsiniz?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(delCtx, false), child: const Text('İmtina')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                onPressed: () => Navigator.pop(delCtx, true),
                                                child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await ShortsSocialService.deleteComment(docId, cDoc.id);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // Rəy daxil etmə sahəsi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Rəy bildirin...',
                              hintStyle: const TextStyle(fontSize: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: isPosting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: Color(0xFF1769D2)),
                          onPressed: isPosting
                              ? null
                              : () async {
                                  final text = commentController.text.trim();
                                  if (text.isEmpty) return;

                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Rəy yazmaq üçün daxil olun.')),
                                    );
                                    return;
                                  }

                                  setModalState(() => isPosting = true);

                                  String userName = user.displayName ?? 'İstifadəçi';
                                  String? userPhoto;

                                  try {
                                    final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                    if (uDoc.exists) {
                                      userName = uDoc.data()?['fullName'] ?? userName;
                                      userPhoto = uDoc.data()?['photoBase64'];
                                    }
                                  } catch (_) {}

                                  try {
                                    await ShortsSocialService.addComment(
                                      shortId: docId,
                                      text: text,
                                      userName: userName,
                                      userPhotoBase64: userPhoto,
                                    );
                                    commentController.clear();
                                  } catch (e) {
                                    debugPrint('Rəy əlavə xətası: $e');
                                  } finally {
                                    setModalState(() => isPosting = false);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMute() async {
    final c = widget.controller;
    if (c == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    await c.setVolume(_isMuted ? 0 : 1.0);
  }

  /// Video player-in qaytardığı aspectRatio dəyərini düzəldir.
  /// video_player 2.9+ Android-də rotationCorrection (90/270°) olduqda
  /// c.value.aspectRatio-nu avtomatik swap etmir — bunu burada düzəldirik.
  double _correctAspectRatio(VideoPlayerController c) {
    final raw = c.value.aspectRatio;
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 9.0 / 16.0;

    // rotationCorrection 90 və ya 270 dərəcədirsə video əslində fırlanmışdır —
    // width/height swap olunmalıdır, buna görə nisbət tərsinə çevrilir.
    final int rot = c.value.rotationCorrection;
    if (rot == 90 || rot == 270) {
      return 1.0 / raw;
    }
    return raw;
  }

  void _togglePlay() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _isPlaying = false;
      } else {
        c.play();
        _isPlaying = true;
      }
    });
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = '994${clean.substring(1)}';
    final Uri uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDeleteVideo() async {
    final docId = widget.data['id'];
    if (docId == null || docId.toString().isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shorts Videosunu Sil'),
        content: const Text('Bu videonu silmək istədiyinizdən əminsiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Xeyr'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bəli, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ShortsSocialService.deleteShortVideoCompletely(docId.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video uğurla silindi!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silmə xətası: $e')),
          );
        }
      }
    }
  }

  Widget _buildCoverImage(Map<String, dynamic> data) {
    final String? thumbnailBase64 = data['thumbnailBase64'];
    final String? thumbnailUrl = data['thumbnailUrl'];
    final String trade = (data['trade'] ?? '').toString();

    final tr = trade.toLowerCase();
    List<Color> gColors = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
    IconData trIcon = Icons.handyman_rounded;
    if (tr.contains('santexnik') || tr.contains('su')) {
      gColors = const [Color(0xFF0284C7), Color(0xFF0369A1)];
      trIcon = Icons.water_drop_rounded;
    } else if (tr.contains('elektrik') || tr.contains('işıq')) {
      gColors = const [Color(0xFFD97706), Color(0xFFB45309)];
      trIcon = Icons.bolt_rounded;
    } else if (tr.contains('tikinti') || tr.contains('hörgü')) {
      gColors = const [Color(0xFFEA580C), Color(0xFFC2410C)];
      trIcon = Icons.foundation_rounded;
    } else if (tr.contains('mebel')) {
      gColors = const [Color(0xFF92400E), Color(0xFF78350F)];
      trIcon = Icons.chair_rounded;
    }

    // Video tam açılana qədər parlaq və estetik fon
    final fallbackWidget = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(trIcon, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
      try {
        return Center(
          child: Image.memory(
            base64Decode(thumbnailBase64),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => fallbackWidget,
          ),
        );
      } catch (_) {}
    }

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Center(
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackWidget;
          },
          errorBuilder: (_, __, ___) => fallbackWidget,
        ),
      );
    }

    return fallbackWidget;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final bool isReady = c != null && c.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      onDoubleTapDown: (details) {
        _toggleLike(forceLike: true, tapPos: details.globalPosition);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 0. VİDEO AÇILANA QƏDƏR ARXA FONDA BAŞLIQ FOTOSU
          if (!isReady)
            _buildCoverImage(widget.data),

          // 1. VİDEO EKRANI - Orijinal proporsiyada (heç bir dartılma, böyüdülmə və ya kəsilmə olmadan, qara boşluqlarla)
          if (isReady)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: AspectRatio(
                // ORIENTATION DÜZƏLİŞİ: Android-də kamera çəkdikləri videoların
                // rotation metadata-sı c.value.aspectRatio-ya düzgün əks etmir.
                // c.value.size.height > width olarsa video portrait-dir → nisbəti düzəldirik.
                aspectRatio: _correctAspectRatio(c),
                child: VideoPlayer(c),
              ),
            ),

          // Video buferlənərkən zərif balaca fırlanan çarx (yalnız video ifa olunmursa göstərilir)
          if (isReady && c.value.isBuffering && !c.value.isPlaying)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
              ),
            ),

          // Pause olduqda mərkəzdə Play ikonu
          if (!_isPlaying && isReady)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, size: 50, color: Colors.white),
              ),
            ),

          // İkiqat toxunuş zamanı TikTok tipli parlayan ürək animasiyası
          if (_showHeartAnimation)
            Positioned(
              left: _heartAnimPosition.dx - 45,
              top: _heartAnimPosition.dy - 45,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.2),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                      size: 90,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 10),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Qradiyent örtük
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
                begin: Alignment.center,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Web üçün Səsi Aç bildirişi
          if (isReady && _isMuted)
            Positioned(
              top: 50,
              right: 16,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.volume_off, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Səsi Aç', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // Sağ tərəfdəki TikTok tipli sosial düymələr
          Positioned(
            right: 10,
            bottom: widget.bottomInset + 30,
            child: Builder(
              builder: (context) {
                final currentUser = FirebaseAuth.instance.currentUser;
                final authorUid = widget.data['userId']?.toString() ?? '';
                final bool isOwner = currentUser != null && currentUser.uid == authorUid;

                ImageProvider? aAvatar;
                if (_authorPhotoBase64 != null && _authorPhotoBase64!.isNotEmpty) {
                  try {
                    aAvatar = MemoryImage(base64Decode(_authorPhotoBase64!));
                  } catch (_) {}
                } else if (_authorPhotoUrl != null && _authorPhotoUrl!.isNotEmpty) {
                  aAvatar = NetworkImage(_authorPhotoUrl!);
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Profil avatarı və üstəgəl (+) Follow düyməsi
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        GestureDetector(
                          onTap: _openArtisanProfile,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: aAvatar,
                              child: aAvatar == null
                                  ? const Icon(Icons.person, color: Color(0xFF1769D2), size: 24)
                                  : null,
                            ),
                          ),
                        ),
                        if (!isOwner && !_isFollowing && authorUid.isNotEmpty && authorUid != 'guest')
                          Positioned(
                            bottom: -7,
                            child: GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1769D2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black38, blurRadius: 4),
                                  ],
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Bəyənmə (Like / Unlike)
                    _buildSideAction(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      _likeCount > 0 ? '$_likeCount' : '',
                      _isLiked ? Colors.red : Colors.white,
                      onTap: () => _toggleLike(),
                    ),
                    const SizedBox(height: 10),

                    // 3. Rəylər (Comments)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('shorts')
                          .doc(widget.data['id']?.toString() ?? '')
                          .collection('comments')
                          .snapshots(),
                      builder: (context, snap) {
                        final cCount = snap.data?.docs.length ?? _commentsCount;
                        return _buildSideAction(
                          Icons.chat_bubble_rounded,
                          cCount > 0 ? '$cCount' : '',
                          Colors.white,
                          onTap: () => _showCommentsModal(widget.data['id']?.toString() ?? ''),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 4. Seçilmişlər (Save / Bookmark) - İkon əsaslı
                    _buildSideAction(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      '',
                      _isSaved ? Colors.amber : Colors.white,
                      onTap: _toggleSave,
                    ),
                    const SizedBox(height: 10),

                    // 5. Paylaş (Share) - İkon əsaslı
                    _buildSideAction(
                      Icons.share_rounded,
                      '',
                      Colors.white,
                      onTap: _shareVideo,
                    ),
                    const SizedBox(height: 10),

                    // 6. Səs (Mute/Unmute)
                    _buildSideAction(
                      (widget.muted || _isMuted) ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      '',
                      (widget.muted || _isMuted) ? Colors.amber : Colors.white,
                      onTap: () {
                        widget.onToggleMute?.call();
                        _toggleMute();
                      },
                    ),
                    const SizedBox(height: 10),

                    // 7. Əlavə Menyu (Üç nöqtə)
                    _buildSideAction(
                      Icons.more_horiz,
                      '',
                      Colors.white70,
                      onTap: _showMoreMenu,
                    ),
                  ],
                );
              },
            ),
          ),

          // Aşağı sol tərəfdəki usta məlumatı, Açıqlama və Hashtaglar
          // Menyunun və irəliləmə xəttinin kəskin şəkildə YUXARISINDA yerləşir (Toqquşma sıfırdır)
          Positioned(
            left: 16,
            right: 86,
            bottom: widget.bottomInset + 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openArtisanProfile,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${_authorName ?? widget.data['artisanName'] ?? 'UstaGo'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1769D2).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _authorTrade ?? widget.data['trade'] ?? 'Usta',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.data['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                // Hashtaglar
                Wrap(
                  spacing: 6,
                  children: [
                    Text(
                      '#${(_authorTrade ?? widget.data['trade'] ?? 'usta').toString().toLowerCase().replaceAll(' ', '')}',
                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      '#ustago #təmir #xidmət',
                      style: TextStyle(color: Color(0xFF64B5F6), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TikTok tipli Video Scrubber (İrəli/Geri çəkmə və Vaxt göstəricisi)
          // Aşağı menyunun düz üstündə, amma hashtagların tam altında, ayrıca səliqəli zolaqda yerləşir
          if (isReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
              child: SafeArea(
                top: false,
                bottom: widget.bottomInset == 0,
                child: _TikTokVideoScrubber(controller: c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideAction(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// TikTok tipli Video İrəli/Geri Çəkmə (Scrubber) və Vaxt Göstəricisi
class _TikTokVideoScrubber extends StatefulWidget {
  final VideoPlayerController controller;
  const _TikTokVideoScrubber({required this.controller});

  @override
  State<_TikTokVideoScrubber> createState() => _TikTokVideoScrubberState();
}

class _TikTokVideoScrubberState extends State<_TikTokVideoScrubber> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(covariant _TikTokVideoScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted || _isDragging) return;
    setState(() {});
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    if (duration == Duration.zero) return const SizedBox.shrink();

    final position = _isDragging
        ? duration * _dragValue
        : widget.controller.value.position;

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag edəndə mərkəzdə görünən böyük vaxt göstəricisi (TikTok kimi)
        if (_isDragging)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Text(
              '${_formatTime(position)} / ${_formatTime(duration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

        // İrəli/Geri çəkmə zolağı (Interactive Slider)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
            });
            widget.controller.pause();
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localX = details.localPosition.dx;
              final width = box.size.width;
              final newPercent = (localX / width).clamp(0.0, 1.0);
              setState(() {
                _dragValue = newPercent;
              });
              final target = duration * newPercent;
              widget.controller.seekTo(target);
            }
          },
          onHorizontalDragEnd: (details) {
            final target = duration * _dragValue;
            widget.controller.seekTo(target).then((_) {
              if (mounted) {
                widget.controller.play();
                setState(() {
                  _isDragging = false;
                });
              }
            });
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localX = details.localPosition.dx;
              final width = box.size.width;
              final percent = (localX / width).clamp(0.0, 1.0);
              final target = duration * percent;
              widget.controller.seekTo(target);
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.transparent, // Geniş sensor sahəsi
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Arxa zolaq (boz)
                Container(
                  height: _isDragging ? 5.0 : 2.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Dolmuş zolaq (TikTok ağ/qırmızı)
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: _isDragging ? 5.0 : 2.5,
                    decoration: BoxDecoration(
                      color: _isDragging ? Colors.redAccent : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Drag zamanı barmaq altındakı indikator
                if (_isDragging)
                  Positioned(
                    left: (MediaQuery.of(context).size.width * progress) - 7,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
