import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_invocation_repository.dart';
import 'package:character_app/data/in_memory_admin_monster_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/features/admin/admin_providers.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:character_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth_service.dart';

Widget _app(InMemoryAdminMonsterRepository monsters) => ProviderScope(
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
    adminInvocationRepositoryProvider.overrideWithValue(
      InMemoryAdminInvocationRepository(),
    ),
    adminMonsterRepositoryProvider.overrideWithValue(monsters),
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
  testWidgets('créer un monstre : bloc de stats, modificateurs calculés, '
      'actions ajoutées, résumé dans la liste', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final monsters = InMemoryAdminMonsterRepository();
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(monsters));
    await tester.pumpAndSettle();
    // Onglet « Monstres » depuis un autre éditeur de compendium.
    appRouter.go(AppRoutes.adminInvocations);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monstres'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sélectionne un monstre, ou crées-en un nouveau'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('monster-name-field')),
      'Loup-garou',
    );
    await _pickDropdown(tester, 'monster-type-dropdown', 'Monstruosité');
    await tester.enterText(_field('monster-cr-field'), '3 (700 PX)');
    await tester.enterText(_field('monster-ability-Force'), '16');
    await tester.pump();
    expect(find.text('+3'), findsOneWidget);

    await tester.tap(find.text('+ Ajouter une action'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('actions-name-0'), 'Morsure');
    await tester.enterText(_field('actions-text-0'), 'Corps à corps : +5.');
    await _pickDropdown(tester, 'actions-roll-0', 'Sauvegarde');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = (await monsters.watchAll().first).single;
    expect(saved.type, 'Monstruosité');
    expect(saved.abilityScores[0], 16);
    expect(saved.actions.single.name, 'Morsure');
    expect(saved.actions.single.roll, 'Sauvegarde');

    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    expect(find.text('Loup-garou'), findsOneWidget);
    expect(find.text('FP 3 · Monstruosité'), findsOneWidget);
    expect(find.text('HOMEBREW'), findsOneWidget);

    await tester.tap(find.text('Loup-garou'));
    await tester.pumpAndSettle();
    expect(
      find.text('Monstruosité moyenne, neutre · Dangerosité 3 (700 PX)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Morsure'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
  });
}
