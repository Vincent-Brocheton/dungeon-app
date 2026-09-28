import 'package:character_app/app.dart';
import 'package:character_app/data/admin_npc_doc.dart';
import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
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

/// Pack figé plutôt que l'asset réel : voir la même précaution dans
/// `admin_species_editor_test.dart`.
final _testPack = ContentPack(
  id: 'test-pack',
  name: 'Test',
  schemaVersion: 1,
  license: 'CC-BY-4.0',
  species: const [
    SpeciesDef(id: 'human', name: 'Human', sizeOptions: ['medium'], speed: 30),
  ],
);

Widget _app(InMemoryContentRepository<AdminNpcDoc> npcs) => ProviderScope(
  overrides: [
    authServiceProvider.overrideWithValue(
      FakeAuthService(
        initial: const AppUser(
          uid: 'me',
          isAnonymous: false,
          email: 'me@test.dev',
        ),
      ),
    ),
    characterRepositoryProvider.overrideWithValue(
      InMemoryCharacterRepository(),
    ),
    adminRepositoryProvider.overrideWithValue(
      InMemoryAdminRepository(admins: {'me'}),
    ),
    adminCharacterRepositoryProvider.overrideWithValue(
      InMemoryAdminCharacterRepository(),
    ),
    adminSpeciesRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSpeciesDoc>(),
    ),
    adminNpcRepositoryProvider.overrideWithValue(npcs),
    srdPackProvider.overrideWith((ref) async => _testPack),
  ],
  child: const CharacterApp(),
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _pickDropdown(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('créer un PNJ depuis le tableau de bord, puis le dupliquer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final npcs = InMemoryContentRepository<AdminNpcDoc>();
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(npcs));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('PNJ'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sélectionne un PNJ, ou crées-en un nouveau'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nouveau PNJ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('npc-name-field')),
      'Spectre Hurlant',
    );
    await tester.enterText(_field('npc-role-field'), 'Boss de scène');
    await _pickDropdown(tester, 'npc-species-dropdown', 'Human');
    await _pickDropdown(tester, 'npc-type-dropdown', 'Mort-vivant');
    await _pickDropdown(tester, 'npc-cr-dropdown', '3 (700 PX)');
    await tester.enterText(_field('npc-ability-Charisme'), '17');
    await tester.pump();
    expect(find.text('+3'), findsOneWidget);
    await tester.tap(find.text('+ Ajouter une action'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('actions-name-0'), 'Toucher flétrissant');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = (await npcs.watchAll().first).single;
    expect(saved.cr, '3');
    expect(saved.speciesId, 'human');
    expect(saved.type, 'Mort-vivant');
    expect(saved.abilityScores[5], 17);
    expect(saved.actions.single.name, 'Toucher flétrissant');

    // Dupliquer : nouveau brouillon pré-rempli, à enregistrer.
    await tester.tap(find.byTooltip('Dupliquer'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau contenu, pas encore enregistré'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Spectre Hurlant (copie)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final all = await npcs.watchAll().first;
    expect(all, hasLength(2));
    expect(all.map((n) => n.id).toSet(), hasLength(2));
    expect(
      all.every((n) => n.actions.single.name == 'Toucher flétrissant'),
      isTrue,
    );

    await tester.tap(find.byTooltip('Nouveau PNJ'));
    await tester.pumpAndSettle();
    expect(find.text('MORT-VIVANT'), findsOneWidget);
    expect(find.text('DP 3 · Boss de scène'), findsNWidgets(2));
  });
}
