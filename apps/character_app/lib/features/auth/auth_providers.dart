import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';
import 'auth_service.dart';

/// Service d'auth ; remplacé par un faux dans les tests.
final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(FirebaseAuth.instance),
);

/// Au démarrage : session anonyme si personne n'est connecté.
final authBootstrapProvider = FutureProvider<AppUser>(
  (ref) => ref.watch(authServiceProvider).ensureSignedIn(),
);

/// Utilisateur courant, mis à jour à chaque liaison / connexion / déconnexion.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// `uid` courant, ou `null` entre deux sessions.
final currentUidProvider = Provider<String?>(
  (ref) =>
      ref.watch(authStateProvider).value?.uid ??
      ref.watch(authBootstrapProvider).value?.uid,
);
