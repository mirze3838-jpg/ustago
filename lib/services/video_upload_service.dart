import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VideoUploadService {
  /// Videonu pulsuz buluda yükləyir və birbaşa MP4 linkini qaytarır.
  /// Əsas: 0x0.st (düzgün Content-Length + Accept-Ranges, tam streaming dəstəyi)
  /// Ehtiyat: catbox.moe
  static Future<String> uploadVideo({
    required Uint8List videoBytes,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      onProgress?.call(0.1);
      // Əsas server: 0x0.st — düzgün HTTP range headers, daimi link
      final uri = Uri.parse('https://0x0.st');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoBytes,
          filename: name,
        ),
      );

      onProgress?.call(0.2);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      onProgress?.call(0.9);

      final response = await http.Response.fromStream(streamedResponse);
      onProgress?.call(0.95);

      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.startsWith('http')) {
          onProgress?.call(1.0);
          return result;
        }
      }

      debugPrint('0x0.st cavab (${response.statusCode}): ${response.body}. Ehtiyat serverə keçilir...');
      return await _uploadToCatbox(videoBytes, name, onProgress);
    } catch (e) {
      debugPrint('0x0.st upload xətası: $e. Ehtiyat serverə keçilir...');
      return await _uploadToCatbox(videoBytes, name, onProgress);
    }
  }

  /// Ehtiyat server: catbox.moe (200MB limit, daimi link)
  static Future<String> _uploadToCatbox(
    Uint8List videoBytes,
    String name,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final uri = Uri.parse('https://catbox.moe/user/api.php');
      final request = http.MultipartRequest('POST', uri);
      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        http.MultipartFile.fromBytes('fileToUpload', videoBytes, filename: name),
      );

      onProgress?.call(0.5);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.startsWith('http')) {
          onProgress?.call(1.0);
          return result;
        }
      }

      // Son ehtiyat: litterbox (72 saat)
      return await _uploadToLitterbox(videoBytes, name, onProgress);
    } catch (e) {
      return await _uploadToLitterbox(videoBytes, name, onProgress);
    }
  }

  /// Son ehtiyat: litterbox.catbox.moe (72 saat saxlanır)
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

      onProgress?.call(0.6);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.startsWith('http')) {
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
