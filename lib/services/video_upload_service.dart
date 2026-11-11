import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoUploadService {
  /// Maksimum icazə verilən video fayl ölçüsü: 150 MiB (150 * 1024 * 1024 bayt)
  static const int maxVideoSizeBytes = 150 * 1024 * 1024;

  /// Videonu buluda yükləyir və birbaşa MP4 linkini qaytarır.
  /// 
  /// ƏSAS STRATEGİYA (Streaming Upload - Zero RAM Peak):
  /// - Əgər `filePath` təqdim olunubsa (Android/iOS), fayl diskdən `File.openRead()` axını ilə
  ///   birbaşa şəbəkə soketinə göndərilir. Bütün fayl heç vaxt RAM-a yüklənmir.
  /// - Əgər `videoBytes` verilibsə və ya Web platformadırsa, mövcud byte əsaslı üsul işləyir.
  static Future<String> uploadVideo({
    Uint8List? videoBytes,
    String? filePath,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final name = fileName ?? 'usta_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 0. Fayl ölçüsünün təhlükəsiz yoxlanması (150 MiB limiti - RAM = 0 MB)
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

    // 1. Birinci cəhd: Cloudflare R2
    try {
      if (!kIsWeb && filePath != null && filePath.isNotEmpty && await File(filePath).exists()) {
        final r2Url = await _uploadToCloudflareR2Stream(filePath, name, onProgress);
        if (r2Url.isNotEmpty) {
          debugPrint('Video Cloudflare R2-yə Stream ilə uğurla yükləndi: $r2Url');
          return r2Url;
        }
      } else if (videoBytes != null) {
        final r2Url = await _uploadToCloudflareR2(videoBytes, name, onProgress);
        if (r2Url.isNotEmpty) {
          debugPrint('Video Cloudflare R2-yə uğurla yükləndi: $r2Url');
          return r2Url;
        }
      }
    } catch (e) {
      debugPrint('Cloudflare R2 upload xətası ($e), ehtiyat serverlərə keçilir...');
    }

    // 2. İkinci cəhd: Firebase Storage
    try {
      final ref = FirebaseStorage.instance.ref().child('shorts_videos/$name');
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
    } catch (e) {
      debugPrint('Firebase Storage upload xətası ($e), ehtiyat serverlərə keçilir...');
    }

    // 3. Üçüncü cəhd: Fallback serverlər (Yalnız Web və ya kiçik video üçün təhlükəsiz)
    // Təhlükəsizlik qaydası: Böyük videolarda RAM-ın dolmaması üçün Catbox/Tmpfiles üçün readAsBytes() çağırılmır!
    if (!kIsWeb && filePath != null) {
      // Mobil platformada R2 və Firebase hər ikisi alınmadısa, RAM-ı qorumaq üçün upload dayandırılır
      throw Exception('Video buluduna qoşulmaq mümkün olmadı (R2 və Firebase cavab vermir). Zəhmət olmasa internet bağlantınızı yoxlayın.');
    }

    if (videoBytes != null && videoBytes.isNotEmpty) {
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

    throw Exception('Video faylı oxuna bilmədi və ya dəstəklənmir.');
  }

  /// Fayl yolundan (Diskdən) axınla SHA256 heşinin hesablanması (RAM = 0 MB)
  static Future<String> _calculateFileSha256(File file) async {
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString();
  }

  /// Cloudflare R2-yə DISKDƏN STREAM ilə yükləmə (Bütün fayl RAM-a yüklənmir!)
  static Future<String> _uploadToCloudflareR2Stream(
    String filePath,
    String fileName,
    void Function(double progress)? onProgress,
  ) async {
    const accountId = '6f5c125316ec775e48be6a5b27579c5a';
    const accessKeyId = '1b833bb1dfe8a3744fe92a1ca55fb098';
    const secretAccessKey = '50d7e5923b2698254cb0c89999461b127e3d4672b31efcdb44bdbb4f294f9715';
    const bucket = 'ustago-videos';
    const publicBaseUrl = 'https://pub-7889d6fa89354ee286e5eb34c3a51e97.r2.dev';

    final file = File(filePath);
    final totalLength = await file.length();
    if (totalLength <= 0) {
      throw Exception('Video faylı boşdur (0 bayt)');
    }

    onProgress?.call(0.05);

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

    // AWS SigV4 imzası üçün SHA-256 heşi (Fayl diskdən parça-parça oxunaraq hesablanır)
    final payloadHash = await _calculateFileSha256(file);
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

    onProgress?.call(0.15);

    final url = Uri.parse('https://$host$canonicalUri');
    final request = http.StreamedRequest('PUT', url);

    request.headers['Host'] = host;
    request.headers['x-amz-date'] = amzDate;
    request.headers['x-amz-content-sha256'] = payloadHash;
    request.headers['Authorization'] = authHeader;
    request.headers['Content-Type'] = 'video/mp4';
    request.headers['Cache-Control'] = 'public, max-age=31536000, immutable';
    request.contentLength = totalLength;

    int sentBytes = 0;
    final fileStream = file.openRead();

    final completer = Completer<http.StreamedResponse>();

    fileStream.listen(
      (chunk) {
        sentBytes += chunk.length;
        request.sink.add(chunk);
        if (totalLength > 0) {
          // 15% - 95% aralığı real upload tərəqqisidir
          final p = 0.15 + (sentBytes / totalLength) * 0.80;
          onProgress?.call(p.clamp(0.0, 0.95));
        }
      },
      onDone: () async {
        try {
          await request.sink.close();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      },
      cancelOnError: true,
    );

    // Sorğunun göndərilməsi və cavabın gözlənilməsi
    final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    onProgress?.call(0.98);

    if (response.statusCode == 200) {
      onProgress?.call(1.0);
      return '$publicBaseUrl/$fileName';
    } else {
      throw Exception('R2 stream upload failed with code ${response.statusCode}: ${response.body}');
    }
  }

  /// Cloudflare R2-yə AWS SigV4 imzası ilə birbaşa yüksək sürətli yükləmə (Uint8List fallback)
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
        'Cache-Control': 'public, max-age=31536000, immutable',
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
