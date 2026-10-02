import 'package:character_app/app.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
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

final _now = DateTime(2026, 10, 2);

InMemoryTableMembershipRepository _membership() =>
    InMemoryTableMembershipRepository(
      public: const TablePublicInfo(
        name: "Les Cendres de l'Aube",
        world: 'Faerûn',
        nextSessionWhen: 'Samedi 20h',
      ),
      invites: [
        TableInvite(
          code: 'K7QX2M9P',
          tableName: "Les Cendres de l'Aube",
          tableWorld: 'Faerûn',
          createdAt: _now,
        ),
      ],
      members: [
        TableMember(
          uid: 'autre',
          inviteCode: 'K7QX2M9P',
          joinedAt: _now,
          characterName: 'Sera Nightwhisper',
          characterSummary: 'Roublard 3',
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  InMemoryTableMembershipRepository membership,
  String location,
) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final characters = InMemoryCharacterRepository();
  await characters.upsert(
    'me',
    CharacterDoc(
      id: 'durgan',
      name: 'Durgan',
      scores: const AbilityScores.all(10),
      createdAt: _now,
      updatedAt: _now,
    ),
  );
  appRouter.go(location);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(
          FakeAuthService(initial: const AppUser(uid: 'me', isAnonymous: true)),
        ),
        characterRepositoryProvider.overrideWithValue(characters),
        tableMembershipRepositoryProvider.overrideWithValue(membership),
        adminRepositoryProvider.overrideWithValue(InMemoryAdminRepository()),
      ],
      child: const CharacterApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('code inconnu : invitation introuvable', (tester) async {
    await _pump(tester, _membership(), AppRoutes.join('ZZZZZZZZ'));
    expect(find.text('Invitation introuvable'), findsOneWidget);
  });

  testWidgets('lien d’invitation : aperçu, personnage, bienvenue, table, '
      'puis quitter', (tester) async {
    final membership = _membership();
    // Le lien tolère minuscules et tirets.
    await _pump(tester, membership, AppRoutes.join('k7qx-2m9p'));
    expect(find.text("Les Cendres de l'Aube"), findsOneWidget);

    await tester.tap(find.text('Rejoindre la table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durgan'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue à la table !'), findsOneWidget);
    final me = await membership.watchMember('me').first;
    expect((me?.inviteCode, me?.characterId), ('K7QX2M9P', 'durgan'));

    await tester.tap(find.text('Voir la table'));
    await tester.pumpAndSettle();
    expect(find.text('Samedi 20h'), findsOneWidget);
    expect(find.text('Durgan'), findsOneWidget);
    expect(find.text('Sera Nightwhisper'), findsOneWidget);

    await tester.tap(find.text('Quitter cette table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter la table'));
    await tester.pumpAndSettle();
    expect(await membership.watchMember('me').first, isNull);
    expect(find.byKey(const Key('join-code-field')), findsOneWidget);
  });

  testWidgets('sans table : saisir le code mène à l’invitation', (
    tester,
  ) async {
    await _pump(tester, _membership(), AppRoutes.table);
    await tester.enterText(
      find.byKey(const Key('join-code-field')),
      'k7qx2m9p',
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Rejoindre la table'), findsOneWidget);
  });

  testWidgets('chronique : lire, publier une quête, filtrer, la terminer, '
      'la supprimer ; pas d’action sur l’entrée d’un autre', (tester) async {
    final membership = InMemoryTableMembershipRepository(
      members: [
        TableMember(
          uid: 'me',
          inviteCode: 'K7QX2M9P',
          joinedAt: _now,
          characterId: 'durgan',
          characterName: 'Durgan',
        ),
      ],
      chronicle: [
        ChronicleEntry(
          id: 'x',
          kind: ChronicleKind.encounter,
          title: 'Embuscade gobeline',
          authorUid: 'autre',
          authorName: 'Sera Nightwhisper',
          createdAt: _now,
        ),
      ],
    );
    await _pump(tester, membership, AppRoutes.table);
    await tester.tap(find.text('Chronique de la table'));
    await tester.pumpAndSettle();
    expect(find.text('Embuscade gobeline'), findsOneWidget);
    expect(find.text('Ajouté par Sera Nightwhisper'), findsOneWidget);
    expect(find.byType(PopupMenuButton<Object>), findsNothing);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chronicle-title')),
      'Retrouver le prêtre',
    );
    await tester.tap(find.text('Publier à la table'));
    await tester.pumpAndSettle();
    expect(find.text('QUÊTE · En cours'), findsOneWidget);
    expect(find.text('Ajouté par Durgan'), findsOneWidget);

    await tester.tap(find.text('Quêtes'));
    await tester.pumpAndSettle();
    expect(find.text('Embuscade gobeline'), findsNothing);

    await tester.tap(find.byTooltip('Actions sur Retrouver le prêtre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminée'));
    await tester.pumpAndSettle();
    expect(find.text('QUÊTE · Terminée'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions sur Retrouver le prêtre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(await membership.watchChronicle().first, hasLength(1));
  });
}
