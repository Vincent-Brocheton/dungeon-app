import 'dart:math';

import 'package:character_app/app.dart';
import 'package:character_app/data/admin_background_doc.dart';
import 'package:character_app/data/admin_class_doc.dart';
import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/data/in_memory_content_repository.dart';
import 'package:character_app/features/admin/admin_providers.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:character_app/providers/content_providers.dart';
import 'package:character_app/features/sheet/roll_dialog.dart';
import 'package:character_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

import 'fakes/fake_auth_service.dart';

final _now = DateTime(2026, 9, 30);

/// Renvoie les valeurs de dé (1–20) données, en boucle.
class _FixedDice implements Random {
  _FixedDice(this.faces);

  final List<int> faces;
  var _i = 0;

  @override
  int nextInt(int max) => faces[_i++ % faces.length] - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

Widget _app(
  InMemoryCharacterRepository characters, {
  List<int> dice = const [10],
}) => ProviderScope(
  overrides: [
    diceRngProvider.overrideWithValue(_FixedDice(dice)),
    authServiceProvider.overrideWithValue(
      FakeAuthService(initial: const AppUser(uid: 'me', isAnonymous: true)),
    ),
    characterRepositoryProvider.overrideWithValue(characters),
    srdPackProvider.overrideWith(
      (ref) async => const ContentPack(
        id: 'test-pack',
        name: 'Test',
        schemaVersion: 1,
        license: 'CC-BY-4.0',
      ),
    ),
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
            originFeat: 'Sauvagerie martiale',
            skills: 'Athlétisme, Intimidation',
          ),
        ],
      ),
    ),
  ],
  child: const CharacterApp(),
);

final _durgan = CharacterDoc(
  id: 'durgan',
  name: 'Durgan',
  classId: 'fighter',
  backgroundId: 'soldier',
  scores: const AbilityScores(
    strength: 17,
    dexterity: 14,
    constitution: 14,
    intelligence: 8,
    wisdom: 10,
    charisma: 12,
  ),
  equipment: const ['Épée longue'],
  gold: 14,
  createdAt: _now,
  updatedAt: _now,
);

Future<void> _enterAmount(WidgetTester tester, String tooltip, int n) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('hp-amount-field')), '$n');
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ouvrir la fiche depuis la liste, subir des dégâts, se soigner, '
      'voir le sac', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Durgan'));
    await tester.pumpAndSettle();

    expect(find.text('Guerrier 1 · Soldat'), findsOneWidget);
    // d10 + Con (+2).
    expect(find.text('12 / 12 PV'), findsOneWidget);
    expect(find.text('Athlétisme ★ (For)'), findsOneWidget);
    expect(find.text('Force ★'), findsOneWidget);

    await _enterAmount(tester, 'Subir des dégâts', 5);
    expect(find.text('7 / 12 PV'), findsOneWidget);
    await _enterAmount(tester, 'Récupérer des PV', 20);
    expect(find.text('12 / 12 PV'), findsOneWidget);
    await _enterAmount(tester, 'Subir des dégâts', 3);
    final saved = (await characters.watchAll('me').first).single;
    expect(saved.hpLost, 3);

    await tester.tap(find.text('Sac'));
    await tester.pumpAndSettle();
    expect(find.text('14 po'), findsOneWidget);
    expect(find.text('Épée longue'), findsOneWidget);
  });

  testWidgets("lancer une sauvegarde, avec avantage, et l'initiative", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters, dice: [16, 3, 12]));
    await tester.pumpAndSettle();

    // Force maîtrisée : 17 → +3, +2 de maîtrise.
    await tester.tap(find.byTooltip('Lancer : Force'));
    await tester.pumpAndSettle();
    expect(find.text('Jet de sauvegarde'), findsOneWidget);
    expect(find.text('Force, maîtrisé'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('roll-total'))).data, '21');

    // Avantage : 3 et 12 lancés, 12 retenu.
    await tester.tap(find.text('Avantage'));
    await tester.pumpAndSettle();
    expect(find.text('12 (3 écarté)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('roll-total'))).data, '17');
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    // Initiative : Dex 14 → +2, dé suivant 16.
    await tester.tap(find.text('INIT.'));
    await tester.pumpAndSettle();
    expect(find.text("Jet d'initiative"), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('roll-total'))).data, '18');
  });
}
