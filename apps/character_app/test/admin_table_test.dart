import 'package:character_app/app.dart';
import 'package:character_app/data/admin_character_entry.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_admin_table_repository.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/data/in_memory_table_membership_repository.dart';
import 'package:character_app/data/table_membership.dart';
import 'package:character_app/features/admin/admin_providers.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:character_app/features/table/table_providers.dart';
import 'package:character_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

import 'fakes/fake_auth_service.dart';

Widget _app(
  InMemoryAdminTableRepository table, [
  InMemoryTableMembershipRepository? membership,
]) => ProviderScope(
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
      InMemoryAdminCharacterRepository(
        seed: [
          AdminCharacterEntry(
            ownerUid: 'joueur-1',
            doc: CharacterDoc(
              id: 'c1',
              name: 'Sera Nightwhisper',
              level: 3,
              scores: PointBuy.standardArray,
              createdAt: DateTime(2026, 9, 1),
              updatedAt: DateTime(2026, 9, 1),
            ),
          ),
        ],
      ),
    ),
    adminTableRepositoryProvider.overrideWithValue(table),
    tableMembershipRepositoryProvider.overrideWithValue(
      membership ?? InMemoryTableMembershipRepository(),
    ),
  ],
  child: const CharacterApp(),
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  testWidgets('configurer sa table : paramètres, règle maison, repos, '
      'journal ; les joueurs viennent des personnages existants', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final table = InMemoryAdminTableRepository();
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(table));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ma table'));
    await tester.pumpAndSettle();

    // Joueurs : déduits des personnages, un joueur actif.
    expect(find.text('Sera Nightwhisper'), findsOneWidget);
    expect(find.text('Niv. 3'), findsOneWidget);

    await tester.enterText(
      _field('table-name-field'),
      'Les Cendres de l\'Aube',
    );
    await tester.tap(find.text('+ Ajouter une règle'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('house-rule-0'), 'Points de destin');
    await tester.tap(find.text('Repos lent (survie)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('table-dice-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Nouvelle entrée'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('journal-title-0'), 'Séance 12');
    await tester.enterText(_field('journal-text-0'), 'Old Renn a cédé.');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final saved = (await table.watch().first)!;
    expect(saved.name, 'Les Cendres de l\'Aube');
    expect(saved.houseRules.single.name, 'Points de destin');
    expect(saved.houseRules.single.enabled, isTrue);
    expect(saved.restVariant, 'Repos lent (survie)');
    expect(saved.journal.single.title, 'Séance 12');
    expect(saved.diceRollsInApp, isFalse);

    // Rouvert : la table enregistrée est reprise.
    appRouter.go(AppRoutes.home);
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.adminTable);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Les Cendres de l\'Aube'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Points de destin'), findsOneWidget);
  });

  testWidgets('invitations : publier la table, générer et révoquer un code, '
      'retirer un joueur', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final membership = InMemoryTableMembershipRepository(
      invites: [
        TableInvite(
          code: 'OLDCODE2',
          tableName: 'X',
          createdAt: DateTime(2026),
        ),
      ],
      members: [
        TableMember(
          uid: 'joueur-1',
          inviteCode: 'OLDCODE2',
          joinedAt: DateTime(2026),
          characterName: 'Sera Nightwhisper',
          characterSummary: 'Roublard 3',
        ),
      ],
    );
    appRouter.go(AppRoutes.adminTable);
    await tester.pumpWidget(_app(InMemoryAdminTableRepository(), membership));
    await tester.pumpAndSettle();

    await tester.enterText(_field('table-name-field'), "Les Cendres de l'Aube");
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      (await membership.watchPublic().first)?.name,
      "Les Cendres de l'Aube",
    );

    await tester.tap(find.text('Générer une invitation'));
    await tester.pumpAndSettle();
    final invites = await membership.watchInvites().first;
    expect(invites, hasLength(2));
    final fresh = invites.firstWhere((i) => i.code != 'OLDCODE2');
    expect(fresh.code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
    expect(fresh.tableName, "Les Cendres de l'Aube");

    await tester.tap(find.byTooltip('Révoquer OLDCODE2'));
    await tester.pumpAndSettle();
    expect(await membership.getInvite('OLDCODE2'), isNull);

    expect(find.text('Sera Nightwhisper'), findsWidgets);
    await tester.tap(find.byTooltip('Retirer de la table'));
    await tester.pumpAndSettle();
    expect(await membership.watchMembers().first, isEmpty);
  });
}
