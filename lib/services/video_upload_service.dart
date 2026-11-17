import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoUploadService {
  /// Maksimum icazə verilən video fayl ölçüsü: 150 MiB (150 * 1024 * 1024 bayt)
  static const int maxVideoSizeBytes = 150 * 1024 * 1024;

  /// Videonu Firebase Storage-ə yükləyir və birbaşa MP4 linkini qaytarır.
  static Future<String> uploadVideo({
    Uint8List? videoBytes,
    String? filePath,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Video yükləmək üçün əvvəlcə hesaba daxil olun.');
    }

    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > maxVideoSizeBytes) {
          final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
          throw Exception('Seçilən video çox böyükdür ($sizeMB MB). Maksimum icazə verilən hədd 150 MB-dır.');
        }
      }
    } else if (videoBytes != null && videoBytes.length > maxVideoSizeBytes) {
      final sizeMB = (videoBytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw Exception('Seçilən video çox böyükdür ($sizeMB MB). Maksimum icazə verilən hədd 150 MB-dır.');
    }

    final ref = FirebaseStorage.instance.ref().child('shorts_videos/${user.uid}/$name');
    UploadTask uploadTask;

    if (!kIsWeb && filePath != null && filePath.isNotEmpty && await File(filePath).exists()) {
      uploadTask = ref.putFile(
        File(filePath),
        SettableMetadata(contentType: 'video/mp4'),
      );
    } else if (videoBytes != null) {
      uploadTask = ref.putData(
        videoBytes,
        SettableMetadata(contentType: 'video/mp4'),
      );
    } else {
      throw Exception('Yüklənəcək video məlumatı tapılmadı');
    }

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        onProgress?.call(event.bytesTransferred / event.totalBytes);
      }
    });

    final snapshot = await uploadTask.timeout(const Duration(minutes: 5));
    final downloadUrl = await snapshot.ref.getDownloadURL();
    if (downloadUrl.isNotEmpty) {
      onProgress?.call(1.0);
      return downloadUrl;
    }

    throw Exception('Video yüklənə bilmədi. Zəhmət olmasa internet bağlantınızı yoxlayın.');
  }
}
