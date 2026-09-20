import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_admin_species_repository.dart';
import 'package:character_app/data/in_memory_admin_subspecies_repository.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
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
    adminSpeciesRepositoryProvider.overrideWithValue(
      InMemoryAdminSpeciesRepository(),
    ),
    adminSubspeciesRepositoryProvider.overrideWithValue(
      InMemoryAdminSubspeciesRepository(),
    ),
    srdPackProvider.overrideWith((ref) async => _testPack),
  ],
  child: const CharacterApp(),
);

Future<void> _openSubspeciesEditor(WidgetTester tester) async {
  appRouter.go(AppRoutes.home);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sous-espèces'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'créer une sous-espèce l\'ajoute à la liste groupée par espèce parente, '
    'en la sélectionnant à nouveau la version enregistrée est reprise',
    (tester) async {
      await _openSubspeciesEditor(tester);

      expect(
        find.text('Sélectionne une sous-espèce, ou crées-en une nouvelle'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Nouvelle sous-espèce'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('subspecies-name-field')),
        'Haut-Elfe',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Reparti sur un nouveau brouillon : "Haut-Elfe" ne désigne plus que
      // la carte fraîchement enregistrée, groupée sous "HUMAN" (seule
      // espèce du pack de test, prise par défaut comme parente).
      await tester.tap(find.byTooltip('Nouvelle sous-espèce'));
      await tester.pumpAndSettle();

      expect(find.text('Haut-Elfe'), findsOneWidget);
      expect(find.text('HUMAN'), findsOneWidget);

      await tester.tap(find.text('Haut-Elfe'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Haut-Elfe'), findsOneWidget);
      expect(find.text('Nouveau contenu, pas encore enregistré'), findsNothing);
    },
  );
}
