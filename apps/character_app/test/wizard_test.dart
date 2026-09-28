import 'package:character_app/app.dart';
import 'package:character_app/data/admin_background_doc.dart';
import 'package:character_app/data/admin_class_doc.dart';
import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/data/in_memory_content_repository.dart';
import 'package:character_app/features/admin/admin_providers.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:character_app/providers/content_providers.dart';
import 'package:character_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

import 'fakes/fake_auth_service.dart';

final _now = DateTime(2026, 9, 28);

/// Pack figé plutôt que l'asset réel : voir la même précaution dans
/// `admin_species_editor_test.dart`.
final _testPack = ContentPack(
  id: 'test-pack',
  name: 'Test',
  schemaVersion: 1,
  license: 'CC-BY-4.0',
  species: const [
    SpeciesDef(id: 'human', name: 'Humain', sizeOptions: ['medium'], speed: 30),
  ],
);

Widget _app(InMemoryCharacterRepository characters) => ProviderScope(
  overrides: [
    authServiceProvider.overrideWithValue(
      FakeAuthService(initial: const AppUser(uid: 'me', isAnonymous: true)),
    ),
    characterRepositoryProvider.overrideWithValue(characters),
    srdPackProvider.overrideWith((ref) async => _testPack),
    adminSpeciesRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSpeciesDoc>(),
    ),
    adminClassRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminClassDoc>(
        seed: [
          AdminClassDoc(
            id: 'fighter',
            name: 'Guerrier',
            updatedAt: _now,
            hitDie: 'd10',
            savingThrows: 'Force, Constitution',
          ),
        ],
      ),
    ),
    adminBackgroundRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminBackgroundDoc>(
        seed: [
          AdminBackgroundDoc(
            id: 'soldier',
            name: 'Soldat',
            updatedAt: _now,
            abilities: const ['Force', 'Dextérité', 'Constitution'],
            originFeat: 'Attaque en Save',
          ),
        ],
      ),
    ),
  ],
  child: const CharacterApp(),
);

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.textContaining('Continuer'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('créer un personnage avec l\'assistant : classe, espèce, '
      'historique, langues, caractéristiques, alignement, finalisation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un nouveau personnage'));
    await tester.pumpAndSettle();

    expect(find.text('Choisis une classe'), findsOneWidget);
    expect(find.text('Étape 1/7'), findsOneWidget);
    await tester.tap(find.text('Guerrier'));
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('Choisis une espèce'), findsOneWidget);
    await tester.tap(find.text('Humain'));
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('Choisis un historique'), findsOneWidget);
    await tester.tap(find.text('Soldat'));
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('Choisis tes langues'), findsOneWidget);
    await tester.tap(find.text('Naine'));
    await tester.tap(find.text('Orc'));
    await tester.pumpAndSettle();
    await _continue(tester);

    // Valeurs standard réparties selon la classe, bonus du Soldat inclus.
    expect(find.text('Détermine tes caractéristiques'), findsOneWidget);
    expect(find.text('15 +2 (Soldat) = 17'), findsOneWidget);
    await _continue(tester);

    expect(find.text('Choisis un alignement'), findsOneWidget);
    await tester.tap(find.text('Loyal Bon'));
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('Finalise ta fiche'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('wizard-name-field')),
      'Durgan Ironvein',
    );
    await tester.pumpAndSettle();
    // PV max : d10 + Con (14 → +2).
    expect(find.text('12'), findsWidgets);
    await tester.tap(find.text('Créer le personnage'));
    await tester.pumpAndSettle();

    expect(find.text('Mes personnages'), findsOneWidget);
    expect(find.text('Durgan Ironvein'), findsOneWidget);
    expect(find.text('Guerrier 1 · Humain'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect(saved.classId, 'fighter');
    expect(saved.speciesId, 'human');
    expect(saved.backgroundId, 'soldier');
    expect(saved.alignment, 'Loyal Bon');
    expect(saved.languages, ['Commun', 'Naine', 'Orc']);
    expect(saved.scores.strength, 17);
    expect(saved.scores.dexterity, 14);
  });
}
