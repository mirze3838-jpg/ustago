import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
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
  final AuthService _authService = AuthService();

  String _selectedRole = 'usta';
  File? _profileImage;
  bool _isLoading = false;
  bool _obscurePass = true;

  final Map<String, String> _roles = {
    'usta': 'Usta kimi (Xidmət təklif etmək)',
    'worker': 'Fəhlə kimi (Köməkçi işlər)',
    'customer': 'Müştəri kimi (Xidmət axtaran)',
    'seller': 'Satıcı kimi (Tikinti materialları və mağaza)',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // İstəyə bağlı profil şəkli seçmək
  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.registerWithEmail(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        profileImage: _profileImage,
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
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
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
