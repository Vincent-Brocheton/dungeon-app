import 'dart:math';

import 'package:character_app/app.dart';
import 'package:character_app/data/admin_background_doc.dart';
import 'package:character_app/data/admin_class_doc.dart';
import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/data/admin_spell_doc.dart';
import 'package:character_app/data/admin_subclass_doc.dart';
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
        weapons: [
          WeaponDef(
            id: 'epee-longue',
            name: 'Épée longue',
            diceCount: 1,
            diceSides: 8,
            damageType: 'tranchant',
          ),
        ],
        armors: [
          ArmorDef(
            id: 'cotte-de-mailles',
            name: 'Cotte de mailles',
            baseAc: 16,
            category: ArmorCategory.heavy,
          ),
          ArmorDef(
            id: 'bouclier',
            name: 'Bouclier',
            baseAc: 2,
            category: ArmorCategory.shield,
          ),
        ],
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
          AdminClassDoc(
            id: 'cleric',
            name: 'Clerc',
            updatedAt: _now,
            savingThrows: 'Sagesse, Charisme',
            spellcaster: true,
            spellcastingAbility: 'Sagesse',
          ),
        ],
      ),
    ),
    adminSubclassRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSubclassDoc>(
        seed: [
          AdminSubclassDoc(
            id: 'champion',
            name: 'Champion',
            parentClassId: 'fighter',
            updatedAt: _now,
            level: 3,
            levelFeatures: const ['', '', 'Critique amélioré'],
          ),
        ],
      ),
    ),
    adminSpellRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSpellDoc>(
        seed: [
          AdminSpellDoc(
            id: 'benediction',
            name: 'Bénédiction',
            updatedAt: _now,
            school: 'Enchantement',
            duration: "Concentration, jusqu'à 1 minute",
            classes: 'Clerc, Paladin',
          ),
          AdminSpellDoc(
            id: 'flamme-sacree',
            name: 'Flamme sacrée',
            updatedAt: _now,
            level: 0,
            classes: 'Clerc',
          ),
          AdminSpellDoc(
            id: 'boule-de-feu',
            name: 'Boule de feu',
            updatedAt: _now,
            level: 3,
            classes: 'Ensorceleur, Magicien',
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
  inventory: const [InventoryItem(name: 'Épée longue')],
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
    expect(find.text('14 po · 0 pa · 0 pc'), findsOneWidget);
    expect(find.text('Épée longue'), findsOneWidget);
  });

  testWidgets('le dernier jet affiché rejoint l’historique à la fermeture', (
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

    await tester.tap(find.byTooltip('Lancer : Force'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avantage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    final roll = characters.rolls.single;
    expect(
      (roll.label, roll.detail, roll.total),
      (
        'Jet de sauvegarde · Force, maîtrisé',
        '2d20 avantage — 12 gardé (3 écarté) (+5)',
        17,
      ),
    );

    appRouter.go(AppRoutes.rolls('durgan'));
    await tester.pumpAndSettle();
    expect(find.text('Historique de mes jets'), findsOneWidget);
    expect(find.text('Jet de sauvegarde · Force, maîtrisé'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
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

  testWidgets('onglet Actions : attaquer avec une arme, dégâts doublés sur '
      'un 20 naturel', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    // Attaque 16, dégâts 5 ; puis attaque 20, dégâts 4 et 6.
    await tester.pumpWidget(_app(characters, dice: [16, 5, 20, 4, 6]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    // Force 17 → +3, maîtrise +2.
    expect(find.text('Épée longue'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('1d8+3 tranchant'), findsOneWidget);

    Text total(String key) => tester.widget<Text>(find.byKey(Key(key)));
    await tester.tap(find.byTooltip('Attaquer : Épée longue'));
    await tester.pumpAndSettle();
    expect(total('roll-total').data, '21');
    expect(total('damage-total').data, '8');

    await tester.tap(find.text('Relancer'));
    await tester.pumpAndSettle();
    expect(total('roll-total').data, '25');
    expect(find.text('DÉGÂTS — COUP CRITIQUE, DÉS DOUBLÉS'), findsOneWidget);
    expect(total('damage-total').data, '13');
  });

  testWidgets('repos court avec un dé de vie, puis repos long', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan.copyWith(hpLost: 10, tempHp: 3));
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters, dice: [6]));
    await tester.pumpAndSettle();
    expect(find.text('2 / 12 PV'), findsOneWidget);
    expect(find.text('Dés de vie 1d10 (0 utilisé)'), findsOneWidget);

    // d10 = 6, Con +2.
    await tester.tap(find.text('Repos court'));
    await tester.pumpAndSettle();
    expect(find.text('1d10 + 2 (≈ 8 PV)'), findsOneWidget);
    await tester.tap(find.text('Prendre un repos court'));
    await tester.pumpAndSettle();
    expect(find.text('10 / 12 PV'), findsOneWidget);
    expect(find.text('+8 PV (dés : 6)'), findsOneWidget);
    expect(find.text('Dés de vie 1d10 (1 utilisé)'), findsOneWidget);

    // Plus aucun dé : le repos court ne peut rien dépenser.
    await tester.tap(find.text('Repos court'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('hit-dice-count'))).data,
      '0',
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repos long'));
    await tester.pumpAndSettle();
    expect(find.text('10 → 12 (complet)'), findsOneWidget);
    await tester.tap(find.text('Prendre un repos long'));
    await tester.pumpAndSettle();
    expect(find.text('12 / 12 PV'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect((saved.hpLost, saved.tempHp, saved.hitDiceUsed), (0, 0, 0));
  });

  testWidgets(
    'sorts : préparer depuis le grimoire, lancer, emplacement dépensé',
    (tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final characters = InMemoryCharacterRepository();
      await characters.upsert(
        'me',
        _durgan.copyWith(classId: 'cleric', name: 'Kaelen'),
      );
      appRouter.go(AppRoutes.character('durgan'));
      await tester.pumpWidget(_app(characters));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sorts'));
      await tester.pumpAndSettle();
      // Sagesse 10 → +0, maîtrise +2 : attaque +2, DD 10.
      expect(find.text('Sagesse'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(
        find.text('Aucun sort préparé : choisis-les dans le grimoire.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Voir le grimoire →'));
      await tester.pumpAndSettle();
      expect(find.text('Liste de sorts de Clerc'), findsOneWidget);
      expect(find.text('Flamme sacrée'), findsOneWidget);
      expect(find.text('Boule de feu'), findsNothing);
      expect(
        find.text('Niv. 1 · Enchantement · concentration'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Préparer Bénédiction'));
      await tester.pumpAndSettle();
      expect(find.text('1 sort préparé'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bénédiction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lancer ce sort (niveau 1)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bénédiction lancé · emplacement de niveau 1 dépensé'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Récupérer un emplacement de niveau 1'),
        findsOneWidget,
      );
      final saved = (await characters.watchAll('me').first).single;
      expect(saved.spellIds, ['benediction']);
      expect(saved.slotsUsed, [1]);
    },
  );

  testWidgets(
    'conditions et épuisement appliqués aux jets, inspiration dépensée',
    (tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final characters = InMemoryCharacterRepository();
      await characters.upsert('me', _durgan);
      appRouter.go(AppRoutes.character('durgan'));
      await tester.pumpWidget(_app(characters, dice: [16, 3, 12, 9, 15]));
      await tester.pumpAndSettle();
      expect(find.text('Aucune condition.'), findsOneWidget);

      await tester.tap(find.text('+ Gérer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empoisonné'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip("Un niveau d'épuisement de plus"),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("Un niveau d'épuisement de plus"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Empoisonné'), findsOneWidget);
      expect(find.text('Épuisement (niveau 1)'), findsOneWidget);

      // Athlétisme +5, désavantage (Empoisonné) : 16 et 3, 3 retenu ; -2.
      await tester.tap(find.byTooltip('Lancer : Athlétisme'));
      await tester.pumpAndSettle();
      expect(find.text('Désavantage — Empoisonné.'), findsOneWidget);
      expect(find.text('3 (16 écarté)'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('roll-total'))).data,
        '6',
      );
      expect(find.text("Dépenser l'Inspiration héroïque"), findsNothing);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Pas d'Inspiration héroïque"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Noter l'inspiration"));
      await tester.pumpAndSettle();
      expect(find.text('Inspiration héroïque disponible'), findsOneWidget);

      // Sauvegarde de Force +5 (pas de désavantage) : 12 - 2 = 15 ; puis
      // l'inspiration donne l'avantage : 9 et 15, 15 retenu → 18.
      await tester.tap(find.byTooltip('Lancer : Force'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('roll-total'))).data,
        '15',
      );
      await tester.tap(find.text("Dépenser l'Inspiration héroïque"));
      await tester.pumpAndSettle();
      expect(
        find.text('Inspiration héroïque dépensée — avantage.'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('roll-total'))).data,
        '18',
      );
      final saved = (await characters.watchAll('me').first).single;
      expect(saved.conditions, ['poisoned']);
      expect(saved.exhaustion, 1);
      expect(saved.heroicInspiration, isFalse);
    },
  );

  testWidgets('sac : ajouter et équiper une armure et un bouclier, la CA '
      'suit ; objet personnalisé', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();
    // Sans armure : 10 + Dex (+2).
    expect(find.text('12'), findsWidgets);

    Future<void> add(String query, String pick) async {
      await tester.tap(find.text('Ajouter un objet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-item-field')), query);
      await tester.pumpAndSettle();
      await tester.tap(find.text(pick));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Sac'));
    await tester.pumpAndSettle();
    await add('cotte', 'Cotte de mailles');
    await add('bouc', 'Bouclier');
    await add('Corde', 'Objet personnalisé : Corde');
    expect(find.text('Armure · CA 16'), findsOneWidget);
    expect(find.text('Corde'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equip-Cotte de mailles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equip-Bouclier')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Un Corde de moins'));
    await tester.pumpAndSettle();
    expect(find.text('Corde'), findsNothing);

    await tester.tap(find.text('Résumé'));
    await tester.pumpAndSettle();
    // Cotte de mailles (16, lourde : sans Dex) + bouclier (+2).
    expect(find.text('18'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect(
      [for (final i in saved.inventory) (i.name, i.equipped)],
      [('Épée longue', false), ('Cotte de mailles', true), ('Bouclier', true)],
    );
  });

  testWidgets('notes : personnalité enregistrée, même en changeant '
      "d'onglet ; note de session privée ajoutée puis supprimée", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-field-Idéal')),
      'Charité.',
    );
    await tester.pump(const Duration(seconds: 1));
    // Tapé puis onglet quitté aussitôt : enregistré quand même.
    await tester.enterText(
      find.byKey(const Key('note-field-Lien')),
      'Mon clan.',
    );
    await tester.tap(find.text('Résumé'));
    await tester.pumpAndSettle();
    var saved = (await characters.watchAll('me').first).single;
    expect(saved.ideal, 'Charité.');
    expect(saved.bond, 'Mon clan.');

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Charité.'), findsOneWidget);
    await tester.tap(find.text('+ Nouvelle note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-note-field')),
      'La clé est chez Old Renn.',
    );
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('La clé est chez Old Renn.'), findsOneWidget);
    expect(characters.notes.single.characterId, 'durgan');

    await tester.tap(find.byTooltip('Supprimer la note'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune note pour le moment.'), findsOneWidget);
    expect(characters.notes, isEmpty);
    saved = (await characters.watchAll('me').first).single;
    expect(saved.ideal, 'Charité.');
  });

  testWidgets('à 0 PV : jets contre la mort, dégâts, 20 naturel, mort '
      'instantanée, soins', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters, dice: [14, 20]));
    await tester.pumpAndSettle();
    Future<DeathSaves> saves() async =>
        (await characters.watchAll('me').first).single.deathSaves;

    await _enterAmount(tester, 'Subir des dégâts', 12);
    expect(find.text('0 / 12 PV'), findsOneWidget);
    expect(find.text('Mourant — Inconscient'), findsOneWidget);

    await tester.tap(find.text('Jet contre la mort (1d20, DD 10)'));
    await tester.pumpAndSettle();
    expect(find.text('Réussite (14 ≥ DD 10)'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    // Blessé à 0 PV : un échec, la réussite reste.
    await _enterAmount(tester, 'Subir des dégâts', 3);
    expect(((await saves()).successes, (await saves()).failures), (1, 1));

    await tester.tap(find.text('Jet contre la mort (1d20, DD 10)'));
    await tester.pumpAndSettle();
    expect(
      find.text('20 naturel — 1 PV, tu reprends conscience !'),
      findsOneWidget,
    );
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12 PV'), findsOneWidget);
    expect(find.text('Mourant — Inconscient'), findsNothing);

    // 30 dégâts à 1 PV : reliquat 29 ≥ 12 PV max.
    await _enterAmount(tester, 'Subir des dégâts', 30);
    expect(find.text('Mort'), findsOneWidget);
    expect(find.text('Jet contre la mort (1d20, DD 10)'), findsNothing);

    await _enterAmount(tester, 'Récupérer des PV', 5);
    expect(find.text('5 / 12 PV'), findsOneWidget);
    expect(((await saves()).successes, (await saves()).failures), (0, 0));
  });

  testWidgets('monter du niveau 3 au 4 : PV au dé, sous-classe, +2 en '
      'Force', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan.copyWith(level: 3));
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters, dice: [7]));
    await tester.pumpAndSettle();
    // d10 + 2, puis 2 niveaux à (6 + 2).
    expect(find.text('28 / 28 PV'), findsOneWidget);

    await tester.tap(find.text('Monter au niveau 4'));
    await tester.pumpAndSettle();
    expect(find.text('Niveau 3 → 4'), findsOneWidget);
    expect(find.text('Étape 1/4'), findsOneWidget);
    await tester.tap(find.text('Lancer 1d10'));
    await tester.pumpAndSettle();
    expect(find.text('Lancé : 7'), findsOneWidget);
    await tester.tap(find.text('Continuer · Aptitudes'));
    await tester.pumpAndSettle();

    // Sous-classe due au niveau 3 et pas encore choisie : obligatoire.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continuer · Amélioration'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Champion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer · Amélioration'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Force 17'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer · Récapitulatif'));
    await tester.pumpAndSettle();
    expect(find.text('28 → 37'), findsOneWidget);
    expect(find.text('17 → 19'), findsOneWidget);
    expect(find.text('Champion'), findsWidgets);
    await tester.tap(find.text('Confirmer la montée de niveau'));
    await tester.pumpAndSettle();

    expect(find.text('Guerrier (Champion) 4 · Soldat'), findsOneWidget);
    expect(find.text('37 / 37 PV'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect(saved.level, 4);
    expect(saved.hpGains, [6, 6, 7]);
    expect(saved.scores.strength, 19);
    expect(saved.subclassId, 'champion');
  });

  testWidgets('bourse : conversions, mouvement refusé puis accepté', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan.copyWith(silver: 12, copper: 25));
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sac'));
    await tester.pumpAndSettle();
    expect(find.text('14 po · 12 pa · 25 pc'), findsOneWidget);
    await tester.tap(find.text('Gérer →'));
    await tester.pumpAndSettle();
    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    expect(text('purse-total'), '≈ 15,45 po');

    await tester.tap(find.byKey(const Key('convert-copper')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('convert-silver')));
    await tester.pumpAndSettle();
    expect(
      (text('coin-gold'), text('coin-silver'), text('coin-copper')),
      ('15', '4', '5'),
    );
    expect(text('purse-total'), '≈ 15,45 po');

    await tester.tap(find.text('Ajouter un mouvement manuel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('movement-label')), 'Amende');
    await tester.enterText(find.byKey(const Key('movement-amount')), '-20');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Pas assez de pièces : 15 po.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('movement-amount')), '+5');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(text('coin-gold'), '20');
    expect(find.text('Amende'), findsOneWidget);
    expect(find.text('+ 5 po'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect(saved.moneyLog.single.amount, 5);
  });

  testWidgets('décès confirmé : mémorial, « Décédé » dans la liste, puis '
      'résurrection', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert(
      'me',
      _durgan.copyWith(hpLost: 12, deathSaves: const DeathSaves(failures: 3)),
    );
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(characters));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durgan'));
    await tester.pumpAndSettle();
    expect(find.text('Mort'), findsOneWidget);

    await tester.tap(find.text('Confirmer le décès'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('epitaph-field')),
      'Tombé face au chef gobelin.',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmer le décès'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Décédé — '), findsOneWidget);
    expect(find.text('Tombé face au chef gobelin.'), findsOneWidget);
    expect(find.text('Points de vie max.'), findsOneWidget);
    expect(find.byTooltip('Subir des dégâts'), findsNothing);

    await tester.tap(find.text('Retour à Mes personnages'));
    await tester.pumpAndSettle();
    expect(find.text('Guerrier 1 · Décédé'), findsOneWidget);

    await tester.tap(find.text('Durgan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résurrection (revient à 1 PV)'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12 PV'), findsOneWidget);
    final saved = (await characters.watchAll('me').first).single;
    expect(saved.isDead, isFalse);
    expect(saved.deathFailures, 0);
  });

  testWidgets('jet libre : 2d6 + 3', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = InMemoryCharacterRepository();
    await characters.upsert('me', _durgan);
    appRouter.go(AppRoutes.character('durgan'));
    await tester.pumpWidget(_app(characters, dice: [4, 2]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jet libre — un ou plusieurs dés'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nombre de dés : plus'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Modificateur : plus'));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lancer 2d6 +3'));
    await tester.pumpAndSettle();
    expect(find.text('4 + 2 = 6'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('free-total'))).data, '9');
  });
}
