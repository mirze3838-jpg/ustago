// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class TikTokEmbedView extends StatefulWidget {
  final String videoId;
  final String? embedUrl;
  final String? originalUrl;
  final String? title;
  final String? authorName;
  final String? thumbnailUrl;

  const TikTokEmbedView({
    super.key,
    required this.videoId,
    this.embedUrl,
    this.originalUrl,
    this.title,
    this.authorName,
    this.thumbnailUrl,
  });

  @override
  State<TikTokEmbedView> createState() => _TikTokEmbedViewState();
}

class _TikTokEmbedViewState extends State<TikTokEmbedView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'tiktok-iframe-${widget.videoId}-${DateTime.now().microsecondsSinceEpoch}';
    final fallbackSrc =
        'https://www.tiktok.com/player/v1/${widget.videoId}?embed_from=oembed&music_info=1&description=1&autoplay=1&muted=0';
    final rawSrc = widget.embedUrl ?? fallbackSrc;
    final parsed = Uri.tryParse(rawSrc);
    final isAllowedTikTok = parsed != null &&
        parsed.scheme == 'https' &&
        (parsed.host == 'tiktok.com' || parsed.host.endsWith('.tiktok.com'));
    final src = isAllowedTikTok ? parsed.toString() : fallbackSrc;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-popups allow-presentation')
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
