import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/video_upload_service.dart';

/// Seçilmiş fotolar üçün model
class _PickedPhotoItem {
  final String id;
  Uint8List bytes;
  final String name;
  int rotation; // 0, 90, 180, 270

  _PickedPhotoItem({
    required this.id,
    required this.bytes,
    required this.name,
    this.rotation = 0,
  });
}

/// Yeni İş Paylaş (Qalereya & Shorts) — Yenilənmiş Müasir Bottom Sheet
class AddPostBottomSheet extends StatefulWidget {
  final String uid;
  final String authorName;
  final String role;
  final List<Map<String, dynamic>> categories;
  final Future<Uint8List> Function(Uint8List) compressCoverImage;

  const AddPostBottomSheet({
    super.key,
    required this.uid,
    required this.authorName,
    required this.role,
    required this.categories,
    required this.compressCoverImage,
  });

  @override
  State<AddPostBottomSheet> createState() => _AddPostBottomSheetState();
}

class _AddPostBottomSheetState extends State<AddPostBottomSheet> {
  // 0: Foto Paylaş, 1: Video / Shorts
  int _activeTab = 0;

  // Foto Paylaşma sahələri
  final List<_PickedPhotoItem> _photos = [];
  int _primaryPhotoIndex = 0;
  final TextEditingController _photoTitleController = TextEditingController();
  final TextEditingController _photoDescController = TextEditingController();
  String _photoCategory = 'Tikinti';
  String _photoWorkType = 'Təmir';

  // Video / Shorts sahələri
  XFile? _pickedVideo;
  VideoPlayerController? _videoPlayerController;
  Duration _videoDuration = Duration.zero;
  RangeValues _trimRange = const RangeValues(0, 1);
  double _totalVideoSeconds = 1.0;
  Uint8List? _pickedCoverBytes;
  String _coverName = '';
  bool _isShortsFormat = true;
  final TextEditingController _videoTitleController = TextEditingController();
  final TextEditingController _videoDescController = TextEditingController();
  String _videoCategory = 'Tikinti';

  // Yükləmə statusu
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = '0%';

  final List<String> _workTypes = const [
    'Təmir',
    'Tikinti',
    'Quraşdırma',
    'Bərpa',
    'Dizayn və Layihə',
    'Digər',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      final firstCat = (widget.categories.first['title'] as String).replaceAll('\n', ' ');
      _photoCategory = firstCat;
      _videoCategory = firstCat;
    }
  }

  @override
  void dispose() {
    _photoTitleController.dispose();
    _photoDescController.dispose();
    _videoTitleController.dispose();
    _videoDescController.dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _disposeVideoController() {
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  // --- FOTO FUNKSİYALARI ---

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> pickedList = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (pickedList.isEmpty) return;

      for (final xf in pickedList) {
        final b = await xf.readAsBytes();
        final compressed = await widget.compressCoverImage(b);
        setState(() {
          _photos.add(
            _PickedPhotoItem(
              id: '${DateTime.now().microsecondsSinceEpoch}_${xf.name}',
              bytes: compressed,
              name: xf.name,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('pickMultiImage xətası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəkil seçilərkən xəta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      if (_primaryPhotoIndex >= _photos.length) {
        _primaryPhotoIndex = _photos.isEmpty ? 0 : _photos.length - 1;
      }
    });
  }

  void _setPrimaryPhoto(int index) {
    setState(() {
      _primaryPhotoIndex = index;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Əsas şəkil təyin edildi ⭐'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1265D5),
      ),
    );
  }

  Future<void> _openCropRotateModal(int index) async {
    final photo = _photos[index];
    await showDialog(
      context: context,
      builder: (ctx) {
        int tempRotation = photo.rotation;
        return StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            title: const Text('Şəkli Düzəlt (Döndər)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: (tempRotation / 90).round(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(photo.bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF1265D5),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setDlgState(() {
                          tempRotation = (tempRotation - 90 + 360) % 360;
                        });
                      },
                      icon: const Icon(Icons.rotate_left),
                      label: const Text('-90°'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF1265D5),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setDlgState(() {
                          tempRotation = (tempRotation + 90) % 360;
                        });
                      },
                      icon: const Icon(Icons.rotate_right),
                      label: const Text('+90°'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ləğv et'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1265D5)),
                onPressed: () {
                  setState(() {
                    photo.rotation = tempRotation;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Təsdiq et', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- VİDEO FUNKSİYALARI ---

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    XFile? video;
    try {
      video = await picker.pickVideo(source: ImageSource.gallery);
    } catch (e) {
      debugPrint('pickVideo xətası: $e');
      return;
    }
    if (video == null) return;

    int length = 0;
    try {
      length = await video.length();
    } catch (e) {
      debugPrint('video.length() xətası: $e');
    }
    if (length > 150 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video həcmi 150MB-dan çox olmamalıdır!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _disposeVideoController();

    final controller = VideoPlayerController.file(File(video.path));
    try {
      await controller.initialize();
      final dur = controller.value.duration;
      final totalSec = dur.inMilliseconds / 1000.0;

      setState(() {
        _pickedVideo = video;
        _videoPlayerController = controller;
        _videoDuration = dur;
        _totalVideoSeconds = totalSec > 0 ? totalSec : 1.0;
        _trimRange = RangeValues(0, _totalVideoSeconds);
      });
      controller.setLooping(true);
    } catch (e) {
      debugPrint('Video init xətası: $e');
      setState(() {
        _pickedVideo = video;
      });
    }
  }

  void _removeVideo() {
    _disposeVideoController();
    setState(() {
      _pickedVideo = null;
      _videoDuration = Duration.zero;
      _pickedCoverBytes = null;
      _coverName = '';
    });
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) {
      final rawBytes = await img.readAsBytes();
      final compressed = await widget.compressCoverImage(rawBytes);
      setState(() {
        _pickedCoverBytes = compressed;
        _coverName = img.name;
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // --- PAYLAŞMA ƏMƏLİYYATI ---

  Future<void> _handleShare() async {
    if (_isUploading) return;

    if (_activeTab == 0) {
      // FOTO PAYLAŞIMI
      final title = _photoTitleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zəhmət olmasa işin adını daxil edin!'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zəhmət olmasa ən azı bir şəkil seçin!'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isUploading = true);

      try {
        final primaryPhoto = _photos[_primaryPhotoIndex < _photos.length ? _primaryPhotoIndex : 0];
        final primaryBase64 = base64Encode(primaryPhoto.bytes);

        final allImagesBase64 = _photos.map((p) => base64Encode(p.bytes)).toList();

        String currentAuthorName = widget.authorName;
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
          if (uDoc.exists) {
            final fn = uDoc.data()?['fullName']?.toString().trim();
            if (fn != null && fn.isNotEmpty) currentAuthorName = fn;
          }
        } catch (_) {}

        await FirebaseFirestore.instance.collection('posts').add({
          'userId': widget.uid,
          'authorName': currentAuthorName,
          'authorRole': widget.role,
          'title': title,
          'description': _photoDescController.text.trim(),
          'category': _photoCategory,
          'workType': _photoWorkType,
          'imageBase64': primaryBase64,
          'imagesBase64': allImagesBase64,
          'isVideo': false,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': 0,
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto işiniz uğurla paylaşıldı! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // VİDEO PAYLAŞIMI
      final title = _videoTitleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zəhmət olmasa video başlığını daxil edin!'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_pickedVideo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zəhmət olmasa qalereyadan video seçin!'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadStatusText = 'Bulud bazasına yüklənir...';
        _uploadProgress = 0.15;
      });

      try {
        final uploadedUrl = await VideoUploadService.uploadVideo(
          filePath: _pickedVideo!.path,
          videoBytes: null,
          fileName: _pickedVideo!.name,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _uploadProgress = p;
                _uploadStatusText = '${(p * 100).toStringAsFixed(0)}%';
              });
            }
          },
        );

        final String coverBase64 = _pickedCoverBytes != null ? base64Encode(_pickedCoverBytes!) : '';

        String? uPhoto;
        String currentAuthorName = widget.authorName;
        String currentPhone = '+994 50 000 00 00';
        try {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
          if (uDoc.exists) {
            final uData = uDoc.data();
            uPhoto = uData?['photoBase64'];
            final fn = uData?['fullName']?.toString().trim();
            if (fn != null && fn.isNotEmpty) currentAuthorName = fn;
            final ph = uData?['phone']?.toString().trim();
            if (ph != null && ph.isNotEmpty) currentPhone = ph;
          }
        } catch (_) {}

        final postData = {
          'userId': widget.uid,
          'authorName': currentAuthorName,
          'authorRole': widget.role,
          'title': title,
          'description': _videoDescController.text.trim(),
          'category': _videoCategory,
          'videoUrl': uploadedUrl,
          'imageBase64': coverBase64,
          'thumbnailBase64': coverBase64,
          'thumbnailUrl': '',
          'isVideo': true,
          'isShorts': _isShortsFormat,
          'phone': currentPhone,
          'durationSeconds': _videoDuration.inSeconds,
          'trimStart': _trimRange.start,
          'trimEnd': _trimRange.end,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': 0,
        };

        // 1. Profil postlarına əlavə et
        await FirebaseFirestore.instance.collection('posts').add(postData);

        // 2. Shorts formatı aktivdirsə Shorts bölməsinə də əlavə et (təkrar yükləmə olmadan eyni videoUrl)
        if (_isShortsFormat) {
          await FirebaseFirestore.instance.collection('shorts').add({
            'userId': widget.uid,
            'title': title,
            'description': _videoDescController.text.trim(),
            'videoUrl': uploadedUrl,
            'thumbnailBase64': coverBase64,
            'thumbnailUrl': '',
            'authorPhotoBase64': uPhoto ?? '',
            'artisanName': currentAuthorName,
            'trade': _videoCategory,
            'phone': currentPhone,
            'likes': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isShortsFormat ? 'Shorts video uğurla paylaşıldı! 🎉' : 'Video uğurla paylaşıldı! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video yükləmə xətası: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const primaryBlue = Color(0xFF1265D5);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst qulpu (drag handle)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _activeTab == 0 ? Icons.photo_library_rounded : Icons.play_circle_fill_rounded,
                        color: primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeTab == 0 ? 'Yeni İş Paylaş' : 'Yeni Video Paylaş',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeTab == 0
                                ? 'Şəkillərinizi peşəkar iş portfolionuza əlavə edin'
                                : 'Videolarınızı peşəkar şəkildə paylaşın',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab Switcher (Foto Paylaş / Video / Shorts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 0),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? primaryBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _activeTab == 0
                                  ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_rounded, color: _activeTab == 0 ? Colors.white : const Color(0xFF64748B), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Foto Paylaş',
                                  style: TextStyle(
                                    color: _activeTab == 0 ? Colors.white : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 1),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? primaryBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _activeTab == 1
                                  ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: _activeTab == 1 ? Colors.white : const Color(0xFF64748B), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Video / Shorts',
                                  style: TextStyle(
                                    color: _activeTab == 1 ? Colors.white : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
              ),

              const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _activeTab == 0 ? _buildPhotoTabContent(primaryBlue) : _buildVideoTabContent(primaryBlue),
                ),
              ),

              // Bottom Paylaş düyməsi və ya Progress Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: _isUploading
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _uploadProgress > 0 ? _uploadProgress : null,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFDBEAFE),
                                valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Yüklənir...',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                                ),
                                Text(
                                  _uploadStatusText,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _handleShare,
                          icon: const Icon(Icons.send_rounded, size: 20),
                          label: const Text(
                            'Paylaş',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FOTO TAB GÖRÜNÜŞÜ ---
  Widget _buildPhotoTabContent(Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Şəkil Seçin böyük kartı (nümunədəki kimi)
        InkWell(
          onTap: _pickMultipleImages,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.image_outlined, size: 30, color: Color(0xFF1265D5)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle, color: Color(0xFF1265D5), size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Şəkil Seçin',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Qalereyadan şəkil seçin\nvə ya buraya toxunun',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Seçilmiş şəkillərin üfüqi listi (Reorderable + Sil + Döndər + Əsas Şəkil)
        if (_photos.isNotEmpty) ...[
          SizedBox(
            height: 96,
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length + 1,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex >= _photos.length || newIndex > _photos.length) return;
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _photos.removeAt(oldIndex);
                    _photos.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  // Sonuncu element: "+ Daha çox" düyməsi
                  if (index == _photos.length) {
                    return Container(
                      key: const ValueKey('add_more_photos_btn'),
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: _pickMultipleImages,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_rounded, color: Color(0xFF1265D5), size: 26),
                              SizedBox(height: 4),
                              Text('Daha çox', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1265D5))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final photo = _photos[index];
                  final isPrimary = index == _primaryPhotoIndex;

                  return Container(
                    key: ValueKey(photo.id),
                    width: 88,
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _setPrimaryPhoto(index),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPrimary ? primaryBlue : const Color(0xFFE2E8F0),
                                  width: isPrimary ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: RotatedBox(
                                  quarterTurns: (photo.rotation / 90).round(),
                                  child: Image.memory(photo.bytes, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Əsas şəkil nişanı
                        if (isPrimary)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Əsas', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        // Döndər düyməsi (Sol yuxarı)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: InkWell(
                            onTap: () => _openCropRotateModal(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.crop_rotate_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                        // Sil düyməsi (Sağ yuxarı)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // İşin Adı *
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _photoTitleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'İşin Adı *',
                    hintText: 'Məsələn: Villa tikintisi',
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Ətraflı Təsvir
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _photoDescController,
                      maxLines: 3,
                      maxLength: 500,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Container(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLength/$maxLength',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Ətraflı Təsvir',
                        hintText: 'İşiniz haqqında qısa məlumat yazın...',
                        labelStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Kateqoriya və İş Növü (Yan-yana 2 kart)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, color: Color(0xFF64748B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _photoCategory,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          items: widget.categories.map((c) {
                            final title = (c['title'] as String).replaceAll('\n', ' ');
                            return DropdownMenuItem(
                              value: title,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Kateqoriya', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _photoCategory = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work_outline_rounded, color: Color(0xFF64748B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _photoWorkType,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          items: _workTypes.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('İş Növü', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _photoWorkType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- VİDEO / SHORTS TAB GÖRÜNÜŞÜ ---
  Widget _buildVideoTabContent(Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pickedVideo == null) ...[
          // Video seçilməyibsə böyük seçim kartı
          InkWell(
            onTap: _pickVideo,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.video_library_rounded, size: 30, color: Color(0xFF1265D5)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Qalereyadan Video Seçin',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Shorts və ya portfolio üçün video faylı seçin',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Seçilmiş video önizləməsi (Nümunədəki kimi)
          Container(
            width: double.infinity,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: _videoPlayerController!.value.aspectRatio,
                      child: VideoPlayer(_videoPlayerController!),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator(color: Colors.white)),

                // Play / Pause düyməsi
                if (_videoPlayerController != null)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_videoPlayerController!.value.isPlaying) {
                          _videoPlayerController!.pause();
                        } else {
                          _videoPlayerController!.play();
                        }
                      });
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        _videoPlayerController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                // Dəyiş düyməsi (Sağ yuxarı qələm)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickVideo,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _removeVideo,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Video müddəti nişanı (Sağ aşağı)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black75,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(_videoDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // "Video hazırdır - Önizləməni yoxlayın və paylaşın" bildirişi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(Icons.video_camera_back_rounded, color: Color(0xFF1265D5), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Video hazırdır. Önizləməni yoxlayın və paylaşın',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Videonun başlanğıc və son hissəsini kəsmək (Trim RangeSlider)
          if (_totalVideoSeconds > 2) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Videonun aralığı (Kəs/Trim)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '${_trimRange.start.toStringAsFixed(1)}s - ${_trimRange.end.toStringAsFixed(1)}s',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1265D5)),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _trimRange,
                    min: 0,
                    max: _totalVideoSeconds,
                    activeColor: primaryBlue,
                    inactiveColor: const Color(0xFFE2E8F0),
                    onChanged: (values) {
                      setState(() {
                        _trimRange = values;
                      });
                      _videoPlayerController?.seekTo(Duration(milliseconds: (values.start * 1000).toInt()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Video Üz Qabığı (Kover / Thumbnail) seçimi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pickedCoverBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_pickedCoverBytes!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF1265D5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pickedCoverBytes != null ? 'Üz qabığı seçildi' : 'Video Üz Qabığı (Thumbnail)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        _pickedCoverBytes != null ? _coverName : 'Videoda qaranlıq kadr qalmamaq üçün şəkil seçin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickCoverImage,
                  child: Text(
                    _pickedCoverBytes != null ? 'Dəyiş' : 'Seç',
                    style: const TextStyle(color: Color(0xFF1265D5), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Video Başlığı *
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _videoTitleController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Video Başlığı *',
                    hintText: 'Məsələn: Möhkəm tikinti prosesi',
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Qısa Təsvir
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _videoDescController,
                  maxLines: 2,
                  maxLength: 300,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Qısa Təsvir',
                    hintText: 'Videonuz haqqında məlumat yazın...',
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Kateqoriya seçimi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _videoCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: widget.categories.map((c) {
                      final title = (c['title'] as String).replaceAll('\n', ' ');
                      return DropdownMenuItem(
                        value: title,
                        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _videoCategory = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Shorts üçün format keçidi (Switch)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF1265D5), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Shorts üçün format',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Qısa video (maks. 60 saniyə)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isShortsFormat,
                activeColor: primaryBlue,
                onChanged: (val) => setState(() => _isShortsFormat = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
