import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Email və Şifrə ilə Qeydiyyat
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? category,
    String? city,
    String? phone,
    Uint8List? profileImageBytes,
  }) async {
    // İstifadəçi yaradılır
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;

    // Şəkil seçilibsə base64 formatına çeviririk (Storage tələb olunmur, həm Web, həm Mobil dəstəklənir)
    String? photoBase64;
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      try {
        photoBase64 = base64Encode(profileImageBytes);
      } catch (_) {}
    }

    // İstifadəçi məlumatları Firestore bazasına yazılır
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone?.trim() ?? '',
      'role': role,
      'category': category ?? 'Tikinti',
      'city': (city != null && city.trim().isNotEmpty) ? city.trim() : 'Bakı',
      'photoBase64': photoBase64 ?? '',
      'isVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Email təsdiq linki
    try {
      await cred.user!.sendEmailVerification();
    } catch (_) {}

    return cred;
  }

  // 2. Email və Şifrə ilə Giriş (Login)
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // 3. Google ilə Giriş (Hər dəfə Gmail hesab seçimi pəncərəsini açır)
  Future<UserCredential?> signInWithGoogle({String defaultRole = 'customer'}) async {
    UserCredential cred;

    if (kIsWeb) {
      final GoogleAuthProvider authProvider = GoogleAuthProvider();
      // Web-də hər dəfə hesab seçimi dialoqunu məcbur edir
      authProvider.setCustomParameters({'prompt': 'select_account'});
      cred = await _auth.signInWithPopup(authProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      // Əvvəlki sessiyanı təmizləyirik ki, istifadəçiyə telefondakı bütün Gmail hesabları göstərilsin
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      cred = await _auth.signInWithCredential(credential);
    }

    final User? user = cred.user;

    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': user.displayName ?? 'Adsız İstifadəçi',
          'email': user.email ?? '',
          'role': defaultRole,
          'photoUrl': user.photoURL ?? '',
          'isVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return cred;
  }

  // 4. Çıxış etmək (Logout - Həm Firebase, həm də Google sessiyasını təmizləyir)
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  // 5. İstifadəçinin rolunu gətirmək
  Future<String?> getUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
