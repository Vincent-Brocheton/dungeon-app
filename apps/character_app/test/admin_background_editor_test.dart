import 'package:character_app/app.dart';
import 'package:character_app/data/admin_background_doc.dart';
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
  backgrounds: const [
    BackgroundDef(
      id: 'acolyte',
      name: 'Acolyte',
      abilities: {Ability.intelligence, Ability.wisdom, Ability.charisma},
      originFeat: 'magic-initiate-cleric',
      skills: ['insight', 'religion'],
      tool: 'calligraphers-supplies',
    ),
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
    adminBackgroundRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminBackgroundDoc>(),
    ),
    srdPackProvider.overrideWith((ref) async => _testPack),
  ],
  child: const CharacterApp(),
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  testWidgets('créer un historique homebrew exige 3 caractéristiques ; '
      'modifier un historique SRD le garde en un seul exemplaire', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historiques'));
    await tester.pumpAndSettle();

    expect(find.text('Acolyte'), findsOneWidget);
    expect(find.text('SRD'), findsOneWidget);

    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('background-name-field')),
      'Marchand des Brumes',
    );
    await tester.enterText(
      _field('background-tool-field'),
      'Kit de déguisement',
    );
    await tester.tap(find.text('Intelligence'));
    await tester.tap(find.text('Sagesse'));
    await tester.pumpAndSettle();

    // Deux caractéristiques seulement : pas enregistré.
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Coche exactement 3 caractéristiques'), findsOneWidget);
    // Seulement dans le champ nom du brouillon, pas dans la liste.
    expect(find.text('Marchand des Brumes'), findsOneWidget);

    await tester.tap(find.text('Charisme'));
    await tester.pumpAndSettle();
    // Une 4e est refusée.
    await tester.tap(find.text('Force'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Acolyte'));
    await tester.pumpAndSettle();
    expect(find.text('Marchand des Brumes'), findsOneWidget);
    expect(find.text('Contenu SRD 5.2 · modifiable'), findsOneWidget);
    await tester.enterText(_field('background-tool-field'), 'Encre et plumes');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // L'override remplace l'entrée SRD au lieu de s'y ajouter (nouveau
    // brouillon : "Acolyte" ne désigne plus que la carte de la liste).
    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    expect(find.text('Acolyte'), findsOneWidget);

    await tester.tap(find.text('Marchand des Brumes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Historique créé pour ta table · modifiable'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Kit de déguisement'),
      findsOneWidget,
    );
    final force = tester.widget<Checkbox>(
      find.byKey(const Key('ability-Force')),
    );
    expect(force.value, isFalse);
  });
}
