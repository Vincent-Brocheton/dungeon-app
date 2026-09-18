import 'package:character_app/app.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

import 'fakes/fake_auth_service.dart';

CharacterDoc _doc(String id, String name) => CharacterDoc(
      id: id,
      name: name,
      scores: PointBuy.standardArray,
      createdAt: DateTime(2026, 9, 17),
      updatedAt: DateTime(2026, 9, 17),
    );

Widget _app({InMemoryCharacterRepository? repository, FakeAuthService? auth}) =>
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
        characterRepositoryProvider
            .overrideWithValue(repository ?? InMemoryCharacterRepository()),
      ],
      child: const CharacterApp(),
    );

void main() {
  testWidgets('démarre en anonyme et liste les personnages', (tester) async {
    final repository = InMemoryCharacterRepository(
      seed: [_doc('c1', 'Brenna'), _doc('c2', 'Orsik')],
    );
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Personnages'), findsOneWidget);
    expect(find.text('Brenna'), findsOneWidget);
    expect(find.text('Orsik'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget,
        reason: 'compte anonyme');
  });

  testWidgets('crée un personnage depuis l\'achat de points', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Aucun personnage pour l\'instant'), findsOneWidget);

    await tester.tap(find.text('Nouveau personnage'));
    await tester.pumpAndSettle();
    expect(find.text('Points restants : 27 / 27'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tharivol');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(find.text('Tharivol'), findsOneWidget);
    expect(find.text('Aucun personnage pour l\'instant'), findsNothing);
  });

  testWidgets('lier un e-mail transforme le compte anonyme', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Compte anonyme'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'vincent@example.org');
    await tester.enterText(find.byType(TextField).at(1), 'secret-123');
    await tester.tap(find.text('Lier ce compte'));
    await tester.pumpAndSettle();
    // Laisse expirer le SnackBar de confirmation (timer en attente sinon).
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('vincent@example.org'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}
