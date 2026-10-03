import 'package:firebase_auth/firebase_auth.dart';

class AuthSnapshot {
  const AuthSnapshot({required this.uid, required this.email});
  final String uid;
  final String email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String authErrorMessage(String code) {
  switch (code) {
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    case 'invalid-email':
      return 'E-mail ou mot de passe incorrect.';
    case 'user-disabled':
      return 'Ce compte est désactivé.';
    case 'too-many-requests':
      return 'Trop de tentatives. Réessayez plus tard.';
    case 'network-request-failed':
      return 'Pas de connexion réseau.';
    default:
      return 'Connexion impossible ($code).';
  }
}

/// Deux comptes à droits identiques, pinnés par UID dans firestore.rules
/// (spec) : pas de notion de vérification d'e-mail ni de document users à
/// surveiller, contrairement à UlmGap.
abstract class AuthService {
  Stream<AuthSnapshot?> changes();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  @override
  Stream<AuthSnapshot?> changes() => _auth
      .authStateChanges()
      .map((u) => u == null ? null : AuthSnapshot(uid: u.uid, email: u.email ?? ''));

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}
