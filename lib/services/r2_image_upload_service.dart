import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// UstaGo — Şəkil Yükləmə Xidməti (Təhlükəsiz Firebase Storage + Base64 fallback)
class R2ImageUploadService {
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB

  static bool _isValidImageMagicBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Şəkli təhlükəsiz şəkildə Firebase Storage-ə yükləyir və CDN URL-ini qaytarır.
  /// Uğursuz olarsa `null` qaytarır ki, sistem sıxılmış Base64 fallback rejimində işləsin.
  static Future<String?> uploadImage(
    Uint8List imageBytes, {
    String folder = 'ads',
    String? extension,
  }) async {
    try {
      if (imageBytes.isEmpty || imageBytes.length > maxImageSizeBytes) {
        return null;
      }
      if (!_isValidImageMagicBytes(imageBytes)) {
        debugPrint('R2ImageUploadService: Etibarsız şəkil formatı.');
        return null;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final ext = (extension ?? 'jpg').replaceAll('.', '').toLowerCase();
      final allowedExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
      final contentType = allowedExt == 'png'
          ? 'image/png'
          : (allowedExt == 'webp' ? 'image/webp' : 'image/jpeg');

      final fileName = '${safeFolder.isEmpty ? 'ads' : safeFolder}/${user.uid}/img_${DateTime.now().millisecondsSinceEpoch}.$allowedExt';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final snapshot = await ref
          .putData(imageBytes, SettableMetadata(contentType: contentType))
          .timeout(const Duration(seconds: 20));
      final url = await snapshot.ref.getDownloadURL();
      return url.isNotEmpty ? url : null;
    } catch (e) {
      debugPrint('Şəkil buluda yüklənmədi (Base64 fallback işlənəcək): $e');
      return null;
    }
  }
}
