import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase ilkin yüklənmə: $e');
  }
  runApp(UstaGoApp(isFirebaseInitialized: isFirebaseInitialized));
}

class UstaGoApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  const UstaGoApp({super.key, this.isFirebaseInitialized = true});

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
      home: !isFirebaseInitialized
          ? const LoginScreen()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  final user = snapshot.data;
                  if (user != null) {
                    return const HomeScreen();
                  } else {
                    return const LoginScreen();
                  }
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
    );
  }
}
