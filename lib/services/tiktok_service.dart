import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// TikTok video və profil məlumatları modeli
class TikTokInfo {
  final String originalUrl;
  final String canonicalUrl;
  final String? videoId;
  final String embedUrl;
  final String? directVideoUrl;
  final String? title;
  final String? authorName;
  final String? authorUrl;
  final String? profileUsername;
  final String? thumbnailUrl;
  final bool isProfile;
  final bool isVideo;
  final bool isValid;

  const TikTokInfo({
    required this.originalUrl,
    required this.canonicalUrl,
    this.videoId,
    required this.embedUrl,
    this.directVideoUrl,
    this.title,
    this.authorName,
    this.authorUrl,
    this.profileUsername,
    this.thumbnailUrl,
    this.isProfile = false,
    this.isVideo = true,
    this.isValid = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'isTikTok': true,
      'tiktokUrl': originalUrl,
      'canonicalUrl': canonicalUrl,
      'videoId': videoId,
      'embedUrl': embedUrl,
      'directVideoUrl': directVideoUrl,
      'videoUrl': directVideoUrl ?? embedUrl,
      'title': title,
      'authorName': authorName,
      'authorUrl': authorUrl,
      'profileUsername': profileUsername,
      'thumbnailUrl': thumbnailUrl,
      'isProfile': isProfile,
      'isVideo': isVideo,
      'isValid': isValid,
    };
  }
}

class TikTokService {
  /// Daxil edilən mətnin TikTok linki olub-olmadığını yoxlayır
  static bool isTikTokUrl(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('tiktok.com') || text.startsWith('@');
  }

  /// Qısa linkləri (vt.tiktok.com və ya vm.tiktok.com) tam linkə açır
  static Future<String> resolveUrl(String input) async {
    String url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('@')) {
        return 'https://www.tiktok.com/$url';
      }
      url = 'https://$url';
    }

    // Əgər vt.tiktok.com və ya vm.tiktok.com qısa linkidirsə, redirect-i izləyirik
    if (url.contains('vt.tiktok.com') || url.contains('vm.tiktok.com')) {
      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(url))..followRedirects = false;
        final response = await client.send(request).timeout(const Duration(seconds: 5));
        final location = response.headers['location'];
        if (location != null && location.isNotEmpty) {
          return location.split('?').first;
        }
      } catch (e) {
        debugPrint('TikTok redirect resolve xətası: $e');
      }
    }

    return url;
  }

  /// URL-dən video ID-sini çıxarır
  static String? extractVideoId(String url) {
    // 1. /video/1234567890 formatı
    final regVideo = RegExp(r'/video/(\d+)');
    final matchVideo = regVideo.firstMatch(url);
    if (matchVideo != null && matchVideo.groupCount >= 1) {
      return matchVideo.group(1);
    }

    // 2. /v/1234567890 formatı
    final regV = RegExp(r'/v/(\d+)');
    final matchV = regV.firstMatch(url);
    if (matchV != null && matchV.groupCount >= 1) {
      return matchV.group(1);
    }

    // 3. Sırf rəqəmlər daxil edilibsə
    if (RegExp(r'^\d{15,22}$').hasMatch(url.trim())) {
      return url.trim();
    }

    return null;
  }

  /// URL-dən istifadəçi adını (@username) çıxarır
  static String? extractUsername(String url) {
    final regUser = RegExp(r'@([a-zA-Z0-9_\.]+)');
    final match = regUser.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return '@${match.group(1)}';
    }
    return null;
  }

  /// TikTok API vasitəsilə video və ya profil məlumatlarını və birbaşa MP4 axınını gətirir
  static Future<TikTokInfo?> fetchTikTokInfo(String inputUrl) async {
    try {
      final canonical = await resolveUrl(inputUrl);

      // 1. Birinci TikWM API-dən birbaşa təmiz MP4 axınını və real məlumatları alırıq
      try {
        final tikwmUri = Uri.parse(
          'https://www.tikwm.com/api/?url=${Uri.encodeComponent(canonical)}&hd=1',
        );
        final tikwmRes = await http.get(tikwmUri).timeout(const Duration(seconds: 5));
        if (tikwmRes.statusCode == 200) {
          final jsonMap = jsonDecode(utf8.decode(tikwmRes.bodyBytes)) as Map<String, dynamic>;
          if (jsonMap['code'] == 0 && jsonMap['data'] != null) {
            final d = jsonMap['data'] as Map<String, dynamic>;
            final vidId = (d['id'] ?? extractVideoId(canonical))?.toString();
            final playUrl = (d['wmplay'] ?? d['hdplay'] ?? d['play'])?.toString();
            final coverUrl = (d['cover'] ?? d['origin_cover'])?.toString();
            final videoTitle = d['title']?.toString();
            final authorObj = d['author'] as Map<String, dynamic>?;
            final author = authorObj?['nickname']?.toString() ?? authorObj?['unique_id']?.toString() ?? 'Usta';
            final username = authorObj?['unique_id'] != null
                ? '@${authorObj!['unique_id']}'
                : (extractUsername(canonical) ?? '@usta');

            final embedPlayerUrl = vidId != null
                ? 'https://www.tiktok.com/player/v1/$vidId?embed_from=oembed&music_info=1&description=1&autoplay=1&muted=0'
                : canonical;

            return TikTokInfo(
              originalUrl: inputUrl,
              canonicalUrl: canonical,
              videoId: vidId,
              embedUrl: embedPlayerUrl,
              directVideoUrl: playUrl,
              title: videoTitle ?? 'Usta TikTok Videosu',
              authorName: author,
              authorUrl: 'https://www.tiktok.com/$username',
              profileUsername: username,
              thumbnailUrl: coverUrl,
              isProfile: false,
              isVideo: true,
              isValid: true,
            );
          }
        }
      } catch (e) {
        debugPrint('TikWM birbaşa axın xətası, oEmbed-ə keçilir: $e');
      }

      // 2. Fallback: TikTok rəsmi oEmbed API
      final videoId = extractVideoId(canonical);
      final username = extractUsername(canonical);
      final isProfileOnly = videoId == null && username != null && !canonical.contains('/video/');

      final oEmbedUri = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(canonical)}',
      );

      final res = await http.get(oEmbedUri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final embedType = (data['embed_type'] ?? data['type'] ?? '').toString();
        final title = data['title']?.toString();
        final authorName = data['author_name']?.toString() ?? username ?? 'TikTok Ustası';
        final authorUrl = data['author_url']?.toString();
        final productId = data['embed_product_id']?.toString() ?? videoId;
        final thumbUrl = data['thumbnail_url']?.toString();

        final finalVideoId = productId != null && RegExp(r'^\d+$').hasMatch(productId)
            ? productId
            : videoId;

        final embedPlayerUrl = finalVideoId != null
            ? 'https://www.tiktok.com/player/v1/$finalVideoId?embed_from=oembed&music_info=1&description=1&autoplay=1&muted=0'
            : canonical;

        return TikTokInfo(
          originalUrl: inputUrl,
          canonicalUrl: canonical,
          videoId: finalVideoId,
          embedUrl: embedPlayerUrl,
          directVideoUrl: null,
          title: title ?? (isProfileOnly ? 'TikTok Profili: $authorName' : 'Usta TikTok Videosu'),
          authorName: authorName,
          authorUrl: authorUrl ?? (username != null ? 'https://www.tiktok.com/$username' : null),
          profileUsername: username,
          thumbnailUrl: thumbUrl,
          isProfile: isProfileOnly || embedType == 'profile',
          isVideo: !isProfileOnly,
          isValid: true,
        );
      } else if (res.statusCode == 404 || res.statusCode == 400) {
        return null;
      }
    } catch (e) {
      debugPrint('TikTok fetch xətası: $e');
    }

    // Əgər oEmbed şəbəkə səbəbindən cavab verməsə, amma videoId aşkar olunubsa:
    final videoId = extractVideoId(inputUrl);
    final username = extractUsername(inputUrl);
    if (videoId != null) {
      return TikTokInfo(
        originalUrl: inputUrl,
        canonicalUrl: inputUrl,
        videoId: videoId,
        embedUrl: 'https://www.tiktok.com/player/v1/$videoId?embed_from=oembed&music_info=1&description=1&autoplay=1&muted=0',
        directVideoUrl: 'https://www.tikwm.com/video/media/play/$videoId.mp4',
        title: 'Usta TikTok Videosu',
        authorName: username ?? 'Usta',
        profileUsername: username,
        isProfile: false,
        isVideo: true,
        isValid: true,
      );
    }

    return null;
  }

  /// Videonun TikTok-da hələ də aktiv olub-olmadığını (silinmədiyini) yoxlayır
  static Future<bool> isVideoStillActive(String url) async {
    try {
      final canonical = await resolveUrl(url);
      final oEmbedUri = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(canonical)}',
      );
      final res = await http.get(oEmbedUri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      // Şəbəkə xətası olarsa dərhal silmirik, true saxlayırıq ki, müvəqqəti internet itkisində video silinməsin
      return true;
    }
  }
}
