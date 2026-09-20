import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth_service.dart';

Widget _app({FakeAuthService? auth}) => ProviderScope(
  overrides: [
    authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
    characterRepositoryProvider.overrideWithValue(
      InMemoryCharacterRepository(),
    ),
  ],
  child: const CharacterApp(),
);

Future<void> _openEmailForm(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuer avec e-mail'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'sans session, affiche Bienvenue ; Commencer à jouer ouvre Personnages',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Commencer à jouer'), findsOneWidget);
      expect(find.text('Personnages'), findsNothing);

      await tester.tap(find.text('Commencer à jouer'));
      await tester.pumpAndSettle();

      expect(find.text('Personnages'), findsOneWidget);
    },
  );

  testWidgets('une session existante saute directement à Personnages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        auth: FakeAuthService(
          initial: const AppUser(uid: 'deja-la', isAnonymous: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personnages'), findsOneWidget);
    expect(find.text('Commencer à jouer'), findsNothing);
  });

  testWidgets(
    'Continuer avec e-mail puis Créer un compte lie une session anonyme',
    (tester) async {
      await _openEmailForm(tester);

      await tester.enterText(
        find.byType(TextField).at(0),
        'nouveau@example.org',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret-123');
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();

      // Preuve que la liaison a bien eu lieu, pas juste une session anonyme :
      // l'icône « compte lié » et l'e-mail apparaissent dans « Mon compte ».
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.verified_user_outlined));
      await tester.pumpAndSettle();

      expect(find.text('nouveau@example.org'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    },
  );

  testWidgets(
    'Continuer avec e-mail puis Se connecter ouvre un compte existant',
    (tester) async {
      await _openEmailForm(tester);

      await tester.enterText(
        find.byType(TextField).at(0),
        'existant@example.org',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret-123');
      await tester.tap(find.text('Déjà un compte ? Se connecter'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.verified_user_outlined));
      await tester.pumpAndSettle();

      expect(find.text('existant@example.org'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
    },
  );

  testWidgets(
    'un échec après Commencer à jouer reste visible même si le formulaire '
    'a déjà été démonté (régression : erreur avalée silencieusement)',
    (tester) async {
      await _openEmailForm(tester);

      // `ensureSignedIn()` réussit d'abord (la session anonyme est créée),
      // puis `linkWithEmail` échoue sur un mot de passe trop court : c'est
      // exactement l'ordre qui démonte ce formulaire avant l'échec.
      await tester.enterText(
        find.byType(TextField).at(0),
        'nouveau@example.org',
      );
      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tester.tap(find.text('Créer un compte'));
      // Pas de pumpAndSettle : le SnackBar d'erreur se referme tout seul
      // après quelques secondes, ce qui le ferait disparaître avant
      // l'assertion si on laissait toutes les animations s'épuiser.
      await tester.pump(); // traite le tap
      await tester.pump(Duration.zero); // vide la file de microtasks
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 250)); // anim. SnackBar

      expect(find.textContaining('trop faible'), findsOneWidget);
    },
  );
}
