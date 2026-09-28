import 'package:character_app/app.dart';
import 'package:character_app/data/admin_class_doc.dart';
import 'package:character_app/data/admin_subclass_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_repository.dart';
import 'package:character_app/data/in_memory_character_repository.dart';
import 'package:character_app/data/in_memory_content_repository.dart';
import 'package:character_app/features/admin/admin_providers.dart';
import 'package:character_app/features/auth/app_user.dart';
import 'package:character_app/features/auth/auth_providers.dart';
import 'package:character_app/features/characters/characters_providers.dart';
import 'package:character_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes/fake_auth_service.dart';

Widget _app(
  InMemoryContentRepository<AdminClassDoc> classes,
  InMemoryContentRepository<AdminSubclassDoc> subclasses,
) => ProviderScope(
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
    adminClassRepositoryProvider.overrideWithValue(classes),
    adminSubclassRepositoryProvider.overrideWithValue(subclasses),
  ],
  child: const CharacterApp(),
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  testWidgets('remplir la table de progression l\'enregistre sur la classe '
      'et la sous-classe, et l\'éditeur de classes ne l\'écrase pas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final classes = InMemoryContentRepository<AdminClassDoc>(
      seed: [
        AdminClassDoc(
          id: 'fighter',
          name: 'Guerrier',
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final subclasses = InMemoryContentRepository<AdminSubclassDoc>(
      seed: [
        AdminSubclassDoc(
          id: 'champion',
          name: 'Champion',
          parentClassId: 'fighter',
          updatedAt: DateTime(2026),
        ),
      ],
    );

    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app(classes, subclasses));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tables de progression'));
    await tester.pumpAndSettle();

    // Seule classe existante, prise par défaut ; bonus de maîtrise calculé.
    expect(find.text('+6'), findsNWidgets(4));

    await tester.enterText(_field('class-feature-1'), 'Style de combat');

    await tester.tap(find.byKey(const Key('progression-subclass-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Champion').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('subclass-feature-3'), 'Critique amélioré');

    await tester.tap(find.text('Colonne de ressource'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('resource-name-0'), 'Sursauts d\'Action');
    await tester.enterText(_field('resource-0-2'), '1');

    // Niveau 4 coché par défaut : on le décoche.
    await tester.tap(find.byKey(const Key('asi-4')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    var fighter = (await classes.watchAll().first).single;
    expect(fighter.levelFeatures[0], 'Style de combat');
    expect(fighter.asiLevels, [8, 12, 16, 19]);
    expect(fighter.resourceColumns.single.name, 'Sursauts d\'Action');
    expect(fighter.resourceColumns.single.values[1], '1');
    final champion = (await subclasses.watchAll().first).single;
    expect(champion.levelFeatures[2], 'Critique amélioré');

    // Réenregistrer la classe depuis son éditeur garde la progression.
    appRouter.go(AppRoutes.adminClasses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guerrier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    fighter = (await classes.watchAll().first).single;
    expect(fighter.levelFeatures[0], 'Style de combat');
    expect(fighter.resourceColumns, hasLength(1));
  });

  testWidgets('depuis la fiche d\'une classe, la carte ouvre sa table ; au '
      'retour, réenregistrer la fiche garde la progression saisie entre-temps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final classes = InMemoryContentRepository<AdminClassDoc>(
      seed: [
        AdminClassDoc(id: 'bard', name: 'Barde', updatedAt: DateTime(2026)),
        AdminClassDoc(
          id: 'wizard',
          name: 'Magicien',
          updatedAt: DateTime(2026),
        ),
      ],
    );
    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(
      _app(classes, InMemoryContentRepository<AdminSubclassDoc>()),
    );
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.adminClasses);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Magicien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table de progression'));
    await tester.pumpAndSettle();

    // Ouverte sur Magicien (paramètre d'URL), pas sur Barde (1er alphabétique).
    expect(find.text('Magicien'), findsOneWidget);
    await tester.enterText(_field('class-feature-1'), 'Grimoire');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final wizard = (await classes.watchAll().first).firstWhere(
      (c) => c.id == 'wizard',
    );
    expect(wizard.levelFeatures[0], 'Grimoire');
  });
}
