import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// UstaGo — Cloudflare R2 Elan və Mağaza Şəkilləri Yükləmə Xidməti
///
/// Xüsusiyyətlər:
/// 1. AWS SigV4 imzası ilə birbaşa Cloudflare R2 Bucket-inə yükləmə.
/// 2. Sıfır çıxış (Zero Egress) haqqı — şəkillərə limitsiz baxış tam pulsuzdur.
/// 3. Yüksək sürətli qlobal Cloudflare CDN keşlənməsi (`Cache-Control: immutable`).
class R2ImageUploadService {
  static const String accountId = '6f5c125316ec775e48be6a5b27579c5a';
  static const String accessKeyId = '1b833bb1dfe8a3744fe92a1ca55fb098';
  static const String secretAccessKey = '50d7e5923b2698254cb0c89999461b127e3d4672b31efcdb44bdbb4f294f9715';
  static const String bucket = 'ustago-videos';
  static const String publicBaseUrl = 'https://pub-7889d6fa89354ee286e5eb34c3a51e97.r2.dev';

  /// Şəkli Cloudflare R2-yə yükləyir və birbaşa CDN URL-ini qaytarır.
  /// Uğursuz olarsa `null` qaytarır ki, sistem Base64 fallback rejimində işləsin.
  static Future<String?> uploadImage(
    Uint8List imageBytes, {
    String folder = 'ads',
    String? extension,
  }) async {
    try {
      final ext = (extension ?? 'jpg').replaceAll('.', '').toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final fileName = '$folder/img_${DateTime.now().millisecondsSinceEpoch}_${imageBytes.length}.$ext';

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

      final payloadHash = sha256.convert(imageBytes).toString();
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

      final url = Uri.parse('https://$host$canonicalUri');
      final response = await http.put(
        url,
        headers: {
          'Host': host,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'Authorization': authHeader,
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=31536000, immutable',
        },
        body: imageBytes,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final publicUrl = '$publicBaseUrl/$fileName';
        debugPrint('Cloudflare R2 şəkil uğurla yükləndi: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('Cloudflare R2 xəta kodu: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudflare R2 yükləmə istisnası: $e');
      return null;
    }
  }
}
