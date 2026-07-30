import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Email sign up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await createWalletIfNeeded(result.user!);
    return result;
  }

  /// Email login
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await createWalletIfNeeded(result.user!);
    return result;
  }

  /// Google login (supports Web + Mobile)
  Future<UserCredential> signInWithGoogle() async {
    // Web / Chrome
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final result = await _auth.signInWithPopup(googleProvider);
      await createWalletIfNeeded(result.user!);
      return result;
    }

    // iOS / Android
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    await createWalletIfNeeded(result.user!);
    return result;
  }

  /// Apple login (mainly for iPhone)
  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      final appleProvider = AppleAuthProvider();
      final result = await _auth.signInWithPopup(appleProvider);
      await createWalletIfNeeded(result.user!);
      return result;
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    await createWalletIfNeeded(result.user!);
    return result;
  }

  /// Logout
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Create wallet document if user is new
  Future<void> createWalletIfNeeded(User user) async {
    final doc = _db.collection('users').doc(user.uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'email': user.email ?? '',
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Live wallet balance stream
  Stream<double> walletBalanceStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return 0.0;
      return (data['balance'] ?? 0).toDouble();
    });
  }

  /// Get current balance once
  Future<double> getBalance(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 0.0;
    return (data['balance'] ?? 0).toDouble();
  }
}