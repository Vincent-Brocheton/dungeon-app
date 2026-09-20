import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_user.dart';

/// Erreur d'authentification lisible par l'utilisateur.
class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Contrat d'authentification : anonyme d'abord, liaison ensuite.
abstract class AuthService {
  /// Émet à chaque changement d'utilisateur, y compris lors d'une liaison.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Garantit un utilisateur : le courant, sinon une session anonyme.
  Future<AppUser> ensureSignedIn();

  /// Lie le compte anonyme courant à un e-mail + mot de passe (même uid).
  Future<void> linkWithEmail(String email, String password);

  /// Connexion à un compte existant (l'anonyme courant est abandonné).
  Future<void> signInWithEmail(String email, String password);

  /// Lie le compte anonyme courant à Google (web : popup ; Android : voir README).
  Future<void> linkWithGoogle();

  /// Connexion Google à un compte existant.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Supprime l'utilisateur. Les données doivent être effacées avant.
  Future<void> deleteAccount();
}

/// Implémentation Firebase Auth.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return _toAppUser(current)!;
    final credential = await _guard(_auth.signInAnonymously);
    return _toAppUser(credential.user)!;
  }

  @override
  Future<void> linkWithEmail(String email, String password) async {
    final user = _requireUser();
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _guard(() => user.linkWithCredential(credential));
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<void> linkWithGoogle() async {
    final user = _requireUser();
    if (!kIsWeb) throw _googleUnsupported;
    await _guard(() => user.linkWithPopup(GoogleAuthProvider()));
  }

  @override
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) throw _googleUnsupported;
    await _guard(() => _auth.signInWithPopup(GoogleAuthProvider()));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() => _guard(() => _requireUser().delete());

  static const _googleUnsupported = AuthFailure(
    'google-not-configured',
    'Connexion Google disponible sur le web pour l\'instant. '
        'Sur Android, ajoute google_sign_in (voir README).',
  );

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('no-user', 'Aucun utilisateur connecté.');
    }
    return user;
  }

  AppUser? _toAppUser(User? user) =>
      user == null
          ? null
          : AppUser(
            uid: user.uid,
            isAnonymous: user.isAnonymous,
            email: user.email,
            displayName: user.displayName,
          );

  /// Traduit les codes Firebase en messages utilisateur.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code, _message(e.code));
    }
  }

  static String _message(String code) => switch (code) {
    'email-already-in-use' || 'credential-already-in-use' =>
      'Cet e-mail est déjà rattaché à un compte. Utilise « Se connecter ».',
    'invalid-email' => 'Adresse e-mail invalide.',
    'weak-password' => 'Mot de passe trop faible (6 caractères minimum).',
    'wrong-password' ||
    'user-not-found' ||
    'invalid-credential' => 'E-mail ou mot de passe incorrect.',
    'requires-recent-login' =>
      'Par sécurité, reconnecte-toi avant de supprimer le compte.',
    'network-request-failed' => 'Pas de réseau : réessaie plus tard.',
    'popup-closed-by-user' => 'Connexion annulée.',
    _ => 'Erreur d\'authentification ($code).',
  };
}
