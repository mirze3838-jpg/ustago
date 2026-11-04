import 'dart:convert';
import 'dart:io';
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
    String? phone,
    File? profileImage,
  }) async {
    // İstifadəçi yaradılır
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;

    // Şəkil seçilibsə base64 formatına çeviririk (Storage tələb olunmur)
    String? photoBase64;
    if (profileImage != null) {
      try {
        final bytes = await profileImage.readAsBytes();
        photoBase64 = base64Encode(bytes);
      } catch (_) {}
    }

    // İstifadəçi məlumatları Firestore bazasına yazılır
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone?.trim() ?? '',
      'role': role,
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

  // 3. Google ilə Giriş
  Future<UserCredential?> signInWithGoogle({String defaultRole = 'customer'}) async {
    UserCredential cred;

    if (kIsWeb) {
      final GoogleAuthProvider authProvider = GoogleAuthProvider();
      cred = await _auth.signInWithPopup(authProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '628924933222-3e5m1dkln294in3alurqdkh1en52nvsb.apps.googleusercontent.com',
      );
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

  // 4. Çıxış etmək (Logout)
  Future<void> signOut() async {
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
