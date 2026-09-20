import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_admin_spell_repository.dart';
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

Widget _app() => ProviderScope(
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
    adminSpellRepositoryProvider.overrideWithValue(
      InMemoryAdminSpellRepository(),
    ),
  ],
  child: const CharacterApp(),
);

Future<void> _openSpellEditor(WidgetTester tester) async {
  appRouter.go(AppRoutes.home);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sorts'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'créer un sort l\'ajoute à la liste, en le sélectionnant à nouveau la '
    'version enregistrée est reprise',
    (tester) async {
      await _openSpellEditor(tester);

      expect(
        find.text('Sélectionne un sort, ou crées-en un nouveau'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Nouveau contenu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('spell-name-field')),
        'Lame Ardente',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Reparti sur un nouveau brouillon : "Lame Ardente" ne désigne plus
      // que la carte fraîchement enregistrée dans la liste.
      await tester.tap(find.byTooltip('Nouveau contenu'));
      await tester.pumpAndSettle();

      expect(find.text('Lame Ardente'), findsOneWidget);
      expect(find.text('Homebrew'), findsOneWidget);
      expect(find.text('Niveau 1 · Évocation'), findsOneWidget);

      await tester.tap(find.text('Lame Ardente'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Lame Ardente'), findsOneWidget);
      expect(find.text('Nouveau contenu, pas encore enregistré'), findsNothing);
    },
  );
}
