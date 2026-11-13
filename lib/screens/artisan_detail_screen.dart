import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'shorts_screen.dart';

class ArtisanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> artisanData;

  const ArtisanDetailScreen({super.key, required this.artisanData});

  @override
  State<ArtisanDetailScreen> createState() => _ArtisanDetailScreenState();
}

class _ArtisanDetailScreenState extends State<ArtisanDetailScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  late bool _isWorking;
  String? _customBio;

  @override
  void initState() {
    super.initState();
    _isWorking = widget.artisanData['isWorking'] == true;
    _customBio = widget.artisanData['bio'] as String?;
    final videoUrl = widget.artisanData['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        });
    }
  }

  Widget _buildVideoGradientFallback(Map<String, dynamic> data) {
    final tr = (data['trade'] ?? '').toString().toLowerCase();
    List<Color> gColors = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
    if (tr.contains('santexnik') || tr.contains('su')) {
      gColors = const [Color(0xFF0284C7), Color(0xFF0369A1)];
    } else if (tr.contains('elektrik') || tr.contains('işıq')) {
      gColors = const [Color(0xFFD97706), Color(0xFFB45309)];
    } else if (tr.contains('tikinti') || tr.contains('hörgü')) {
      gColors = const [Color(0xFFEA580C), Color(0xFFC2410C)];
    } else if (tr.contains('mebel')) {
      gColors = const [Color(0xFF92400E), Color(0xFF78350F)];
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = '994${clean.substring(1)}';
    final Uri uri = Uri.parse('https://wa.me/$clean?text=Salam%20$name,%20UstaGo-dan%20əlaqə%20saxlayıram.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddReviewDialog(String artisanUid, String artisanName) {
    int rating = 5;
    final commentController = TextEditingController();
    final nameController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      nameController.text = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Müştəri';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.rate_review_rounded, color: Color(0xFF1769D2), size: 24),
              SizedBox(width: 8),
              Text('Rəy və Qiymətləndirmə', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$artisanName tərəfindən görülən işi qiymətləndirin:',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 34,
                        ),
                        onPressed: () {
                          setDialogState(() => rating = starValue);
                        },
                      );
                    }),
                  ),
                ),
                Center(
                  child: Text(
                    rating == 5
                        ? '⭐⭐⭐⭐⭐ Əla xidmət'
                        : (rating == 4
                            ? '⭐⭐⭐⭐ Çox yaxşı'
                            : (rating == 3 ? '⭐⭐⭐ Orta' : '⭐⭐ Zəif')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Adınız *',
                    hintText: 'Məs: Elçin Məmmədov',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Şərhiniz *',
                    hintText: 'Görülən iş, operativlik və qiymət haqqında rəyiniz...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ləğv et'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769D2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final comment = commentController.text.trim();
                final reviewer = nameController.text.trim();
                if (comment.isEmpty || reviewer.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zəhmət olmasa ad və rəyinizi qeyd edin!')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await FirebaseFirestore.instance.collection('reviews').add({
                    'artisanId': artisanUid,
                    'artisanName': artisanName,
                    'reviewerName': reviewer,
                    'rating': rating,
                    'comment': comment,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  // Ustanın real ortalama reytinqini və rəy sayını users kolleksiyasında yeniləyirik
                  try {
                    final revSnap = await FirebaseFirestore.instance
                        .collection('reviews')
                        .where('artisanId', isEqualTo: artisanUid)
                        .get();
                    if (revSnap.docs.isNotEmpty) {
                      double sum = 0;
                      for (var r in revSnap.docs) {
                        final val = r.data()['rating'];
                        if (val is num) sum += val.toDouble();
                      }
                      final double avg = sum / revSnap.docs.length;
                      await FirebaseFirestore.instance.collection('users').doc(artisanUid).update({
                        'rating': double.parse(avg.toStringAsFixed(1)),
                        'reviewCount': revSnap.docs.length,
                      });
                    }
                  } catch (_) {}

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Təşəkkür edirik! Rəyiniz qeydə alındı.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Göndər', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBioDialog(String uId, String currentBio, String defaultBio) {
    final controller = TextEditingController(text: currentBio.trim().isNotEmpty ? currentBio : defaultBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: Color(0xFF1769D2), size: 26),
            SizedBox(width: 8),
            Text('Haqqımda Məlumatı Dəyiş', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gördüyünüz işlər, təcrübəniz və müştərilərə xidmət şərtləriniz haqqında məlumat yazın:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Məsələn: 10 illik təcrübə, santexnika və istilik sistemlərinin quraşdırılması...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1769D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newBio = controller.text.trim();
              setState(() {
                _customBio = newBio;
              });
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('users').doc(uId).set({
                  'bio': newBio,
                }, SetOptions(merge: true));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Haqqımda məlumatı uğurla yeniləndi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Yadda saxla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.artisanData['fullName'] ?? widget.artisanData['name'] ?? 'Usta';
    final phone = widget.artisanData['phone'] ?? '';
    final category = widget.artisanData['category'] ?? widget.artisanData['trade'] ?? 'Tikinti';
    final isVerified = widget.artisanData['isVerified'] == true;
    final photoBase64 = widget.artisanData['photoBase64'] as String?;
    final city = widget.artisanData['city'] ?? 'Bakı';
    final userId = widget.artisanData['uid'] ?? widget.artisanData['userId'] ?? widget.artisanData['id'];
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isMyProfile = currentUser != null && currentUser.uid == userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('$name - Anket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profil kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                // Profil şəkli
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                  backgroundImage: (photoBase64 != null && photoBase64.isNotEmpty)
                      ? MemoryImage(base64Decode(photoBase64))
                      : null,
                  child: (photoBase64 == null || photoBase64.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF1769D2), size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$category Ustası',
                    style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 15, color: Color(0xFFE53935)),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // HAL-HAZIRDA İŞLƏYİR VƏ YA İŞLƏMİR İŞARƏSİ / STATUŞ KARTI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isWorking ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isWorking ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isWorking ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isWorking ? 'Hal-hazırda işləyir (Məşğuldur)' : 'Sərbəstdir (Sifariş qəbul edir)',
                        style: TextStyle(
                          color: _isWorking ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Əgər usta öz anketinə baxırsa, birbaşa statusu dəyişmək keçidi
                if (isMyProfile) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    icon: Icon(_isWorking ? Icons.toggle_on : Icons.toggle_off, color: const Color(0xFF1769D2), size: 24),
                    label: Text(
                      _isWorking ? 'Statusu "Sərbəstdir" et' : 'Statusu "İşləyir" et',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      final newStatus = !_isWorking;
                      setState(() => _isWorking = newStatus);
                      await FirebaseFirestore.instance.collection('users').doc(userId.toString()).set({
                        'isWorking': newStatus,
                      }, SetOptions(merge: true));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(newStatus ? 'Status "Hal-hazırda işləyir" olaraq dəyişdirildi!' : 'Status "Sərbəstdir" olaraq dəyişdirildi!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // Əlaqə düymələri (Zəng və WhatsApp)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty ? () => _makeCall(phone) : null,
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Zəng Et', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty ? () => _openWhatsApp(phone, name) : null,
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Xidmət və Təcrübə haqqında
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF1769D2), size: 20),
                        SizedBox(width: 8),
                        Text('Usta Haqqında', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (isMyProfile && userId != null)
                      InkWell(
                        onTap: () => _showEditBioDialog(
                          userId.toString(),
                          _customBio ?? '',
                          'Hörmətli müştərilər, $category sahəsində çoxillik təcrübəyə malik peşəkar usta olaraq yüksək keyfiyyətli xidmət təklif edirəm. Bütün işlər zəmanətlə və vaxtında təhvil verilir.',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1769D2).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.edit, size: 14, color: Color(0xFF1769D2)),
                              SizedBox(width: 4),
                              Text('Dəyiş', style: TextStyle(color: Color(0xFF1769D2), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (_customBio != null && _customBio!.trim().isNotEmpty)
                      ? _customBio!
                      : 'Hörmətli müştərilər, $category sahəsində çoxillik təcrübəyə malik peşəkar usta olaraq yüksək keyfiyyətli xidmət təklif edirəm. Bütün işlər zəmanətlə və vaxtında təhvil verilir.',
                  style: const TextStyle(color: Color(0xFF334155), height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (phone.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone_iphone, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Əlaqə nömrəsi: $phone', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Ustanın Şəkillər və Videolar Bölməsi (Ayrı-ayrı, Yalnız ən son 1 ədəd kart, klikləndikdə tam bölmə açılır)
          if (userId != null) ...[
            _buildSeparateMediaSection(userId.toString(), name, category),
          ],

        const SizedBox(height: 20),

        // 4. Müştəri Rəyləri və Qiymətləndirmə (Reviews & Ratings)
        if (userId != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 6),
                        Text(
                          'Müştəri Rəyləri',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1769D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Rəy Yaz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddReviewDialog(userId.toString(), name),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('artisanId', isEqualTo: userId.toString())
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.rate_review_outlined, color: Colors.grey, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Hələ ki heç kim rəy bildirməyib',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Bu ustanın ilk rəyini siz yazın və digər müştərilərə kömək edin!',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Reytinq ortalaması
                    double avgRating = 0;
                    for (var d in docs) {
                      avgRating += (d.data()['rating'] as num?)?.toDouble() ?? 5.0;
                    }
                    avgRating = avgRating / docs.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reytinq ümumi kartı
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        i < avgRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                                        color: Colors.amber,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              Text(
                                '${docs.length} rəy əsasında',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Rəylərin siyahısı
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
                              padding: const EdgeInsets.all(12),
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
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(0xFF1769D2).withOpacity(0.15),
                                            child: Text(
                                              revName.isNotEmpty ? revName[0].toUpperCase() : 'M',
                                              style: const TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            revName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: List.generate(5, (starIdx) {
                                          return Icon(
                                            starIdx < revRating ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 15,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    revComment,
                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.3),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

  void _showFullScreenImage(BuildContext context, String imgBase64, String title) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.memory(
                  base64Decode(imgBase64),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Şəkillər və Videolar bölməsini tam ayıran, hərəsindən yalnız ən son 1 ədədini göstərən
  /// və üzərinə basıldıqda bütün müvafiq siyahını açan metod
  Widget _buildSeparateMediaSection(String uId, String artisanName, String trade) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ŞƏKİLLƏR BÖLMƏSİ (Portfolio) — Yalnız son 1 şəkil
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: uId)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
            allDocs.sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });
            final photoDocs = allDocs.where((d) {
              final data = d.data();
              final bool isVid = data['isVideo'] == true ||
                  (data['videoUrl'] != null && data['videoUrl'].toString().trim().isNotEmpty);
              if (isVid) return false;
              final hasImg = (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty) ||
                  (data['imagesBase64'] != null && (data['imagesBase64'] as List).isNotEmpty) ||
                  (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().isNotEmpty);
              return hasImg;
            }).toList();

            final int count = photoDocs.length;
            final latestDoc = photoDocs.isNotEmpty ? photoDocs.first : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1769D2), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Şəkillər (Portfolio)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      if (count > 0)
                        InkWell(
                          onTap: () => _openAllPhotosScreen(context, uId, artisanName),
                          child: Row(
                            children: [
                              Text(
                                'Hamısı ($count)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF1769D2)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (latestDoc == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Hələlik iş şəkli yüklənməyib',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => _openAllPhotosScreen(context, uId, artisanName),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Builder(
                                builder: (_) {
                                  final data = latestDoc.data();
                                  String? base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
                                  if ((base64Img == null || base64Img.isEmpty) &&
                                      data['imagesBase64'] is List &&
                                      (data['imagesBase64'] as List).isNotEmpty) {
                                    base64Img = (data['imagesBase64'] as List).first.toString();
                                  }
                                  if (base64Img != null && base64Img.isNotEmpty) {
                                    try {
                                      return Image.memory(base64Decode(base64Img), fit: BoxFit.cover);
                                    } catch (_) {}
                                  }
                                  final thumbUrl = data['thumbnailUrl']?.toString();
                                  if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                                    return Image.network(thumbUrl, fit: BoxFit.cover);
                                  }
                                  return Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        latestDoc.data()['title'] ?? 'Son Görülən İş',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1769D2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.collections_rounded, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'Şəkilləri Aç',
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        // 2. VİDEOLAR BÖLMƏSİ (Shorts) — Yalnız son 1 video
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('shorts')
              .where('userId', isEqualTo: uId)
              .snapshots(),
          builder: (context, snapshot) {
            final videoDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
            videoDocs.sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });
            final int count = videoDocs.length;
            final latestDoc = videoDocs.isNotEmpty ? videoDocs.first : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.video_library_rounded, color: Color(0xFFDC2626), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Videolar (Shorts)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      if (count > 0)
                        InkWell(
                          onTap: () => _openAllVideosScreen(context, uId, artisanName),
                          child: Row(
                            children: [
                              Text(
                                'Hamısı ($count)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: Color(0xFFDC2626)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (latestDoc == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Hələlik video yüklənməyib',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: () => _openAllVideosScreen(context, uId, artisanName),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Builder(
                                builder: (_) {
                                  final data = latestDoc.data();
                                  // thumbnailBase64, imageBase64, imagesBase64 — hamısını yoxla
                                  String? coverBase64 = data['thumbnailBase64']?.toString();
                                  if (coverBase64 == null || coverBase64.isEmpty) {
                                    coverBase64 = data['imageBase64']?.toString();
                                  }
                                  if ((coverBase64 == null || coverBase64.isEmpty) &&
                                      data['imagesBase64'] is List &&
                                      (data['imagesBase64'] as List).isNotEmpty) {
                                    coverBase64 = (data['imagesBase64'] as List).first.toString();
                                  }
                                  if (coverBase64 != null && coverBase64.isNotEmpty) {
                                    try {
                                      return Image.memory(base64Decode(coverBase64), fit: BoxFit.cover);
                                    } catch (_) {}
                                  }
                                  final thumbUrl = data['thumbnailUrl']?.toString();
                                  if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                                    return Image.network(
                                      thumbUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildVideoGradientFallback(data),
                                    );
                                  }
                                  final tr = (data['trade'] ?? '').toString().toLowerCase();
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

                                  return Container(
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
                                        Positioned(
                                          right: -20,
                                          top: -20,
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(0.12),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.25),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                                            ),
                                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(trIcon, color: Colors.white, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (data['trade'] ?? 'Shorts').toString(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        latestDoc.data()['title'] ?? 'Son Video',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.play_circle_outline, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text(
                                            'Videoları Aç',
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Ustanın Bütün Şəkillər Bölməsini (Portfolio Siyahısını) açan xüsusi səhifə
  void _openAllPhotosScreen(BuildContext context, String uId, String artisanName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArtisanAllPhotosScreen(userId: uId, artisanName: artisanName),
      ),
    );
  }

  /// Ustanın Bütün Videolar Bölməsini (Shorts lentini) açan xüsusi səhifə
  void _openAllVideosScreen(BuildContext context, String uId, String artisanName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsScreen(targetUserId: uId),
      ),
    );
  }
}

/// Ustanın bütün fotoşəkillərini göstərən təmiz qalereya səhifəsi
class _ArtisanAllPhotosScreen extends StatelessWidget {
  final String userId;
  final String artisanName;

  const _ArtisanAllPhotosScreen({required this.userId, required this.artisanName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$artisanName - Şəkillər', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return mb.compareTo(ma);
          });
          final photoDocs = docs.where((d) {
            final data = d.data();
            final bool isVid = data['isVideo'] == true ||
                (data['videoUrl'] != null && data['videoUrl'].toString().trim().isNotEmpty);
            if (isVid) return false;
            final hasImg = (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty) ||
                (data['imagesBase64'] != null && (data['imagesBase64'] as List).isNotEmpty) ||
                (data['thumbnailUrl'] != null && data['thumbnailUrl'].toString().isNotEmpty);
            return hasImg;
          }).toList();

          if (photoDocs.isEmpty) {
            return const Center(
              child: Text('Heç bir şəkil tapılmadı', style: TextStyle(color: Color(0xFF94A3B8))),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: photoDocs.length,
            itemBuilder: (context, index) {
              final doc = photoDocs[index];
              final data = doc.data();
              String? base64Img = (data['imageBase64'] ?? data['thumbnailBase64']) as String?;
              if ((base64Img == null || base64Img.isEmpty) &&
                  data['imagesBase64'] is List &&
                  (data['imagesBase64'] as List).isNotEmpty) {
                base64Img = (data['imagesBase64'] as List).first.toString();
              }

              return InkWell(
                onTap: () {
                  if (base64Img != null && base64Img.isNotEmpty) {
                    showDialog(
                      context: context,
                      useSafeArea: false,
                      builder: (ctx) => Scaffold(
                        backgroundColor: Colors.black,
                        body: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Image.memory(base64Decode(base64Img!), fit: BoxFit.contain),
                              ),
                            ),
                            SafeArea(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Builder(
                      builder: (_) {
                        if (base64Img != null && base64Img.isNotEmpty) {
                          try {
                            return Image.memory(base64Decode(base64Img), fit: BoxFit.cover);
                          } catch (_) {}
                        }
                        final thumbUrl = data['thumbnailUrl']?.toString();
                        if (thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.contains('unsplash.com')) {
                          return Image.network(thumbUrl, fit: BoxFit.cover);
                        }
                        return const Center(
                          child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
