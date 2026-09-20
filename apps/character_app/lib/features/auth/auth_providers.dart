import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';
import 'auth_service.dart';

/// Service d'auth ; remplacé par un faux dans les tests.
final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(FirebaseAuth.instance),
);

/// Utilisateur courant. `null` tant qu'aucune session n'est ouverte —
/// c'est ce qui affiche l'écran Bienvenue. Mis à jour à chaque liaison,
/// connexion ou déconnexion.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// `uid` courant, ou `null` tant qu'aucune session n'est ouverte.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);
