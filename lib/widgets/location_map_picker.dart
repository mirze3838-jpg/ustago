import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/location_helper.dart';

const Color _kBlue = Color(0xFF1769D2);

/// GPS / icazə axınının nəticəsi
class LocationAcquireResult {
  final LocationPosition? position;
  final bool permissionGranted;
  const LocationAcquireResult({this.position, this.permissionGranted = false});
}

/// Android-in 3 konum vəziyyətini idarə edən axın:
/// 1) GPS bağlıdır -> bildiriş + "Konum parametrlərini aç", geri qayıdanda yenidən yoxlanılır
/// 2) GPS açıqdır, icazə yoxdur -> rəsmi runtime icazə pəncərəsi (sonsuz təkrarlanmır)
/// 3) Hər ikisi aktivdir -> cari koordinatlar alınır
class LocationFlow {
  static Future<void> _waitForResume() {
    final completer = Completer<void>();
    late final _ResumeObserver observer;
    observer = _ResumeObserver(() {
      WidgetsBinding.instance.removeObserver(observer);
      if (!completer.isCompleted) completer.complete();
    });
    WidgetsBinding.instance.addObserver(observer);
    // Təhlükəsizlik üçün: 3 dəqiqədən sonra gözləməni dayandır
    return completer.future.timeout(const Duration(minutes: 3), onTimeout: () {
      WidgetsBinding.instance.removeObserver(observer);
    });
  }

  static void _snack(BuildContext context, String msg, {Color color = const Color(0xFF334155)}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(duration: const Duration(milliseconds: 1300), content: Text(msg), backgroundColor: color));
  }

  static Future<LocationAcquireResult> acquireCurrentLocation(BuildContext context) async {
    // 1. GPS xidmətinin vəziyyəti
    var status = await LocationHelper.checkLocationStatus();
    if (!status.gpsEnabled) {
      if (!context.mounted) return const LocationAcquireResult();
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 26),
              SizedBox(width: 8),
              Expanded(child: Text('Konum xidməti bağlıdır', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text(
            'Telefonunuzda konum xidməti bağlıdır. Davam etmək üçün konumu aktivləşdirin.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bağla')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Konum parametrlərini aç'),
            ),
          ],
        ),
      );
      if (openSettings != true) return LocationAcquireResult(permissionGranted: status.isGranted);
      final opened = await LocationHelper.openLocationSettings();
      if (!opened) {
        if (context.mounted) {
          _snack(context, 'Cihazın parametrlərindən konum xidmətini aktivləşdirib yenidən cəhd edin.');
        }
        return LocationAcquireResult(permissionGranted: status.isGranted);
      }
      // İstifadəçi parametrlərdən geri qayıdanda GPS yenidən yoxlanılır
      await _waitForResume();
      await Future.delayed(const Duration(milliseconds: 400));
      status = await LocationHelper.checkLocationStatus();
      if (!status.gpsEnabled) {
        if (context.mounted) {
          _snack(context, 'Konum xidməti hələ də bağlıdır. Konumu xəritədə əl ilə də seçə bilərsiniz.',
              color: const Color(0xFFB45309));
        }
        return LocationAcquireResult(permissionGranted: status.isGranted);
      }
    }

    // 2. Tətbiqin konum icazəsi
    if (!status.isGranted) {
      String perm = status.permission;
      if (perm != 'permanentlyDenied') {
        perm = await LocationHelper.requestLocationPermission();
      }
      if (perm == 'denied') {
        if (context.mounted) {
          _snack(
            context,
            'Konum icazəsi verilmədi. Konumunuzu xəritədə əl ilə seçə və ya ünvanı yaza bilərsiniz.',
            color: const Color(0xFFB45309),
          );
        }
        return const LocationAcquireResult();
      }
      if (perm == 'permanentlyDenied') {
        if (!context.mounted) return const LocationAcquireResult();
        final goSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Konum icazəsi rədd edilib', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: const Text(
              'UstaGo-ya konum icazəsi verilməyib. Cari mövqeyinizi avtomatik tapmaq üçün tətbiqin '
              'parametrlərində "Konum" icazəsini aktivləşdirin. İstəsəniz, konumu xəritədə əl ilə də seçə bilərsiniz.',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Əl ilə seçəcəyəm')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tətbiq parametrlərini aç'),
              ),
            ],
          ),
        );
        if (goSettings != true) return const LocationAcquireResult();
        final opened = await LocationHelper.openAppSettings();
        if (!opened) {
          if (context.mounted) {
            _snack(context, 'Brauzer / cihaz parametrlərindən bu sayt üçün konum icazəsini aktivləşdirin.');
          }
          return const LocationAcquireResult();
        }
        await _waitForResume();
        await Future.delayed(const Duration(milliseconds: 400));
        final again = await LocationHelper.checkLocationStatus();
        if (!again.isGranted) {
          if (context.mounted) _snack(context, 'Konum icazəsi hələ də verilməyib.', color: const Color(0xFFB45309));
          return const LocationAcquireResult();
        }
      }
    }

    // 3. GPS açıq və icazə var -> cari koordinatlar
    try {
      final pos = await LocationHelper.getCurrentPosition();
      return LocationAcquireResult(position: pos, permissionGranted: true);
    } on LocationException catch (e) {
      if (context.mounted) {
        String msg = 'Konum alınarkən xəta baş verdi. Yenidən cəhd edin və ya xəritədə əl ilə seçin.';
        if (e.code == 'TIMEOUT') msg = 'Konum vaxtında alınmadı. Açıq məkanda yenidən cəhd edin və ya əl ilə seçin.';
        if (e.code == 'GPS_DISABLED') msg = 'Konum xidməti bağlıdır. Zəhmət olmasa aktivləşdirin.';
        _snack(context, msg, color: const Color(0xFFDC2626));
      }
      return const LocationAcquireResult(permissionGranted: true);
    }
  }

  /// Konumun ictimai profildə paylaşılması üçün AYRICA razılıq pəncərəsi.
  /// Yalnız "Bəli, konumumu paylaş" seçildikdə true qaytarır.
  static Future<bool> askShareConsent(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.share_location_rounded, color: _kBlue, size: 26),
            SizedBox(width: 8),
            Expanded(child: Text('Konum paylaşımı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: const Text(
          'Konumunuzu Ustago profilinizdə paylaşmaq istəyirsiniz? Konumunuz yalnız təsdiq etdikdən sonra paylaşılacaq.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İmtina et')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bəli, konumumu paylaş'),
          ),
        ],
      ),
    );
    return res == true;
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  final VoidCallback onResume;
  _ResumeObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// Plitəli (tile) küçə xəritəsi. Marker mərkəzdə sabitdir:
/// xəritəni sürüşdürmək və ya toxunmaq markerin yerini dəyişir.
class TileMapView extends StatelessWidget {
  final double lat;
  final double lng;
  final double zoom;
  final ValueChanged<List<double>> onCenterChanged;
  final bool showMarker;

  const TileMapView({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.onCenterChanged,
    this.showMarker = true,
  });

  @override
  Widget build(BuildContext context) {
    final int tileZ = zoom.floor().clamp(3, 18);
    final int nTiles = 1 << tileZ;
    final double worldPx = 256.0 * math.pow(2.0, zoom).toDouble();
    final double tileSize = 256.0 * math.pow(2.0, zoom - tileZ).toDouble();

    double lngToX(double v) => ((v + 180.0) / 360.0) * worldPx;
    double latToY(double v) {
      final double rad = v.clamp(-85.0, 85.0) * math.pi / 180.0;
      final double s = math.sin(rad);
      return (0.5 - math.log((1.0 + s) / (1.0 - s)) / (4.0 * math.pi)) * worldPx;
    }

    List<double> pxToLatLng(double x, double y) {
      final double nLng = ((x / worldPx) * 360.0 - 180.0).clamp(-180.0, 180.0);
      final double yF = (y / worldPx).clamp(0.001, 0.999);
      final double n = math.pi - 2.0 * math.pi * yF;
      final double nLat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
      return [nLat, nLng];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double cx = lngToX(lng);
        final double cy = latToY(lat);

        final int minTx = ((cx - w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTx = ((cx + w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int minTy = ((cy - h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
        final int maxTy = ((cy + h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);

        final tiles = <Widget>[];
        for (int tx = minTx; tx <= maxTx; tx++) {
          for (int ty = minTy; ty <= maxTy; ty++) {
            final int sub = (tx + ty) % 4;
            tiles.add(Positioned(
              key: ValueKey('t_${tileZ}_${tx}_$ty'),
              left: w / 2.0 + (tx * tileSize - cx),
              top: h / 2.0 + (ty * tileSize - cy),
              width: tileSize + 0.6,
              height: tileSize + 0.6,
              child: Image.network(
                'https://mt$sub.google.com/vt/lyrs=m&x=$tx&y=$ty&z=$tileZ&hl=az',
                fit: BoxFit.fill,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Image.network(
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$tileZ/$ty/$tx',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ));
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onCenterChanged(pxToLatLng(cx - d.delta.dx, cy - d.delta.dy)),
          onTapUp: (d) => onCenterChanged(
            pxToLatLng(cx + (d.localPosition.dx - w / 2.0), cy + (d.localPosition.dy - h / 2.0)),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Container(color: const Color(0xFFEAF2F8)),
                ...tiles,
                if (showMarker)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 34),
                      child: Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 40,
                          shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _roundMapButton({required IconData icon, required VoidCallback? onTap, String? tooltip, Widget? child}) {
  return Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(child: child ?? Icon(icon, size: 20, color: const Color(0xFF0F172A))),
        ),
      ),
    ),
  );
}

/// Qeydiyyat formasında yığcam (200 dp) xəritə kartı
class CompactLocationMap extends StatelessWidget {
  final double lat;
  final double lng;
  final double zoom;
  final bool isConfirmed;
  final bool isLoading;
  final bool isRequired;
  final String addressLabel;
  final ValueChanged<List<double>> onCenterChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onOpenFullScreen;
  final VoidCallback onConfirm;
  final ValueChanged<bool>? onDragStateChanged;

  const CompactLocationMap({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.isConfirmed,
    required this.isLoading,
    required this.addressLabel,
    required this.onCenterChanged,
    required this.onZoomChanged,
    required this.onUseCurrentLocation,
    required this.onOpenFullScreen,
    required this.onConfirm,
    this.isRequired = false,
    this.onDragStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Listener(
              onPointerDown: (_) => onDragStateChanged?.call(true),
              onPointerUp: (_) => onDragStateChanged?.call(false),
              onPointerCancel: (_) => onDragStateChanged?.call(false),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TileMapView(lat: lat, lng: lng, zoom: zoom, onCenterChanged: onCenterChanged),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Column(
                      children: [
                        _roundMapButton(icon: Icons.fullscreen_rounded, tooltip: 'Tam ekran', onTap: onOpenFullScreen),
                        const SizedBox(height: 6),
                        _roundMapButton(
                          icon: Icons.add,
                          tooltip: 'Yaxınlaşdır',
                          onTap: () => onZoomChanged((zoom + 1).clamp(5.0, 18.0)),
                        ),
                        const SizedBox(height: 6),
                        _roundMapButton(
                          icon: Icons.remove,
                          tooltip: 'Uzaqlaşdır',
                          onTap: () => onZoomChanged((zoom - 1).clamp(5.0, 18.0)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _roundMapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Cari mövqeyimə keç',
                      onTap: isLoading ? null : onUseCurrentLocation,
                      child: isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 20, color: _kBlue),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              addressLabel.isEmpty ? 'Ünvan seçilməyib' : addressLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBlue,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isLoading ? null : onUseCurrentLocation,
                icon: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gps_fixed_rounded, size: 18),
                label: Text(isLoading ? 'Konum alınır...' : 'Konumu əlavə et',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmed ? const Color(0xFF059669) : _kBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onConfirm,
                icon: Icon(isConfirmed ? Icons.check_circle_rounded : Icons.pin_drop_rounded, size: 18),
                label: Text(isConfirmed ? 'Təsdiqləndi' : 'Bu nöqtəni təsdiqlə',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tam ekran xəritə seçicisi. Nəticə: {'lat','lng','zoom','fromGps'}
class FullScreenMapPickerPage extends StatefulWidget {
  final double lat;
  final double lng;
  final double zoom;
  final String addressLabel;

  const FullScreenMapPickerPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    this.addressLabel = '',
  });

  @override
  State<FullScreenMapPickerPage> createState() => _FullScreenMapPickerPageState();
}

class _FullScreenMapPickerPageState extends State<FullScreenMapPickerPage> {
  late double _lat = widget.lat;
  late double _lng = widget.lng;
  late double _zoom = widget.zoom;
  bool _loading = false;
  bool _fromGps = false;
  bool _gpsPermissionGranted = false;

  Future<void> _useGps() async {
    setState(() => _loading = true);
    final res = await LocationFlow.acquireCurrentLocation(context);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _gpsPermissionGranted = res.permissionGranted || _gpsPermissionGranted;
      if (res.position != null) {
        _lat = res.position!.lat;
        _lng = res.position!.lng;
        _zoom = 16.5;
        _fromGps = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        title: const Text('Konumu xəritədə seçin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TileMapView(
              lat: _lat,
              lng: _lng,
              zoom: _zoom,
              onCenterChanged: (c) => setState(() {
                _lat = c[0];
                _lng = c[1];
                _fromGps = false;
              }),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _roundMapButton(icon: Icons.add, tooltip: 'Yaxınlaşdır', onTap: () => setState(() => _zoom = (_zoom + 1).clamp(5.0, 18.0))),
                const SizedBox(height: 8),
                _roundMapButton(icon: Icons.remove, tooltip: 'Uzaqlaşdır', onTap: () => setState(() => _zoom = (_zoom - 1).clamp(5.0, 18.0))),
                const SizedBox(height: 8),
                _roundMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Cari mövqeyimə keç',
                  onTap: _loading ? null : _useGps,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 20, color: _kBlue),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: 54),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                ),
                child: const Text(
                  'Xəritəni sürüşdürün və ya toxunun — qırmızı marker seçdiyiniz nöqtəni göstərir.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.addressLabel.isEmpty ? 'Seçilmiş nöqtə' : widget.addressLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context, {
                        'lat': _lat,
                        'lng': _lng,
                        'zoom': _zoom,
                        'fromGps': _fromGps,
                        'gpsPermissionGranted': _gpsPermissionGranted,
                      }),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Bu konumu seç', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
