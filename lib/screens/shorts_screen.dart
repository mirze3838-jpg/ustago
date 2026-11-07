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
import 'artisan_detail_screen.dart';

class ShortsScreen extends StatefulWidget {
  final int initialIndex;
  const ShortsScreen({super.key, this.initialIndex = 0});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
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
    super.dispose();
  }

  /// Şəkili Firestore 1MB limitinə uyğun sıxışdırır (maks ~700KB)
  Future<Uint8List> _compressCoverImage(Uint8List bytes) async {
    if (bytes.length <= 700000) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd != null && bd.lengthInBytes < bytes.length) {
        return bd.buffer.asUint8List();
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
                            final picker = ImagePicker();
                            final video = await picker.pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 2),
                            );
                            if (video != null) {
                              final bytes = await video.readAsBytes();
                              setModalState(() {
                                pickedVideo = video;
                                pickedVideoBytes = bytes;
                              });
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
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  CategoryCityService.getCategoryPlaceholderImage(tradeController.text),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.movie_filter_rounded, color: Color(0xFF1769D2)),
                                ),
                              ),
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
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: const Text('Avtomatik HD', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            Text(
                              pickedCoverBytes != null
                                  ? pickedCover!.name
                                  : 'Qaranlıq qalmamaq üçün peşənizə uyğun canlı şəkil',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                          if (img != null) {
                            final rawBytes = await img.readAsBytes();
                            // Firestore 1MB limit üçün şəkli sıxışdırırıq
                            final compressed = await _compressCoverImage(rawBytes);
                            setModalState(() {
                              pickedCover = img;
                              pickedCoverBytes = compressed;
                            });
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
                        if (pickedVideo != null && pickedVideoBytes != null) {
                          try {
                            setModalState(() {
                              uploadStatus = 'Video bulud bazasına yüklənir...';
                              uploadProgress = 0.2;
                            });

                            final uploadedUrl = await VideoUploadService.uploadVideo(
                              videoBytes: pickedVideoBytes!,
                              fileName: pickedVideo!.name,
                              onProgress: (p) {
                                setModalState(() {
                                  uploadProgress = p;
                                  uploadStatus = '${(p * 100).toStringAsFixed(0)}%';
                                });
                              },
                            );

                            finalVideoUrl = uploadedUrl;
                          } catch (e) {
                            debugPrint('Video upload error: $e');
                            setModalState(() => isUploading = false);
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
                          final authorName = user?.displayName ?? 'UstaGo Ustası';
                          final uid = user?.uid ?? 'guest';
                          final tradeVal = tradeController.text.trim().isEmpty ? 'Tikinti' : tradeController.text.trim();

                          String? uPhoto;
                          if (user != null) {
                            try {
                              final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              if (uDoc.exists) {
                                uPhoto = uDoc.data()?['photoBase64'];
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
                            'phone': phone.isEmpty ? '+994 50 000 00 00' : phone,
                            'likes': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          // 2. İstifadəçinin profil qalereyasına (posts) da video kimi əlavə edirik
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('posts').add({
                              'userId': uid,
                              'authorName': authorName,
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
            stream: FirebaseFirestore.instance
                .collection('shorts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
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
              // Yalnız heç bir real video yüklənməyibsə nümunə videoları göstəririk
              if (items.isEmpty) {
                items.addAll(_sampleShorts);
              }

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _ShortVideoItem(
                    key: ValueKey(items[index]['id'] ?? index),
                    data: items[index],
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
        ],
      ),
    );
  }
}

class _ShortVideoItem extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ShortVideoItem({super.key, required this.data});

  @override
  State<_ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<_ShortVideoItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _hasError = false;

  int _likeCount = 0;
  bool _isLiked = false;
  String? _authorPhotoBase64;
  String? _authorPhotoUrl;

  @override
  void initState() {
    super.initState();
    _likeCount = int.tryParse(widget.data['likes']?.toString() ?? '0') ?? 0;
    _checkIfLiked();
    _loadAuthorPhoto();
    _initVideo();
  }

  void _loadAuthorPhoto() async {
    final photo = widget.data['authorPhotoBase64'] ?? widget.data['photoBase64'];
    if (photo != null && photo.toString().isNotEmpty) {
      if (mounted) setState(() => _authorPhotoBase64 = photo.toString());
      return;
    }
    final uid = widget.data['userId']?.toString() ?? '';
    if (uid.isNotEmpty && uid != 'guest') {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _authorPhotoBase64 = data?['photoBase64'];
            _authorPhotoUrl = data?['photoUrl'];
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _openArtisanProfile() async {
    final uid = widget.data['userId']?.toString() ?? '';
    Map<String, dynamic> artisanMap = {
      'id': uid,
      'uid': uid,
      'fullName': widget.data['artisanName'] ?? 'Usta',
      'category': widget.data['trade'] ?? 'Usta',
      'phone': widget.data['phone'] ?? '',
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtisanDetailScreen(artisanData: artisanMap),
        ),
      );
    }
  }

  void _checkIfLiked() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final likedBy = widget.data['likedBy'];
    if (uid != null && likedBy is List && likedBy.contains(uid)) {
      if (mounted) setState(() => _isLiked = true);
    }
  }

  Future<void> _toggleLike() async {
    final docId = widget.data['id']?.toString() ?? '';
    if (docId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        if (_likeCount > 0) _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('shorts').doc(docId);
      if (_isLiked) {
        await docRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([uid]),
        });
      } else {
        await docRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([uid]),
        });
      }
    } catch (e) {
      debugPrint('Like error: $e');
    }
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
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                // Başlıq
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rəylər',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final cDoc = comments[index];
                          final cData = cDoc.data();
                          final String author = cData['userName'] ?? 'İstifadəçi';
                          final String text = cData['text'] ?? '';
                          final String? photoBase64 = cData['userPhotoBase64'];
                          final String commentUserId = (cData['userId'] ?? '').toString();
                          final String videoOwnerId = (widget.data['userId'] ?? '').toString();
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

                          // Həm rəy yazan şəxs, həm də videosuna rəy yazılan şəxs (video sahibi) rəyi silə bilər!
                          final bool canDelete = currentUserId.isNotEmpty &&
                              (currentUserId == commentUserId || currentUserId == videoOwnerId);

                          ImageProvider? cAvatar;
                          if (photoBase64 != null && photoBase64.isNotEmpty) {
                            try {
                              cAvatar = MemoryImage(base64Decode(photoBase64));
                            } catch (_) {}
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onLongPress: () async {
                              if (!canDelete) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Yalnız rəy müəllifi və ya video sahibi bu rəyi silə bilər.'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.black87,
                                  ),
                                );
                                return;
                              }

                              final bool? confirm = await showModalBottomSheet<bool>(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (sheetCtx) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          margin: const EdgeInsets.only(bottom: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const Text(
                                          'Rəyi silmək istəyirsiniz?',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '"$text"',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => Navigator.pop(sheetCtx, false),
                                                child: const Text('İmtina'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => Navigator.pop(sheetCtx, true),
                                                icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                                                label: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await cDoc.reference.delete();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Rəy uğurla silindi.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Row(
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
                                        const SizedBox(height: 2),
                                        Text(
                                          text,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canDelete)
                                    Tooltip(
                                      message: 'Silmək üçün basılı saxlayın',
                                      child: Icon(Icons.more_horiz, size: 18, color: Colors.grey.shade400),
                                    ),
                                ],
                              ),
                            ),
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
                                  setModalState(() => isPosting = true);

                                  final user = FirebaseAuth.instance.currentUser;
                                  String userName = user?.displayName ?? 'İstifadəçi';
                                  String? userPhoto;

                                  if (user != null) {
                                    try {
                                      final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                      if (uDoc.exists) {
                                        userName = uDoc.data()?['fullName'] ?? userName;
                                        userPhoto = uDoc.data()?['photoBase64'];
                                      }
                                    } catch (_) {}
                                  }

                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('shorts')
                                        .doc(docId)
                                        .collection('comments')
                                        .add({
                                      'userId': user?.uid ?? 'guest',
                                      'userName': userName,
                                      'userPhotoBase64': userPhoto,
                                      'text': text,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
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

  Future<void> _initVideo() async {
    String url = widget.data['videoUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    if (url.contains('tmpfiles.org')) {
      if (!url.contains('/dl/') || url.split('/').length < 7) {
        try {
          final pageUrl = url.replaceFirst('/dl/', '/');
          final res = await http.get(Uri.parse(pageUrl)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final m = RegExp(r'href="([^"]+/dl/[^"]+)"').firstMatch(res.body);
            if (m != null) {
              url = m.group(1)!;
            }
          }
        } catch (_) {}
      }
    }

    try {
      // Heç bir zərərli httpHeaders ötürmürük - ExoPlayer birbaşa açır
      // Web-də Flutter video_player brauzerin native <video> elementini işlədir
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      // Timeout: web üçün 15s, mobil üçün 25s
      final timeoutDur = kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 25);
      await controller.initialize().timeout(
        timeoutDur,
        onTimeout: () {
          debugPrint('Video initialize timeout: $url');
        },
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      // Initialize sonrası yoxla
      if (!controller.value.isInitialized) {
        if (mounted) setState(() => _hasError = true);
        return;
      }

      controller.setLooping(true);
      await controller.play();

      setState(() {
        _isInitialized = true;
        _hasError = false;
        _isPlaying = true;
      });

      controller.addListener(() {
        if (!mounted) return;
        final playing = controller.value.isPlaying;
        if (playing != _isPlaying) {
          setState(() {
            _isPlaying = playing;
          });
        }
      });
    } catch (e) {
      debugPrint('Video oxutma xətası ($url): $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
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
        await FirebaseFirestore.instance.collection('shorts').doc(docId.toString()).delete();
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

    // Peşəyə uyğun gözəl HD foto kadrı
    final String placeholderImg = CategoryCityService.getCategoryPlaceholderImage(trade);

    final fallbackWidget = Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          placeholderImg,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.75)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
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
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 0. VİDEO AÇILANA QƏDƏR ARXA FONDA BAŞLIQ FOTOSU (Qaranlıq qalmır!)
          _buildCoverImage(widget.data),
          // 1. VİDEO EKRANI (Əsl en-boy nisbəti qorunur, kənarları kəsilmir)
          if (_isInitialized && _controller != null && !_hasError)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio > 0
                    ? _controller!.value.aspectRatio
                    : (9 / 16),
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 72),
                  const SizedBox(height: 16),
                  if (kIsWeb) ...[
                    const Text(
                      'Videonu izləmək üçün toxunun',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = widget.data['videoUrl']?.toString() ?? '';
                        if (url.isNotEmpty) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Videonu Aç'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Video oxunmadı',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isInitialized = false;
                        });
                        _controller?.dispose();
                        _controller = null;
                        _initVideo();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      label: const Text('Yenidən cəhd et', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ],
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Video yüklənir...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Video buferlənərkən fırlanan çarx
          if (_isInitialized && _controller != null && _controller!.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),

          // Pause olduqda mərkəzdə Play ikonu
          if (!_isPlaying && _isInitialized)
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

          // Sağ tərəfdəki düymələr (Bəyən, WhatsApp, Zəng, Sil)
          Positioned(
            right: 16,
            bottom: 90,
            child: Builder(
              builder: (context) {
                final currentUser = FirebaseAuth.instance.currentUser;
                final bool isOwnerOrAdmin = currentUser != null &&
                    ((widget.data['userId'] != null && currentUser.uid == widget.data['userId']) ||
                     currentUser.email == 'mirze3838@gmail.com');

                return Column(
                  children: [
                    _buildSideAction(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      _likeCount.toString(),
                      _isLiked ? Colors.red : Colors.white,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 18),
                    _buildSideAction(
                      Icons.chat_bubble_outline_rounded,
                      'Rəy',
                      Colors.white,
                      onTap: () => _showCommentsModal(widget.data['id']?.toString() ?? ''),
                    ),
                    const SizedBox(height: 18),
                    _buildSideAction(Icons.chat, 'WhatsApp', Colors.green, onTap: () => _openWhatsApp(widget.data['phone'])),
                    const SizedBox(height: 18),
                    _buildSideAction(Icons.call, 'Zəng', const Color(0xFF00C853), onTap: () => _makeCall(widget.data['phone'])),
                    if (isOwnerOrAdmin && widget.data['id'] != null) ...[
                      const SizedBox(height: 18),
                      _buildSideAction(Icons.delete_outline_rounded, 'Sil', Colors.redAccent, onTap: _confirmDeleteVideo),
                    ],
                  ],
                );
              },
            ),
          ),

          // Aşağı sol tərəfdəki usta məlumatı
          Positioned(
            left: 16,
            right: 80,
            bottom: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openArtisanProfile,
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          ImageProvider? aAvatar;
                          if (_authorPhotoBase64 != null && _authorPhotoBase64!.isNotEmpty) {
                            try {
                              aAvatar = MemoryImage(base64Decode(_authorPhotoBase64!));
                            } catch (_) {}
                          } else if (_authorPhotoUrl != null && _authorPhotoUrl!.isNotEmpty) {
                            aAvatar = NetworkImage(_authorPhotoUrl!);
                          }
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            backgroundImage: aAvatar,
                            child: aAvatar == null
                                ? const Icon(Icons.person, color: Color(0xFF1769D2), size: 24)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.data['artisanName'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
                              ],
                            ),
                            Text(
                              widget.data['trade'],
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.data['title'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _makeCall(widget.data['phone']),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Zəng et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(widget.data['phone']),
                      icon: const Icon(Icons.chat, size: 16, color: Colors.green),
                      label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideAction(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
