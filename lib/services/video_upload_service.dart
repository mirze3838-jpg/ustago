import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoUploadService {
  /// Videonu buluda yükləyir və birbaşa MP4 linkini qaytarır.
  /// 1. Cloudflare R2 (Ən sürətli qlobal CDN, sıfır gecikmə, limitsiz daimi saxlama)
  /// 2. Firebase Storage (Ehtiyat server)
  /// 3. Catbox.moe / TmpFiles (Alternativ serverlər)
  static Future<String> uploadVideo({
    required Uint8List videoBytes,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 1. Birinci cəhd: Cloudflare R2 (Dünyanın ən sürətli video buludu)
    try {
      final r2Url = await _uploadToCloudflareR2(videoBytes, name, onProgress);
      if (r2Url.isNotEmpty) {
        debugPrint('Video Cloudflare R2-yə uğurla yükləndi: $r2Url');
        return r2Url;
      }
    } catch (e) {
      debugPrint('Cloudflare R2 upload xətası ($e), ehtiyat serverlərə keçilir...');
    }

    // 2. İkinci cəhd: Firebase Storage
    try {
      final ref = FirebaseStorage.instance.ref().child('shorts_videos/$name');
      final uploadTask = ref.putData(
        videoBytes,
        SettableMetadata(contentType: 'video/mp4'),
      );
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
    } catch (e) {
      debugPrint('Firebase Storage upload xətası ($e), ehtiyat serverlərə keçilir...');
    }

    // 3. Üçüncü cəhd: Veb və ya Mobil fallback
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

  /// Cloudflare R2-yə AWS SigV4 imzası ilə birbaşa yüksək sürətli yükləmə
  static Future<String> _uploadToCloudflareR2(
    Uint8List videoBytes,
    String fileName,
    void Function(double progress)? onProgress,
  ) async {
    const accountId = '6f5c125316ec775e48be6a5b27579c5a';
    const accessKeyId = '1b833bb1dfe8a3744fe92a1ca55fb098';
    const secretAccessKey = '50d7e5923b2698254cb0c89999461b127e3d4672b31efcdb44bdbb4f294f9715';
    const bucket = 'ustago-videos';
    const publicBaseUrl = 'https://pub-7889d6fa89354ee286e5eb34c3a51e97.r2.dev';

    onProgress?.call(0.1);

    final host = '$accountId.r2.cloudflarestorage.com';
    const region = 'auto';
    const service = 's3';

    final now = DateTime.now().toUtc();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final dateStamp = '$year$month$day';
    final amzDate = '${dateStamp}T$hour$minute${second}Z';

    final payloadHash = sha256.convert(videoBytes).toString();
    final canonicalUri = '/$bucket/$fileName';
    final canonicalHeaders = 'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalRequest = 'PUT\n$canonicalUri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    List<int> getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
      final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
      final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
      final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
      return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    }

    final signingKey = getSignatureKey(secretAccessKey, dateStamp, region, service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authHeader = 'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    onProgress?.call(0.3);

    final url = Uri.parse('https://$host$canonicalUri');
    final response = await http.put(
      url,
      headers: {
        'Host': host,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': payloadHash,
        'Authorization': authHeader,
        'Content-Type': 'video/mp4',
      },
      body: videoBytes,
    ).timeout(const Duration(minutes: 5));

    onProgress?.call(0.95);

    if (response.statusCode == 200) {
      onProgress?.call(1.0);
      return '$publicBaseUrl/$fileName';
    } else {
      throw Exception('R2 upload failed with code ${response.statusCode}: ${response.body}');
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
          final String pageUrl = decoded['data']['url'].toString();

          // tmpfiles.org web səhifəsindən birbaşa MP4 stream linkini (/dl/.../.../name.mp4) əldə edirik
          try {
            final pageRes = await http.get(Uri.parse(pageUrl)).timeout(const Duration(seconds: 8));
            if (pageRes.statusCode == 200) {
              final match = RegExp(r'href="([^"]+/dl/[^"]+)"').firstMatch(pageRes.body);
              if (match != null) {
                final directUrl = match.group(1)!;
                onProgress?.call(1.0);
                return directUrl;
              }
            }
          } catch (e) {
            debugPrint('Direct link parsing error: $e');
          }

          // Fallback
          String url = pageUrl;
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
