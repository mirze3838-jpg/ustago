import 'dart:async';
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
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
        category: _selectedRole == 'usta' ? _selectedCategory : null,
        city: fullCity,
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
                    onChanged: (_) => setState(() {}),
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
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
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
}
