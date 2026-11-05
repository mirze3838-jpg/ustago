import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VideoUploadService {
  /// Videonu buluda yükləyir və birbaşa MP4 linkini qaytarır.
  /// - Veb brauzerdə (CORS dəstəyi ilə): TmpFiles
  /// - Mobil tətbiqdə (Android): Catbox.moe və TmpFiles fallback
  static Future<String> uploadVideo({
    required Uint8List videoBytes,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (kIsWeb) {
      try {
        return await _uploadToTmpfiles(videoBytes, name, onProgress);
      } catch (e) {
        debugPrint('Web upload fallback: $e');
        return await _uploadToCatbox(videoBytes, name, onProgress);
      }
    } else {
      try {
        return await _uploadToCatbox(videoBytes, name, onProgress);
      } catch (e) {
        debugPrint('Mobile upload fallback to tmpfiles: $e');
        return await _uploadToTmpfiles(videoBytes, name, onProgress);
      }
    }
  }

  static Future<String> _uploadToCatbox(
    Uint8List videoBytes,
    String name,
    void Function(double progress)? onProgress,
  ) async {
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
      onProgress?.call(0.85);

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

  /// TmpFiles serveri - Veb brauzerlər üçün tam CORS dəstəkləyir
  static Future<String> _uploadToTmpfiles(
    Uint8List videoBytes,
    String name,
    void Function(double progress)? onProgress,
  ) async {
    try {
      onProgress?.call(0.2);
      final uri = Uri.parse('https://tmpfiles.org/api/v1/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('file', videoBytes, filename: name),
      );

      onProgress?.call(0.5);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);
      onProgress?.call(0.9);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data']?['url'] != null) {
          String url = decoded['data']['url'].toString();
          // Birbaşa video URL-nə çeviririk: https://tmpfiles.org/xxx/yyy -> https://tmpfiles.org/dl/xxx/yyy
          if (url.contains('tmpfiles.org/') && !url.contains('tmpfiles.org/dl/')) {
            url = url.replaceFirst('tmpfiles.org/', 'tmpfiles.org/dl/');
          }
          onProgress?.call(1.0);
          return url;
        }
      }
      throw Exception('Serverdən keçərsiz cavab: ${response.statusCode}');
    } catch (e) {
      throw Exception('TmpFiles yükləmə xətası: $e');
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
