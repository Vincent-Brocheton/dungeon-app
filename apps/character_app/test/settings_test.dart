import 'package:character_app/app.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/data/in_memory_table_membership_repository.dart';
import 'package:character_app/data/table_membership.dart';
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

Widget _app(
  InMemoryCharacterRepository characters, [
  InMemoryTableMembershipRepository? membership,
]) => ProviderScope(
  overrides: [
    tableMembershipRepositoryProvider.overrideWithValue(
      membership ?? InMemoryTableMembershipRepository(),
    ),
    authServiceProvider.overrideWithValue(
      FakeAuthService(initial: const AppUser(uid: 'me', isAnonymous: true)),
    ),
    characterRepositoryProvider.overrideWithValue(characters),
  ],
  child: const CharacterApp(),
);

Future<InMemoryCharacterRepository> _withDurgan() async {
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
  await characters.addNote(
    'me',
    CharacterNote(
      id: 'n1',
      characterId: 'durgan',
      text: 'La clé est chez Old Renn.',
      createdAt: _now,
    ),
  );
  return characters;
}

void main() {
  setUp(() {
    appRouter.go(AppRoutes.account);
  });

  testWidgets('réglages : version, conditions et confidentialité', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(InMemoryCharacterRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('0.1.0 (bêta)'), findsOneWidget);

    await tester.tap(find.text("Conditions d'utilisation"));
    await tester.pumpAndSettle();
    expect(find.text('1. Le service'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Voir aussi la politique de confidentialité'),
      300,
    );
    await tester.tap(find.text('Voir aussi la politique de confidentialité'));
    await tester.pumpAndSettle();
    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.text('3. Qui voit quoi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('6. Contact'), 300);
    expect(find.textContaining('59260 Lille'), findsOneWidget);
  });

  testWidgets('export : personnages et notes privées en JSON', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(await _withDurgan()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exporter mes données'));
    await tester.pumpAndSettle();
    final json =
        tester
            .widget<SelectableText>(find.byKey(const Key('export-json')))
            .data!;
    expect(json, contains('"name": "Durgan"'));
    expect(json, contains('La clé est chez Old Renn.'));
    expect(json, contains('"createdAt": "2026-10-02T00:00:00.000"'));
  });

  testWidgets('suppression : SUPPRIMER à taper, puis tout est effacé', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final characters = await _withDurgan();
    final membership = InMemoryTableMembershipRepository(
      members: [TableMember(uid: 'me', inviteCode: 'X', joinedAt: _now)],
    );
    await tester.pumpWidget(_app(characters, membership));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    FilledButton deleteButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Supprimer définitivement'),
    );
    expect(deleteButton().onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('delete-confirm-field')),
      'supprimer',
    );
    await tester.pump();
    expect(deleteButton().onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('delete-confirm-field')),
      'SUPPRIMER',
    );
    await tester.pump();
    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(await characters.watchAll('me').first, isEmpty);
    expect(characters.notes, isEmpty);
    expect(await membership.watchMember('me').first, isNull);
  });
}
