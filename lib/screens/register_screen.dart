import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

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
  File? _videoFile;
  bool _isLoading = false;
  bool _obscurePass = true;

  final Map<String, String> _roles = {
    'usta': 'Usta kimi (Xidmət təklif etmək)',
    'worker': 'Fəhlə kimi (Köməkçi işlər)',
    'customer': 'Müştəri kimi (Xidmət axtaran)',
    'seller': 'Satıcı kimi (Tikinti materialları)',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // Kamera və ya Qalereyadan 1 dəqiqəlik video seçmək
  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60), // Maksimum 1 dəqiqə
      );

      if (picked != null) {
        final file = File(picked.path);
        final sizeInMb = (await file.length()) / (1024 * 1024);

        if (sizeInMb > 40) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video ölçüsü çox böyükdür (maksimum 40 MB ola bilər)!'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _videoFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video seçilərkən xəta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Əgər usta və ya fəhlədirsə və video mütləqdirsə yoxlayırıq
    if ((_selectedRole == 'usta' || _selectedRole == 'worker') && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zəhmət olmasa, 1 dəqiqəlik iş təcrübənizi göstərən video əlavə edin!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerWithEmail(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        videoFile: _videoFile,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Qeydiyyat uğurla tamamlandı!'),
            content: const Text(
              'Təsdiq linki e-mail ünvanınıza göndərildi. Zəhmət olmasa e-mailinizi yoxlayın.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // dialoqu bağla
                  Navigator.pop(context); // login/home ekranına qayıt
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Qeydiyyat xətası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArtisan = _selectedRole == 'usta' || _selectedRole == 'worker';

    return Scaffold(
      appBar: AppBar(title: const Text('Qeydiyyat')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Yeni Hesab Yarat',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Xidmətlərdən yararlanmaq üçün qeydiyyatdan keçin',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Ad və Soyad
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ad və Soyad',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Adınızı qeyd edin' : null,
            ),
            const SizedBox(height: 14),

            // Telefon nömrəsi
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Əlaqə nömrəsi (+994...)',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Əlaqə nömrənizi qeyd edin' : null,
            ),
            const SizedBox(height: 14),

            // E-mail
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail ünvanı',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || !v.contains('@') ? 'Düzgün e-mail yazın' : null,
            ),
            const SizedBox(height: 14),

            // Şifrə
            TextFormField(
              controller: _passController,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Şifrə (ən azı 8 simvol)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) => v == null || v.length < 8 ? 'Şifrə ən azı 8 simvol olmalıdır' : null,
            ),
            const SizedBox(height: 20),

            // Rol seçimi
            const Text(
              'Hansı məqsədlə qeydiyyatdan keçirsiniz?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._roles.entries.map((entry) => RadioListTile<String>(
                  value: entry.key,
                  groupValue: _selectedRole,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  onChanged: (val) {
                    setState(() {
                      _selectedRole = val!;
                    });
                  },
                )),

            // Usta və ya fəhlədirsə 1 DƏQİQƏLİK VİDEO YÜKLƏMƏ BÖLMƏSİ
            if (isArtisan) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.video_library, color: Color(0xFF1769D2)),
                          SizedBox(width: 8),
                          Text(
                            '1 Dəqiqəlik Tanıtım Videosu',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1769D2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Görülən işləriniz və bacarıqlarınız haqqında qısa video çəkin (Maksimum 60 saniyə, 40 MB).',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      if (_videoFile != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Video seçildi (${_videoFile!.path.split(Platform.pathSeparator).last})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _videoFile = null),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickVideo(ImageSource.camera),
                                icon: const Icon(Icons.videocam),
                                label: const Text('Kamera ilə çək'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickVideo(ImageSource.gallery),
                                icon: const Icon(Icons.video_file),
                                label: const Text('Qalereyadan seç'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Təsdiq düyməsi
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Yüklənir və qeydiyyatdan keçirilir...'),
                      ],
                    )
                  : const Text('Qeydiyyatı Tamamla', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
