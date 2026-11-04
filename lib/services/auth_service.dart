import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Email və Şifrə ilə Qeydiyyat
  Future<UserCredential> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? phone,
    File? videoFile,
  }) async {
    // İstifadəçi yaradılır
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;
    String? videoUrl;

    // Əgər usta video seçibsə, Firebase Storage-ə təhlükəsiz yüklənir
    if (videoFile != null && (role == 'usta' || role == 'worker')) {
      videoUrl = await uploadVideo(uid: uid, file: videoFile);
    }

    // İstifadəçi məlumatları Firestore bazasına yazılır
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone?.trim() ?? '',
      'role': role,
      'videoUrl': videoUrl ?? '',
      'isVerified': false, // Admin tərəfindən videoya baxılıb təsdiqlənəcək
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Email təsdiq linki göndərilir
    await cred.user!.sendEmailVerification();

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

  // 3. Google ilə 1-Kliklə Giriş / Qeydiyyat
  Future<UserCredential?> signInWithGoogle({String defaultRole = 'customer'}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) return null; // İstifadəçi ləğv etdi

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential cred = await _auth.signInWithCredential(credential);
    final User? user = cred.user;

    if (user != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      // Əgər ilk dəfə girirsə, bazada profil açırıq
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': user.displayName ?? 'Adsız İstifadəçi',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'role': defaultRole,
          'videoUrl': '',
          'isVerified': defaultRole == 'customer',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return cred;
  }

  // 4. Usta Videosunu Firebase Storage-ə Təhlükəsiz Yükləmək
  Future<String> uploadVideo({required String uid, required File file}) async {
    // Fayl ölçüsünü yoxlayırıq (maksimum 40 MB)
    final int sizeInBytes = await file.length();
    if (sizeInBytes > 40 * 1024 * 1024) {
      throw Exception('Video həcmi maksimum 40 MB ola bilər!');
    }

    // Serverdə xüsusi qovluğa mp4 formatında yazılır
    final ref = _storage.ref().child('artisan_videos').child(uid).child('intro_video.mp4');
    
    // Yalnız video/mp4 MIME tipinə icazə
    final metadata = SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {'uploadedBy': uid},
    );

    final uploadTask = await ref.putFile(file, metadata);
    return await uploadTask.ref.getDownloadURL();
  }

  // 5. İstifadəçi Rolunu Əldə Etmək
  Future<String?> getUserRole() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _db.collection('users').doc(u.uid).get();
    return doc.data()?['role'] as String?;
  }

  // 6. Çıxış etmək (Logout)
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
