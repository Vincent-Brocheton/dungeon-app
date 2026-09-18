import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'router.dart';

/// Racine de l'app : thème Material 3 + routeur, derrière la porte d'authentification.
class CharacterApp extends StatelessWidget {
  const CharacterApp({super.key});

  static const _seed = Color(0xFF7B1E1E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Nom provisoire : ne pas utiliser « Dungeons & Dragons » (marque déposée).
      title: 'Grimoire',
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      routerConfig: appRouter,
      builder: (context, child) => _AuthGate(child: child!),
    );
  }
}

/// Bloque l'UI tant qu'aucun utilisateur (anonyme ou lié) n'est connecté.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authBootstrapProvider).when(
          data: (_) => child,
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
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
