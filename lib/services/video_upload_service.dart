import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VideoUploadService {
  /// Videonu pulsuz və limitsiz buluda yükləyir və birbaşa MP4 linkini qaytarır.
  /// Əsas Server: Catbox.moe (Daimi saxlama, 200MB limit, tam pulsuz)
  /// Ehtiyat Server: Litterbox (1GB limit)
  static Future<String> uploadVideo({
    required Uint8List videoBytes,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      onProgress?.call(0.15);
      final uri = Uri.parse('https://catbox.moe/user/api.php');
      final request = http.MultipartRequest('POST', uri);
      request.fields['reqtype'] = 'fileupload';

      final multipartFile = http.MultipartFile.fromBytes(
        'fileToUpload',
        videoBytes,
        filename: name,
      );
      request.files.add(multipartFile);

      onProgress?.call(0.3);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      onProgress?.call(0.9);

      final response = await http.Response.fromStream(streamedResponse);
      onProgress?.call(0.95);

      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.startsWith('http://') || result.startsWith('https://')) {
          onProgress?.call(1.0);
          return result;
        }
      }

      debugPrint('Catbox cavab (${response.statusCode}): ${response.body}. Ehtiyat serverə keçilir...');
      return await _uploadToLitterbox(videoBytes, name, onProgress);
    } catch (e) {
      debugPrint('Catbox upload error: $e, Ehtiyat serverə keçilir...');
      return await _uploadToLitterbox(videoBytes, name, onProgress);
    }
  }

  /// Ehtiyat server: Litterbox
  static Future<String> _uploadToLitterbox(
    Uint8List videoBytes,
    String name,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final uri = Uri.parse('https://litterbox.catbox.moe/resources/internals/api.php');
      final request = http.MultipartRequest('POST', uri);
      request.fields['reqtype'] = 'fileupload';
      request.fields['time'] = '72h';
      request.files.add(
        http.MultipartFile.fromBytes('fileToUpload', videoBytes, filename: name),
      );

      onProgress?.call(0.5);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.startsWith('http://') || result.startsWith('https://')) {
          onProgress?.call(1.0);
          return result;
        }
      }
      throw Exception('Video serverindən keçərsiz cavab: ${response.body}');
    } catch (e) {
      throw Exception('Video buluduna yükləmə uğursuz oldu: $e');
    }
  }
}
