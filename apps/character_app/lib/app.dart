import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/welcome_screen.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Racine de l'app : thème + routeur, derrière la porte d'authentification.
class CharacterApp extends StatelessWidget {
  const CharacterApp({super.key});

  static final _theme = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Nom provisoire : ne pas utiliser « Dungeons & Dragons » (marque déposée).
      title: 'Grimoire',
      theme: _theme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) => _AuthGate(child: child!),
    );
  }
}

/// Affiche Bienvenue tant qu'aucune session (anonyme ou liée) n'est ouverte.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(authStateProvider)
        .when(
          data: (user) => user == null ? const _WelcomeNavigator() : child,
          loading:
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Connexion impossible : $error'),
                  ),
                ),
              ),
        );
  }
}

/// `WelcomeScreen` précède le routeur (cf. `_AuthGate`), donc n'a pas
/// nativement de `Navigator`/`Overlay` : les champs de texte et infobulles
/// en ont besoin. Ce `Navigator` local le leur fournit.
class _WelcomeNavigator extends StatelessWidget {
  const _WelcomeNavigator();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
    );
  }
}
