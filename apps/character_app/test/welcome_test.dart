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

  testWidgets('Continuer avec e-mail puis Créer un compte ouvre Personnages', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer avec e-mail'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'nouveau@example.org');
    await tester.enterText(find.byType(TextField).at(1), 'secret-123');
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Personnages'), findsOneWidget);
  });
}
