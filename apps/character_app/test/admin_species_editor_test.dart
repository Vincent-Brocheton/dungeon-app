import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_admin_species_repository.dart';
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

/// Pack figé plutôt que l'asset réel (`loadSrd52Pack`) : plusieurs
/// `testWidgets` dans ce fichier attendent la résolution de `srdPackProvider`
/// (via `allSpeciesProvider`, qui bloque sur `.when()`) — rejouer le vrai
/// chargement d'asset à chaque test s'est avéré ne pas se résoudre de
/// manière fiable au-delà du premier `testWidgets` du fichier.
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
    srdPackProvider.overrideWith((ref) async => _testPack),
  ],
  child: const CharacterApp(),
);

Future<void> _openSpeciesEditor(WidgetTester tester) async {
  appRouter.go(AppRoutes.home);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Espèces'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('liste l\'espèce du pack SRD embarqué', (tester) async {
    await _openSpeciesEditor(tester);

    expect(find.text('Human'), findsOneWidget);
    expect(find.text('SRD'), findsOneWidget);
  });

  testWidgets(
    'créer une espèce homebrew l\'ajoute à la liste, en l\'éditant à nouveau '
    'la version enregistrée est reprise',
    (tester) async {
      await _openSpeciesEditor(tester);

      await tester.tap(find.byTooltip('Nouveau contenu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('species-name-field')),
        'Sylvanite',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Reparti sur un nouveau brouillon (champ nom vide) : "Sylvanite" ne
      // désigne plus que la carte fraîchement enregistrée dans la liste.
      await tester.tap(find.byTooltip('Nouveau contenu'));
      await tester.pumpAndSettle();

      expect(find.text('Sylvanite'), findsOneWidget);
      expect(find.text('Homebrew'), findsOneWidget);

      // Sélectionner à nouveau l'espèce reprend bien la version enregistrée,
      // pas le brouillon vide en cours.
      await tester.tap(find.text('Sylvanite'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Sylvanite'), findsOneWidget);
      expect(find.text('Nouveau contenu, pas encore enregistré'), findsNothing);
    },
  );
}
