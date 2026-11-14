import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/category_city_service.dart';
import '../widgets/location_map_picker.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  // Kontrollerlər
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _streetController = TextEditingController();
  final _specialtySearchController = TextEditingController();
  final _otherRoleNoteController = TextEditingController();

  final AuthService _authService = AuthService();

  // 1. Profil Şəkli
  Uint8List? _profileImageBytes;

  // 2. Fəaliyyət Növü (Rol)
  String _selectedRole = 'usta'; // 'usta' | 'worker' | 'customer' | 'seller'
  final Map<String, Map<String, dynamic>> _roleMeta = {
    'usta': {
      'label': 'Usta',
      'desc': 'Fərdi usta xidmətləri göstərən peşəkar',
      'icon': Icons.handyman_rounded,
      'color': const Color(0xFF1769D2),
    },
    'worker': {
      'label': 'Fəhlə',
      'desc': 'Tikinti, köməkçi və fiziki işlər üzrə işçi',
      'icon': Icons.construction_rounded,
      'color': const Color(0xFFEA580C),
    },
    'customer': {
      'label': 'Müştəri',
      'desc': 'Usta, fəhlə və ya xidmət sifariş edən şəxs',
      'icon': Icons.person_rounded,
      'color': const Color(0xFF0D9488),
    },
    'seller': {
      'label': 'Satıcı',
      'desc': 'Tikinti materialları və alət mağazası sahibi',
      'icon': Icons.storefront_rounded,
      'color': const Color(0xFF7C3AED),
    },
  };

  // 3. Çoxseçimli İxtisaslar
  final Set<String> _selectedSpecialtyIds = {};
  final Map<String, String> _customSpecialtyTitles = {}; // id -> title
  final Set<String> _pendingCustomSpecialtyIds = {};
  final Set<String> _expandedGroupIds = {'grp_tikinti'}; // Standart olaraq ilk accordion açıq
  String _specialtySearchQuery = '';

  // 4. Mərhələli Ünvan
  final String _selectedCountry = 'Azərbaycan';
  String _selectedCity = 'Bakı';
  String? _selectedBakuDistrict; // Binəqədi, Xətai və s.
  String? _selectedSettlement; // Kənd və ya qəsəbə

  List<String> _cities = List.from(CategoryCityService.defaultCities);
  StreamSubscription<List<String>>? _citySub;

  // 5. Xəritə və Konum
  double _selectedLat = 40.4093;
  double _selectedLng = 49.8671;
  double _mapZoom = 13.0;
  bool _isLocationConfirmed = false;
  bool _isMapDragging = false;
  bool _isLocating = false;
  bool _gpsPermissionGranted = false;

  // 6. Konum Paylaşımı Razılığı
  bool _locationSharingConsent = false;

  // Ümumi Vəziyyət
  bool _isLoading = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _syncMapToAddress(markConfirmed: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _citySub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _streetController.dispose();
    _specialtySearchController.dispose();
    _otherRoleNoteController.dispose();
    super.dispose();
  }

  // İstifadəçi telefonun GPS parametrlərindən geri qayıtdıqda avtomatik yoxlanılır
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_gpsPermissionGranted) {
      // Lazım olarsa arxa planda GPS vəziyyətini yeniləyə bilər
    }
  }

  // ===================================================================
  // ÜNVAN VƏ XƏRİTƏ SİNXRONİZASİYASI
  // ===================================================================
  String _buildAddressLabel() {
    final parts = <String>[];
    if (_selectedCity.isNotEmpty) parts.add(_selectedCity);
    if (_selectedCity == 'Bakı' && _selectedBakuDistrict != null && _selectedBakuDistrict!.isNotEmpty) {
      parts.add(_selectedBakuDistrict!);
    }
    if (_selectedSettlement != null && _selectedSettlement!.isNotEmpty) {
      parts.add(_selectedSettlement!);
    }
    final street = _streetController.text.trim();
    if (street.isNotEmpty) parts.add(street);
    return parts.isEmpty ? 'Bakı, Azərbaycan' : parts.join(', ');
  }

  void _syncMapToAddress({bool markConfirmed = false}) {
    String subArea = '';
    if (_selectedCity == 'Bakı') {
      subArea = _selectedSettlement ?? _selectedBakuDistrict ?? '';
    } else {
      subArea = _selectedSettlement ?? '';
    }
    final coords = CategoryCityService.getCoordinates(_selectedCity, subArea);
    _selectedLat = coords[0];
    _selectedLng = coords[1];
    _mapZoom = subArea.isNotEmpty ? 14.5 : 12.5;
    if (markConfirmed) _isLocationConfirmed = true;
  }

  // Profil Şəkli Seçimi
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
        setState(() => _profileImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəkil seçilərkən xəta: $e')),
        );
      }
    }
  }

  // ===================================================================
  // GPS / KONUM ƏLDƏ ETMƏ VƏ RAZILIQ (Bölmə 6 və 7)
  // ===================================================================
  Future<void> _handleAcquireLocation() async {
    setState(() => _isLocating = true);
    final res = await LocationFlow.acquireCurrentLocation(context);
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (res.permissionGranted) _gpsPermissionGranted = true;
    });

    if (res.position != null) {
      setState(() {
        _selectedLat = res.position!.lat;
        _selectedLng = res.position!.lng;
        _mapZoom = 16.5;
        _isLocationConfirmed = true;
      });

      // Bölmə 7: Cari koordinatlar xəritədə göründükdən sonra AYRICA razılıq pəncərəsi
      final consented = await LocationFlow.askShareConsent(context);
      if (mounted) {
        setState(() {
          _locationSharingConsent = consented;
        });
        if (consented) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konumunuz təsdiqləndi və profilinizdə paylaşılacaq.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum paylaşımı ləğv edildi. Koordinatlarınız ictimai profildə göstərilməyəcək.'),
              backgroundColor: Color(0xFF475569),
            ),
          );
        }
      }
    }
  }

  Future<void> _openFullScreenMap() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMapPickerPage(
          lat: _selectedLat,
          lng: _selectedLng,
          zoom: _mapZoom,
          addressLabel: _buildAddressLabel(),
        ),
      ),
    );

    if (res != null && mounted) {
      setState(() {
        _selectedLat = (res['lat'] as num).toDouble();
        _selectedLng = (res['lng'] as num).toDouble();
        _mapZoom = (res['zoom'] as num).toDouble();
        _isLocationConfirmed = true;
        if (res['gpsPermissionGranted'] == true) _gpsPermissionGranted = true;
      });

      if (res['fromGps'] == true && !_locationSharingConsent) {
        final consented = await LocationFlow.askShareConsent(context);
        if (mounted) {
          setState(() => _locationSharingConsent = consented);
        }
      }
    }
  }

  // ===================================================================
  // YENİ İXTİSAS ƏLAVƏ ETMƏ (Bölmə 3)
  // ===================================================================
  Future<void> _showAddCustomSpecialtyDialog() async {
    final textCtrl = TextEditingController();
    String targetGroupId = 'grp_tikinti';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1769D2), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Digər İxtisas Əlavə Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Siyahıda olmayan peşənizi yazın. Əlavə etdiyiniz ixtisas administrator təsdiqindən sonra ümumi siyahıya daxil ediləcək.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: targetGroupId,
                decoration: InputDecoration(
                  labelText: 'Kateqoriya',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: CategoryCityService.specialtyGroups.map((g) {
                  return DropdownMenuItem<String>(
                    value: g['id'] as String,
                    child: Text(g['title'] as String, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => targetGroupId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'İxtisasın adı *',
                  hintText: 'Məs: Dron təmiri, Hovuz ustası...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ləğv et')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final txt = textCtrl.text.trim();
                if (txt.isEmpty) return;
                Navigator.pop(ctx, {'title': txt, 'groupId': targetGroupId});
              },
              child: const Text('Təklif et'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final title = result['title']!;
      final gId = result['groupId']!;
      final gMeta = CategoryCityService.specialtyGroups.firstWhere((g) => g['id'] == gId);
      try {
        final docId = await CategoryCityService.submitCustomSpecialty(
          title: title,
          groupId: gId,
          groupTitle: gMeta['title'] as String,
          submittedBy: _phoneController.text.trim(),
        );
        setState(() {
          _customSpecialtyTitles[docId] = title;
          _selectedSpecialtyIds.add(docId);
          _pendingCustomSpecialtyIds.add(docId);
          _expandedGroupIds.add(gId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" ixtisası profilinizə əlavə olundu və təsdiq üçün göndərildi.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===================================================================
  // QEYDİYYATIN TƏSDİQLƏNMƏSİ VƏ SUBMIT (Bölmə 8)
  // ===================================================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zəhmət olmasa tələb olunan sahələri düzgün doldurun!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Usta və Fəhlə üçün ən azı bir ixtisas tələbi
    final isWorkerOrUsta = _selectedRole == 'usta' || _selectedRole == 'worker';
    if (isWorkerOrUsta && _selectedSpecialtyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zəhmət olmasa ${_selectedRole == 'usta' ? 'usta' : 'fəhlə'} üçün ən azı bir fəaliyyət sahəsi və ya ixtisas seçin!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Seçilmiş ixtisas adları və kateqoriyaları toplanır
      final specialtyTitles = <String>[];
      final specialtyCategoryTitles = <String>{};

      for (final id in _selectedSpecialtyIds) {
        final sp = CategoryCityService.findSpecialtyById(id);
        if (sp != null) {
          specialtyTitles.add(sp['title']!);
          specialtyCategoryTitles.add(sp['groupTitle']!);
        } else if (_customSpecialtyTitles.containsKey(id)) {
          specialtyTitles.add(_customSpecialtyTitles[id]!);
        }
      }

      final legacyCategory = CategoryCityService.legacyCategoryFor(
        _selectedSpecialtyIds.toList(),
        specialtyTitles,
      );

      final districtVal = _selectedCity == 'Bakı' ? (_selectedBakuDistrict ?? '') : '';
      final settlementVal = _selectedSettlement ?? '';

      await _authService.registerWithEmail(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passController.text,
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        category: isWorkerOrUsta ? legacyCategory : (_selectedRole == 'seller' ? 'Mağaza / Satıcı' : 'Müştəri'),
        city: _selectedCity,
        district: districtVal,
        settlement: settlementVal,
        street: _streetController.text.trim(),
        lat: _selectedLat,
        lng: _selectedLng,
        specialtyIds: _selectedSpecialtyIds.toList(),
        specialties: specialtyTitles,
        specialtyCategories: specialtyCategoryTitles.toList(),
        pendingSpecialtyIds: _pendingCustomSpecialtyIds.toList(),
        gpsPermissionGranted: _gpsPermissionGranted,
        locationSharingConsent: _locationSharingConsent,
        profileImageBytes: _profileImageBytes,
        roleNote: _otherRoleNoteController.text.trim(),
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('Uğurlu Qeydiyyat!')),
              ],
            ),
            content: Text(
              'Təbriklər, ${_nameController.text.trim()}! Hesabınız uğurla yaradıldı.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Ana Səhifəyə Keç'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('email-already-in-use')) {
          msg = 'Bu e-mail artıq qeydiyyatdan keçib! Giriş səhifəsindən daxil olun.';
        } else if (msg.contains('weak-password')) {
          msg = 'Şifrə çox zəifdir. Ən azı 6 simvol daxil edin.';
        } else if (msg.contains('invalid-email')) {
          msg = 'E-mail ünvanı düzgün deyil.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  // WIDGET BUILDERLƏR
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final isWorkerOrUsta = _selectedRole == 'usta' || _selectedRole == 'worker';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Qeydiyyat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: _isMapDragging ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            // 1. Profil şəkli əlavə etmək (istəyə bağlı)
            _buildSectionCard(
              title: '1. Profil Şəkli (İstəyə bağlı)',
              icon: Icons.camera_alt_rounded,
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF1769D2).withOpacity(0.12),
                          backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                          child: _profileImageBytes == null
                              ? const Icon(Icons.person_rounded, size: 54, color: Color(0xFF1769D2))
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
                              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickProfileImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(_profileImageBytes == null ? 'Şəkil seç' : 'Şəkli dəyiş'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Ad və soyad
            _buildSectionCard(
              title: '2. Ad və Soyad *',
              icon: Icons.badge_rounded,
              child: TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Məs: Elçin Məmmədov',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad və soyadınızı daxil edin' : null,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Fəaliyyət növü (Usta, Fəhlə, Müştəri, Satıcı)
            _buildSectionCard(
              title: '3. Fəaliyyət Növü *',
              icon: Icons.work_outline_rounded,
              child: Column(
                children: _roleMeta.entries.map((e) {
                  final key = e.key;
                  final meta = e.value;
                  final isSelected = _selectedRole == key;
                  final color = meta['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? color : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(meta['icon'] as IconData, color: isSelected ? Colors.white : color, size: 22),
                      ),
                      title: Text(
                        meta['label'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        meta['desc'] as String,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Radio<String>(
                        value: key,
                        groupValue: _selectedRole,
                        activeColor: color,
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      onTap: () => setState(() => _selectedRole = key),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Fəaliyyət sahəsi və ixtisaslar (Bölmə 3)
            if (isWorkerOrUsta)
              _buildSpecialtiesSection()
            else
              _buildRoleSpecificInfoCard(),
            const SizedBox(height: 16),

            // 5. Mobil nömrə
            _buildSectionCard(
              title: '5. Mobil Nömrə *',
              icon: Icons.phone_rounded,
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+994 50 123 45 67',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Əlaqə nömrənizi daxil edin' : null,
              ),
            ),
            const SizedBox(height: 16),

            // 6. E-mail ünvanı
            _buildSectionCard(
              title: '6. E-mail Ünvanı *',
              icon: Icons.email_rounded,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'numune@mail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) => (v == null || !v.contains('@')) ? 'Düzgün e-mail daxil edin' : null,
              ),
            ),
            const SizedBox(height: 16),

            // 7. Şifrə
            _buildSectionCard(
              title: '7. Şifrə *',
              icon: Icons.lock_rounded,
              child: TextFormField(
                controller: _passController,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  hintText: 'Ən azı 6 simvol',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Şifrə ən azı 6 simvol olmalıdır' : null,
              ),
            ),
            const SizedBox(height: 16),

            // 8, 9, 10, 11, 12. Mərhələli Ünvan Bölmələri (Bölmə 4)
            _buildAddressSection(),
            const SizedBox(height: 16),

            // 13. Xəritədə konum seçimi (Bölmə 5 və 6)
            _buildMapSection(),
            const SizedBox(height: 16),

            // 14. Konumun paylaşılması üçün ayrıca razılıq (Bölmə 7)
            _buildConsentCard(),
            const SizedBox(height: 24),

            // 15. Qeydiyyatdan keç düyməsi
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Qeydiyyatdan Keç',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Giriş keçidi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Artıq hesabınız var? ', style: TextStyle(color: Color(0xFF64748B))),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Daxil olun',
                    style: TextStyle(color: Color(0xFF1769D2), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // KÖMƏKÇİ KART VƏ ACCORDION WIDGETLƏRİ
  // ===================================================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1769D2), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Fəaliyyət Sahələri — Çoxseçimli və Accordion Sistemi (Bölmə 3)
  Widget _buildSpecialtiesSection() {
    final query = _specialtySearchQuery.trim().toLowerCase();

    // Seçilmiş ixtisas etiketləri
    final selectedBadges = <Widget>[];
    for (final id in _selectedSpecialtyIds) {
      final sp = CategoryCityService.findSpecialtyById(id);
      final title = sp?['title'] ?? _customSpecialtyTitles[id] ?? id;
      selectedBadges.add(
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: Chip(
            label: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1769D2))),
            backgroundColor: const Color(0xFFEFF6FF),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1769D2)),
            onDeleted: () => setState(() => _selectedSpecialtyIds.remove(id)),
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: '4. Fəaliyyət Sahəsi və İxtisaslar *',
      icon: Icons.checklist_rtl_rounded,
      trailing: TextButton.icon(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: _showAddCustomSpecialtyDialog,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Digər əlavə et', style: TextStyle(fontSize: 11.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bir və ya bir neçə kateqoriyadan ixtisas seçə bilərsiniz. Kateqoriyaya toxunaraq alt ixtisasları açın.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // Axtarış xanası (PlayStation, Santexnik və s.)
          TextField(
            controller: _specialtySearchController,
            onChanged: (val) => setState(() => _specialtySearchQuery = val),
            decoration: InputDecoration(
              hintText: 'İxtisas axtar (məs: PlayStation, Santexnik, Motor)...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _specialtySearchController.clear();
                        setState(() => _specialtySearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 10),

          // Seçilmiş ixtisaslar etiketi
          if (_selectedSpecialtyIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seçilmiş ixtisaslar (${_selectedSpecialtyIds.length}):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedSpecialtyIds.clear()),
                        child: const Text('Hamısını sil', style: TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(children: selectedBadges),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 6 Əsas Kateqoriya üzrə Accordion
          ...CategoryCityService.specialtyGroups.map((g) {
            final gId = g['id'] as String;
            final gTitle = g['title'] as String;
            final gIcon = g['icon'] as IconData;
            final gColor = g['color'] as Color;
            final items = (g['items'] as List<Map<String, String>>);

            // Axtarış filtri
            final matchingItems = query.isEmpty
                ? items
                : items.where((it) => it['title']!.toLowerCase().contains(query)).toList();

            // Əgər axtarış zamanı bu kateqoriyada uyğunluq yoxdursa gizlət
            if (query.isNotEmpty && matchingItems.isEmpty) return const SizedBox.shrink();

            final selectedCountInGroup = items.where((it) => _selectedSpecialtyIds.contains(it['id'])).length;
            final isExpanded = _expandedGroupIds.contains(gId) || query.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedCountInGroup > 0 ? gColor : const Color(0xFFE2E8F0),
                  width: selectedCountInGroup > 0 ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    onTap: () {
                      setState(() {
                        if (_expandedGroupIds.contains(gId)) {
                          _expandedGroupIds.remove(gId);
                        } else {
                          _expandedGroupIds.add(gId);
                        }
                      });
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: gColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(gIcon, color: gColor, size: 20),
                    ),
                    title: Text(
                      gTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: selectedCountInGroup > 0 ? gColor : const Color(0xFF0F172A)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectedCountInGroup > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: gColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$selectedCountInGroup',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    ...matchingItems.map((item) {
                      final itemId = item['id']!;
                      final itemTitle = item['title']!;
                      final isChecked = _selectedSpecialtyIds.contains(itemId);

                      return CheckboxListTile(
                        dense: true,
                        value: isChecked,
                        activeColor: gColor,
                        title: Text(
                          itemTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                            color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedSpecialtyIds.add(itemId);
                            } else {
                              _selectedSpecialtyIds.remove(itemId);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Müştəri və Satıcı üçün xüsusi məlumat kartı (Bölmə 2)
  Widget _buildRoleSpecificInfoCard() {
    final isSeller = _selectedRole == 'seller';
    return _buildSectionCard(
      title: isSeller ? '4. Mağaza / Fəaliyyət Haqqında' : '4. Müştəri Məlumatı',
      icon: isSeller ? Icons.store_rounded : Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSeller
                ? 'Satıcı profilinizlə mağaza yarada, tikinti materialları və alətlər üzrə elanlar yerləşdirə bilərsiniz.'
                : 'Müştəri profilinizlə UstaGo-dakı bütün peşəkar ustaları və elanları axtarıb birbaşa əlaqə saxlaya bilərsiniz.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _otherRoleNoteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: isSeller ? 'Mağaza adı və ya qısa qeyd (istəyə bağlı)' : 'Qeyd / Tələblər (istəyə bağlı)',
              hintText: isSeller ? 'Məs: Metak Dərnəgül filialı' : 'Təmir sifarişləri üçün qeyd',
            ),
          ),
        ],
      ),
    );
  }

  // 8, 9, 10, 11, 12. Ünvan Seçimi Bölmələri (Bölmə 4)
  Widget _buildAddressSection() {
    final isBaku = _selectedCity == 'Bakı';

    // Kənd / Qəsəbə siyahısı
    List<String> settlements = [];
    if (isBaku && _selectedBakuDistrict != null && _selectedBakuDistrict!.isNotEmpty) {
      settlements = CategoryCityService.getSettlementsForBakuDistrict(_selectedBakuDistrict!);
    } else {
      settlements = CategoryCityService.getVillagesForRegion(_selectedCity);
    }

    return _buildSectionCard(
      title: '8–12. Yaşayış və Fəaliyyət Ünvanı *',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 8. Ölkə (Azərbaycan standart)
          TextFormField(
            initialValue: _selectedCountry,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: '8. Ölkə',
              prefixIcon: Icon(Icons.public_rounded),
              suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),

          // 9. Şəhər və ya Rayon
          DropdownButtonFormField<String>(
            value: _cities.contains(_selectedCity) ? _selectedCity : (_cities.isNotEmpty ? _cities.first : 'Bakı'),
            decoration: const InputDecoration(
              labelText: '9. Şəhər və ya Rayon *',
              prefixIcon: Icon(Icons.location_city_rounded),
            ),
            items: _cities.map((city) {
              return DropdownMenuItem(value: city, child: Text(city, style: const TextStyle(fontWeight: FontWeight.bold)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedCity = val;
                  _selectedBakuDistrict = null;
                  _selectedSettlement = null;
                  _syncMapToAddress();
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // 10. Bakı seçildikdə: Bakı Rayonları
          if (isBaku) ...[
            DropdownButtonFormField<String>(
              value: _selectedBakuDistrict,
              hint: const Text('Bakı rayonunu seçin'),
              decoration: const InputDecoration(
                labelText: '10. Bakı Rayonu *',
                prefixIcon: Icon(Icons.map_rounded),
              ),
              items: CategoryCityService.bakuDistricts.map((d) {
                return DropdownMenuItem(value: d, child: Text(d));
              }).toList(),
              validator: (v) {
                if (_selectedCity == 'Bakı' && (v == null || v.isEmpty)) {
                  return 'Bakı rayonunu seçin';
                }
                return null;
              },
              onChanged: (val) {
                setState(() {
                  _selectedBakuDistrict = val;
                  _selectedSettlement = null;
                  _syncMapToAddress();
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // 11. Kənd və ya Qəsəbə
          DropdownButtonFormField<String>(
            value: settlements.contains(_selectedSettlement) ? _selectedSettlement : null,
            hint: Text(isBaku ? 'Qəsəbə / Kənd / Massiv seçin' : 'Kənd / Qəsəbə seçin'),
            decoration: const InputDecoration(
              labelText: '11. Kənd və ya Qəsəbə',
              prefixIcon: Icon(Icons.holiday_village_rounded),
            ),
            items: settlements.map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSettlement = val;
                _syncMapToAddress();
              });
            },
          ),
          const SizedBox(height: 12),

          // 12. Küçə və ünvan
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(
              labelText: '12. Küçə, Bina və Ev nömrəsi',
              hintText: 'Məs: Nəcəf Nərimanov küç. ev 14',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            onChanged: (_) => _syncMapToAddress(),
          ),
        ],
      ),
    );
  }

  // 13. Xəritədə Konum Seçimi (Bölmə 5 və 6)
  Widget _buildMapSection() {
    final isWorkerOrUsta = _selectedRole == 'usta' || _selectedRole == 'worker';

    return _buildSectionCard(
      title: '13. Xəritədə Konum Seçimi ${isWorkerOrUsta ? '*' : ''}',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xəritəni sürüşdürərək dəqiq yerinizi seçin və ya "Konumu əlavə et" düyməsi ilə cari GPS mövqeyinizi tapın.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          CompactLocationMap(
            lat: _selectedLat,
            lng: _selectedLng,
            zoom: _mapZoom,
            isConfirmed: _isLocationConfirmed,
            isLoading: _isLocating,
            isRequired: isWorkerOrUsta,
            addressLabel: _buildAddressLabel(),
            onCenterChanged: (coords) {
              setState(() {
                _selectedLat = coords[0];
                _selectedLng = coords[1];
                _isLocationConfirmed = true;
              });
            },
            onZoomChanged: (z) => setState(() => _mapZoom = z),
            onUseCurrentLocation: _handleAcquireLocation,
            onOpenFullScreen: _openFullScreenMap,
            onConfirm: () {
              setState(() => _isLocationConfirmed = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Xəritədə seçilmiş mövqe təsdiqləndi!'),
                  backgroundColor: Color(0xFF059669),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onDragStateChanged: (dragging) {
              if (_isMapDragging != dragging) setState(() => _isMapDragging = dragging);
            },
          ),
        ],
      ),
    );
  }

  // 14. Konumun Paylaşılması Razılığı (Bölmə 7)
  Widget _buildConsentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _locationSharingConsent ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _locationSharingConsent ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: _locationSharingConsent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _locationSharingConsent ? Icons.verified_user_rounded : Icons.privacy_tip_outlined,
                color: _locationSharingConsent ? const Color(0xFF059669) : const Color(0xFF1769D2),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '14. Konumun Paylaşılması Üçün Razılıq',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Telefonun GPS-nin açıq olması konumunuzun paylaşılması demək deyil. '
            'Konum yalnız siz "Bəli, konumumu paylaş" təsdiqini verdikdə ictimai profildə göstərilir. '
            'İmtina etdikdə heç bir koordinat ictimai profilə göndərilmir və yaşayış ünvanınız məxfi saxlanılır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _locationSharingConsent,
            activeColor: const Color(0xFF059669),
            title: Text(
              _locationSharingConsent ? '✓ Konumumu profilimdə paylaşmağa razıyam' : 'Konumumu profilimdə paylaşmağa razı deyiləm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _locationSharingConsent ? const Color(0xFF059669) : const Color(0xFF334155),
              ),
            ),
            subtitle: Text(
              _locationSharingConsent
                  ? 'Yaxınlığınızdakı müştərilər xəritədə sizi tapa biləcək.'
                  : 'Xəritədə dəqiq koordinatınız görünməyəcək, yalnız rayon/şəhər adı görünəcək.',
              style: const TextStyle(fontSize: 11),
            ),
            onChanged: (val) async {
              if (val) {
                final confirmed = await LocationFlow.askShareConsent(context);
                if (mounted) setState(() => _locationSharingConsent = confirmed);
              } else {
                setState(() => _locationSharingConsent = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
