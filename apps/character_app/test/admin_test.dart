import 'package:character_app/app.dart';
import 'package:character_app/data/admin_character_entry.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
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
import 'package:rules_engine/rules_engine.dart';

import 'fakes/fake_auth_service.dart';

CharacterDoc _doc(String id, String name) => CharacterDoc(
  id: id,
  name: name,
  scores: PointBuy.standardArray,
  createdAt: DateTime(2026, 9, 17),
  updatedAt: DateTime(2026, 9, 17),
);

Widget _app({required bool admin}) => ProviderScope(
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
      InMemoryAdminRepository(admins: admin ? {'me'} : {}),
    ),
    adminCharacterRepositoryProvider.overrideWithValue(
      InMemoryAdminCharacterRepository(
        seed: [
          AdminCharacterEntry(ownerUid: 'autre-uid', doc: _doc('c1', 'Brenna')),
        ],
      ),
    ),
  ],
  child: const CharacterApp(),
);

void main() {
  testWidgets(
    'un admin voit l\'icône admin et la liste de tous les personnages',
    (tester) async {
      await tester.pumpWidget(_app(admin: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Brenna'), findsOneWidget);
      expect(find.textContaining('autre-uid'), findsOneWidget);
    },
  );

  testWidgets(
    'depuis le tableau de bord, une carte Compendium ouvre son écran (à venir)',
    (tester) async {
      appRouter.go(AppRoutes.home);
      await tester.pumpWidget(_app(admin: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Espèces'), findsOneWidget);
      await tester.tap(find.text('Espèces'));
      await tester.pumpAndSettle();

      expect(find.text('Bientôt disponible'), findsOneWidget);
    },
  );

  testWidgets('un utilisateur non-admin ne voit pas l\'icône admin', (
    tester,
  ) async {
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(admin: false));
    await tester.pumpAndSettle();

    expect(find.text('Mes personnages'), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
  });
}
