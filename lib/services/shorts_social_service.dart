import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// UstaGo Shorts TikTok Tipli Sosial Funksiyalar Servisi
class ShortsSocialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => currentUser?.uid;

  // ================= 1. LIKE / UNLIKE =================
  /// Videonun cari istifadəçi tərəfindən bəyənilib-bəyənilmədiyini yoxlayır
  static Future<bool> isVideoLiked(String shortId) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty) return false;
    try {
      final doc = await _firestore
          .collection('shorts')
          .doc(shortId)
          .collection('likes')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('isVideoLiked error: $e');
      return false;
    }
  }

  /// Videonu bəyən / bəyənməni geri götür (Atomic Transaction ilə sayğac dəqiqliyi)
  static Future<bool> toggleLikeVideo(String shortId) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty) {
      throw Exception('Əməliyyat üçün daxil olun');
    }

    final shortRef = _firestore.collection('shorts').doc(shortId);
    final likeRef = shortRef.collection('likes').doc(uid);

    return await _firestore.runTransaction<bool>((tx) async {
      final likeSnap = await tx.get(likeRef);
      final shortSnap = await tx.get(shortRef);

      if (!shortSnap.exists) {
        throw Exception('Video tapılmadı');
      }

      int curLikes = 0;
      final rawLikes = shortSnap.data()?['likes'];
      if (rawLikes is num) {
        curLikes = rawLikes.toInt();
      } else if (rawLikes is String) {
        curLikes = int.tryParse(rawLikes) ?? 0;
      }

      if (likeSnap.exists) {
        // Artıq bəyənib -> Bəyənməni ləğv et
        tx.delete(likeRef);
        final newLikes = (curLikes - 1) < 0 ? 0 : (curLikes - 1);
        tx.update(shortRef, {
          'likes': newLikes,
          'likedBy': FieldValue.arrayRemove([uid]),
        });
        return false; // Artıq bəyənilməyib
      } else {
        // Bəyən
        tx.set(likeRef, {
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final newLikes = curLikes + 1;
        tx.update(shortRef, {
          'likes': newLikes,
          'likedBy': FieldValue.arrayUnion([uid]),
        });
        return true; // Bəyənildi
      }
    });
  }

  // ================= 2. FOLLOW / UNFOLLOW =================
  /// Ustanın izlənilib-izlənilmədiyini yoxlayır
  static Future<bool> isArtisanFollowed(String artisanUid) async {
    final uid = currentUid;
    if (uid == null || artisanUid.isEmpty || uid == artisanUid) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(artisanUid)
          .collection('followers')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('isArtisanFollowed error: $e');
      return false;
    }
  }

  /// Ustanı izlə / izləməni dayandır (Təhlükəsiz atomik batch: yalnız icazə verilən sub-kolleksiyalar və öz sənədi yenilənir)
  static Future<bool> toggleFollowArtisan(String artisanUid) async {
    final uid = currentUid;
    if (uid == null || artisanUid.isEmpty) {
      throw Exception('İzləmək üçün daxil olun');
    }
    if (uid == artisanUid) {
      throw Exception('Öz profilinizi izləyə bilməzsiniz');
    }

    final followerRef = _firestore.collection('users').doc(artisanUid).collection('followers').doc(uid);
    final followingRef = _firestore.collection('users').doc(uid).collection('following').doc(artisanUid);
    final currentUserRef = _firestore.collection('users').doc(uid);

    final snap = await followerRef.get();
    if (snap.exists) {
      // İzləməni ləğv et
      final batch = _firestore.batch();
      batch.delete(followerRef);
      batch.delete(followingRef);
      // Yalnız öz sənədimizdəki followingCount sayğacını yeniləyirik
      batch.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});
      await batch.commit();
      return false;
    } else {
      // İzlə
      final batch = _firestore.batch();
      batch.set(followerRef, {
        'followerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(followingRef, {
        'targetUserId': artisanUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(currentUserRef, {'followingCount': FieldValue.increment(1)});
      await batch.commit();
      return true;
    }
  }

  // ================= 3. SAVE / BOOKMARK =================
  /// Videonun yadda saxlanılıb-saxlanılmadığını yoxlayır
  static Future<bool> isVideoSaved(String shortId) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_shorts')
          .doc(shortId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('isVideoSaved error: $e');
      return false;
    }
  }

  /// Videonu yadda saxla / yaddaşdan sil
  static Future<bool> toggleSaveVideo(String shortId, Map<String, dynamic> shortData) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty) {
      throw Exception('Videonu yadda saxlamaq üçün daxil olun');
    }

    final savedRef = _firestore.collection('users').doc(uid).collection('saved_shorts').doc(shortId);
    final snap = await savedRef.get();

    if (snap.exists) {
      await savedRef.delete();
      return false;
    } else {
      await savedRef.set({
        'shortId': shortId,
        'title': shortData['title'] ?? '',
        'videoUrl': shortData['videoUrl'] ?? '',
        'thumbnailBase64': shortData['thumbnailBase64'] ?? '',
        'thumbnailUrl': shortData['thumbnailUrl'] ?? '',
        'artisanName': shortData['artisanName'] ?? '',
        'authorPhotoBase64': shortData['authorPhotoBase64'] ?? '',
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  // ================= 4. SHARE =================
  /// Videonu sistem menyusu ilə paylaşır
  static Future<void> shareVideo({
    required String title,
    required String artisanName,
    required String? videoUrl,
  }) async {
    final shareText = StringBuffer();
    if (artisanName.isNotEmpty) {
      shareText.writeln('UstaGo Usta Shorts: $artisanName');
    }
    if (title.isNotEmpty) {
      shareText.writeln(title);
    }
    if (videoUrl != null && videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
      shareText.writeln('\nVideoya bax: $videoUrl');
    }
    shareText.writeln('\nUstaGo — Azərbaycanın ən böyük usta və xidmət platforması!');

    await Share.share(
      shareText.toString(),
      subject: 'UstaGo Shorts: $title',
    );
  }

  // ================= 5. ŞƏRHLƏR (COMMENT LIKE & DELETE) =================
  /// Şərhi bəyən / bəyənməni geri götür
  static Future<bool> toggleLikeComment(String shortId, String commentId) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty || commentId.isEmpty) return false;

    final commentRef = _firestore.collection('shorts').doc(shortId).collection('comments').doc(commentId);
    final likeRef = commentRef.collection('likes').doc(uid);

    final likeSnap = await likeRef.get();
    if (likeSnap.exists) {
      await likeRef.delete();
      await commentRef.update({'likes': FieldValue.increment(-1)}).catchError((_) {});
      return false;
    } else {
      await likeRef.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await commentRef.update({'likes': FieldValue.increment(1)}).catchError((_) {});
      return true;
    }
  }

  /// Şərhi sil (Yalnız şərh müəllifi, video sahibi və ya admin)
  static Future<void> deleteComment(String shortId, String commentId) async {
    await _firestore
        .collection('shorts')
        .doc(shortId)
        .collection('comments')
        .doc(commentId)
        .delete();

    await _firestore.collection('shorts').doc(shortId).update({
      'commentsCount': FieldValue.increment(-1),
    }).catchError((_) {});
  }

  /// Yeni şərh göndər
  static Future<void> addComment({
    required String shortId,
    required String text,
    required String userName,
    String? userPhotoBase64,
  }) async {
    final uid = currentUid ?? 'guest';
    await _firestore.collection('shorts').doc(shortId).collection('comments').add({
      'userId': uid,
      'userName': userName,
      'userPhotoBase64': userPhotoBase64,
      'text': text,
      'likes': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('shorts').doc(shortId).update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {});
  }

  // ================= 6. ŞİKAYƏT ET (REPORT) =================
  static Future<void> reportVideo({
    required String shortId,
    required String reason,
  }) async {
    final uid = currentUid ?? 'guest';
    await _firestore.collection('reports').add({
      'targetType': 'short',
      'shortId': shortId,
      'reportedBy': uid,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================= 7. VİDEO VƏ ALT-KOLLEKSİYALARIN TƏHLÜKƏSİZ SİLİNMƏSİ =================
  /// Videonu və onun bütün alt-kolleksiyalarını (comments, likes) batch ilə tam təmizləyir
  static Future<void> deleteShortVideoCompletely(String shortId) async {
    final uid = currentUid;
    if (uid == null || shortId.isEmpty) {
      throw Exception('Videonu silmək üçün daxil olun');
    }

    final shortRef = _firestore.collection('shorts').doc(shortId);
    final shortDoc = await shortRef.get();
    if (!shortDoc.exists) return;

    final shortData = shortDoc.data();
    final isOwner = shortData?['userId'] == uid;
    // Yalnız video sahibi və ya admin silə bilər
    if (!isOwner && currentUser?.email != 'mirze3838@gmail.com') {
      throw Exception('Yalnız öz videonuzu silə bilərsiniz');
    }

    // 1. Şərhləri və onların likes alt-kolleksiyasını toplayıb silirik (batch limit: 500)
    final commentsSnap = await shortRef.collection('comments').limit(200).get();
    final batch = _firestore.batch();

    for (var cDoc in commentsSnap.docs) {
      final cLikesSnap = await cDoc.reference.collection('likes').limit(50).get();
      for (var clDoc in cLikesSnap.docs) {
        batch.delete(clDoc.reference);
      }
      batch.delete(cDoc.reference);
    }

    // 2. Videonun öz likes alt-kolleksiyasını silirik
    final likesSnap = await shortRef.collection('likes').limit(200).get();
    for (var lDoc in likesSnap.docs) {
      batch.delete(lDoc.reference);
    }

    // 3. Əsas video sənədini silirik
    batch.delete(shortRef);

    await batch.commit();
  }
}
