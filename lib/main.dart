import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase ilkin yüklənmə: $e');
  }

  // Qəfil crashlərin qarşısını almaq üçün təhlükəsiz xəta idarəetməsi
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('UstaGo Flutter Error: ${details.exception}');
  };

  runApp(const UstaGoApp());
}

class UstaGoApp extends StatelessWidget {
  const UstaGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UstaGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769D2),
          primary: const Color(0xFF1769D2),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      // Tətbiq birbaşa Ana Səhifəyə açılır (Qeydiyyat məcburiyyəti yoxdur)
      // Vebdə/Kompüterdə açıldıqda mərkəzdə tam telefon ekranı görünüşü
      builder: (context, child) {
        return Container(
          color: const Color(0xFF0F172A), // Zərif tünd fon (kompüter kənarları üçün)
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480, // Standart mobil telefon eni
              ),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRect(
                  child: child ?? const SizedBox(),
                ),
              ),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
