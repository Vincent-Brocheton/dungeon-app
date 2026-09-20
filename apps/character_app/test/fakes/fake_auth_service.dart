import 'dart:async';

import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_service.dart';

/// Auth en mémoire : anonyme au départ, liaison instantanée.
class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? initial}) : _user = initial;

  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();
  var _counter = 0;

  void _emit() => _controller.add(_user);

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser> ensureSignedIn() async {
    _user ??= AppUser(uid: 'anon-${++_counter}', isAnonymous: true);
    _emit();
    return _user!;
  }

  @override
  Future<void> linkWithEmail(String email, String password) async {
    if (password.length < 6) {
      throw const AuthFailure('weak-password', 'Mot de passe trop faible.');
    }
    _user = AppUser(uid: _user!.uid, isAnonymous: false, email: email);
    _emit();
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    _user = AppUser(uid: 'user-$email', isAnonymous: false, email: email);
    _emit();
  }

  @override
  Future<void> linkWithGoogle() async {
    _user = AppUser(uid: _user!.uid, isAnonymous: false, displayName: 'Google');
    _emit();
  }

  @override
  Future<void> signInWithGoogle() async {
    _user = const AppUser(
      uid: 'google',
      isAnonymous: false,
      displayName: 'Google',
    );
    _emit();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _emit();
  }

  @override
  Future<void> deleteAccount() async {
    _user = null;
    _emit();
  }
}
