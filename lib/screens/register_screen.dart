import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/category_city_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _districtController = TextEditingController();
  final AuthService _authService = AuthService();

  String _selectedRole = 'usta';
  String _selectedCategory = 'Tikinti';
  String _selectedCity = 'Bakı';
  double _selectedLat = 40.4093;
  double _selectedLng = 49.8671;
  double _mapZoom = 13.5;
  bool _isLocationConfirmed = false;
  bool _isDraggingMap = false;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;
  bool _obscurePass = true;

  List<String> _categories = CategoryCityService.defaultCategories
      .map((c) => (c['title'] as String).replaceAll('\n', ' '))
      .toList();
  StreamSubscription<List<Map<String, dynamic>>>? _catSub;

  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<String>>? _citySub;

  final Map<String, String> _roles = {
    'usta': 'Usta kimi (Xidmət təklif etmək)',
    'worker': 'Fəhlə kimi (Köməkçi işlər)',
    'customer': 'Müştəri kimi (Xidmət axtaran)',
    'seller': 'Satıcı kimi (Tikinti materialları və mağaza)',
  };

  @override
  void initState() {
    super.initState();
    _catSub = CategoryCityService.getCategoriesStream().listen((cats) {
      if (mounted) {
        setState(() {
          _categories = cats.map((c) => (c['title'] as String).replaceAll('\n', ' ')).toList();
        });
      }
    });
    _citySub = CategoryCityService.getCitiesStream().listen((cities) {
      if (mounted) {
        setState(() {
          _cities = cities;
          if (!_cities.contains(_selectedCity) && _cities.isNotEmpty) {
            _selectedCity = _cities.first;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _citySub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _syncMapToSelectedLocation({bool markConfirmed = false}) {
    final district = _districtController.text.trim();
    final coords = CategoryCityService.getCoordinates(_selectedCity, district);
    _selectedLat = coords[0];
    _selectedLng = coords[1];
    _mapZoom = district.isNotEmpty ? 14.0 : 12.5;
    _isLocationConfirmed = markConfirmed;
  }

  // İstəyə bağlı profil şəkli seçmək
  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəkil seçilərkən xəta: $e')),
        );
      }
    }
  }

  Future<void> _showVillagePickerSheet() async {
    final villages = CategoryCityService.getVillagesForRegion(_selectedCity);
    final searchCtrl = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = CategoryCityService.normalizeAz(searchCtrl.text);
          final filtered = q.isEmpty
              ? villages
              : villages.where((v) => CategoryCityService.normalizeAz(v).contains(q)).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 18,
              right: 18,
              top: 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$_selectedCity — Kənd / Qəsəbə / Rayon seçin',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Kənd və ya qəsəbə axtar...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Siyahıda tapılmadı — yazdığınız adı istifadə edə bilərsiniz',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                if (searchCtrl.text.trim().isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.pop(ctx, searchCtrl.text.trim()),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: Text('"${searchCtrl.text.trim()}" seç'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_outlined, color: Color(0xFF1769D2)),
                                title: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
    if (selected != null && mounted) {
      setState(() {
        _districtController.text = selected;
        _syncMapToSelectedLocation();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bool requiresLocationConfirm = _selectedRole == 'usta' || _selectedRole == 'worker';
    if (requiresLocationConfirm && !_isLocationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usta və fəhlə qeydiyyatı üçün xəritədə dəqiq konumu təsdiqləmək vacibdir!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String district = _districtController.text.trim();
      final String fullCity = district.isNotEmpty ? '$_selectedCity, $district' : _selectedCity;

      await _authService.registerWithEmail(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        category: _selectedRole == 'usta'
            ? _selectedCategory
            : (_selectedRole == 'worker' ? 'Fəhlə (Köməkçi işlər)' : null),
        city: fullCity,
        lat: _selectedLat,
        lng: _selectedLng,
        profileImageBytes: _profileImageBytes,
      );

      if (mounted) {
        // Uğurlu bildiriş dialoqu
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Uğurlu Qeydiyyat!'),
              ],
            ),
            content: Text(
              'Təbriklər, ${_nameController.text.trim()}! Hesabınız uğurla yaradıldı.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Ana Səhifəyə Keç', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('email-already-in-use')) {
          errMsg = 'Bu e-mail artıq qeydiyyatdan keçib! Giriş səhifəsindən daxil olun.';
        } else if (errMsg.contains('weak-password')) {
          errMsg = 'Şifrə çox zəifdir. Ən azı 6 simvol daxil edin.';
        } else if (errMsg.contains('invalid-email')) {
          errMsg = 'E-mail ünvanı düzgün deyil.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qeydiyyat'),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: _isDraggingMap ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(24),
          children: [
            // Profil Şəkli Seçimi (İstəyə bağlı)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                    backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, size: 52, color: Color(0xFF1769D2))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1769D2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Profil şəkli əlavə et (İstəyə bağlı)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Ad və Soyad
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ad və Soyad',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Adınızı daxil edin' : null,
            ),
            const SizedBox(height: 16),

            // Rol Seçimi
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Fəaliyyət Növü',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: _roles.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 16),

            // Əgər Usta seçilibsə, İxtisas (Kateqoriya) seçimi
            if (_selectedRole == 'usta') ...[
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Usta İxtisası / Fəaliyyət Sahəsi',
                  prefixIcon: Icon(Icons.construction, color: Color(0xFF1769D2)),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Fəaliyyət Göstərdiyi / Məskunlaşdığı Şəhər, Rayon və Kənd
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: _cities.contains(_selectedCity) ? _selectedCity : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
                    decoration: const InputDecoration(
                      labelText: 'Şəhər / Rayon *',
                      prefixIcon: Icon(Icons.location_city, color: Color(0xFF1769D2)),
                    ),
                    items: _cities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCity = val;
                          _districtController.clear();
                          _syncMapToSelectedLocation();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _districtController,
                    onChanged: (_) {
                      setState(() {
                        _syncMapToSelectedLocation();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Kənd / Qəsəbə / Ərazi *',
                      hintText: 'Məs: Maştağa, Yasamal',
                      prefixIcon: const Icon(Icons.pin_drop_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Kənd və ya qəsəbə seç',
                        icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF1769D2)),
                        onPressed: _showVillagePickerSheet,
                      ),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Yaşadığınız kənd və ya ərazini qeyd edin' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: CategoryCityService.getVillagesForRegion(_selectedCity).map((village) {
                  final bool isPicked = _districtController.text.trim().toLowerCase() == village.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(
                        village,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
                          color: isPicked ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      backgroundColor: isPicked ? const Color(0xFF1769D2) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isPicked ? const Color(0xFF1769D2) : const Color(0xFFE2E8F0),
                      ),
                      onPressed: () {
                        setState(() {
                          _districtController.text = village;
                          _syncMapToSelectedLocation();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_selectedRole == 'usta' || _selectedRole == 'worker') ...[
              const SizedBox(height: 14),
              _buildRegistrationMapPickerCard(),
            ],
            const SizedBox(height: 14),

            // Telefon Nömrəsi
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobil Nömrə',
                prefixIcon: Icon(Icons.phone),
                hintText: '+994 50 123 45 67',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Əlaqə nömrənizi daxil edin' : null,
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail ünvanı',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) => !v!.contains('@') ? 'Düzgün e-mail daxil edin' : null,
            ),
            const SizedBox(height: 16),

            // Şifrə
            TextFormField(
              controller: _passController,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Şifrə (ən azı 6 simvol)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) => v!.length < 6 ? 'Ən azı 6 simvol olmalıdır' : null,
            ),
            const SizedBox(height: 30),

            // Qeydiyyat Düyməsi
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Qeydiyyatdan Keç',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Daxil ol keçidi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Artıq hesabınız var? '),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Daxil olun',
                    style: TextStyle(
                      color: Color(0xFF1769D2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationMapPickerCard() {
    final int tileZ = _mapZoom.floor().clamp(8, 17);
    final int nTiles = 1 << tileZ;
    final double worldPx = 256.0 * math.pow(2.0, _mapZoom).toDouble();
    final double tileSize = 256.0 * math.pow(2.0, _mapZoom - tileZ).toDouble();

    double lngToX(double lng) => ((lng + 180.0) / 360.0) * worldPx;
    double latToY(double lat) {
      final double rad = lat.clamp(-85.0, 85.0) * math.pi / 180.0;
      final double s = math.sin(rad);
      final double f = 0.5 - math.log((1.0 + s) / (1.0 - s)) / (4.0 * math.pi);
      return f * worldPx;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isLocationConfirmed ? const Color(0xFF10B981) : const Color(0xFFEF4444).withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(
                  _isLocationConfirmed ? Icons.verified_rounded : Icons.add_location_alt_rounded,
                  color: _isLocationConfirmed ? const Color(0xFF059669) : const Color(0xFF1769D2),
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Xəritədə Dəqiq Konumunuz (Vacib *)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => setState(() => _syncMapToSelectedLocation()),
                  icon: const Icon(Icons.my_location_rounded, size: 15),
                  label: const Text('Bölgəyə mərkəzlə', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Xəritəni sürüşdürərək işlədiyiniz dəqiq yeri mərkəz nişanının altına gətirin və təsdiqləyin.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 215,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Listener(
                onPointerDown: (_) {
                  if (!_isDraggingMap) setState(() => _isDraggingMap = true);
                },
                onPointerUp: (_) {
                  if (_isDraggingMap) setState(() => _isDraggingMap = false);
                },
                onPointerCancel: (_) {
                  if (_isDraggingMap) setState(() => _isDraggingMap = false);
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth;
                    final double h = constraints.maxHeight;
                    final double centerX = lngToX(_selectedLng);
                    final double centerY = latToY(_selectedLat);

                    final int minTx = ((centerX - w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
                    final int maxTx = ((centerX + w / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
                    final int minTy = ((centerY - h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);
                    final int maxTy = ((centerY + h / 2.0) / tileSize).floor().clamp(0, nTiles - 1);

                    final List<Widget> tileWidgets = [];
                    for (int tx = minTx; tx <= maxTx; tx++) {
                      for (int ty = minTy; ty <= maxTy; ty++) {
                        final double left = w / 2.0 + (tx * tileSize - centerX);
                        final double top = h / 2.0 + (ty * tileSize - centerY);
                        final int sub = (tx + ty) % 4;
                        final String googleTileUrl = 'https://mt$sub.google.com/vt/lyrs=m&x=$tx&y=$ty&z=$tileZ&hl=az';
                        final String arcgisUrl =
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/$tileZ/$ty/$tx';

                        tileWidgets.add(
                          Positioned(
                            key: ValueKey('reg_tile_${tileZ}_${tx}_$ty'),
                            left: left,
                            top: top,
                            width: tileSize + 0.6,
                            height: tileSize + 0.6,
                            child: Image.network(
                              googleTileUrl,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.network(
                                arcgisUrl,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final double cx = centerX - details.delta.dx;
                        final double cy = centerY - details.delta.dy;
                        final double nLng = ((cx / worldPx) * 360.0 - 180.0).clamp(43.5, 52.0);
                        final double yF = (cy / worldPx).clamp(0.01, 0.99);
                        final double n = math.pi - 2.0 * math.pi * yF;
                        final double nLat =
                            (180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)))).clamp(37.5, 42.6);
                        setState(() {
                          _selectedLat = nLat;
                          _selectedLng = nLng;
                          _isLocationConfirmed = true;
                        });
                      },
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFFEAF2F8)),
                          ...tileWidgets,
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFDC2626),
                                size: 40,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Column(
                              children: [
                                _buildMiniZoomBtn(
                                  icon: Icons.add,
                                  onTap: () => setState(() => _mapZoom = (_mapZoom + 1.0).clamp(8.0, 17.0)),
                                ),
                                const SizedBox(height: 6),
                                _buildMiniZoomBtn(
                                  icon: Icons.remove,
                                  onTap: () => setState(() => _mapZoom = (_mapZoom - 1.0).clamp(8.0, 17.0)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLocationConfirmed ? const Color(0xFF059669) : const Color(0xFF1769D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() {
                  _isLocationConfirmed = true;
                });
              },
              icon: Icon(_isLocationConfirmed ? Icons.check_circle_rounded : Icons.pin_drop_rounded, size: 18),
              label: Text(
                _isLocationConfirmed
                    ? '✓ Konum Təsdiqləndi (${_selectedLat.toStringAsFixed(4)}, ${_selectedLng.toStringAsFixed(4)})'
                    : 'Konumu Təsdiqlə (Vacib *)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniZoomBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
