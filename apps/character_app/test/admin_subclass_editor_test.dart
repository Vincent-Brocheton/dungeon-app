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
    adminClassRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminClassDoc>(
        seed: [
          AdminClassDoc(
            id: 'fighter',
            name: 'Guerrier',
            updatedAt: DateTime(2026),
          ),
        ],
      ),
    ),
    adminSubclassRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSubclassDoc>(),
    ),
  ],
  child: const CharacterApp(),
);

void main() {
  testWidgets('créer une sous-classe l\'ajoute à la liste groupée par classe '
      'parente, et elle apparaît dans la fiche de sa classe', (tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    appRouter.go(AppRoutes.home);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sous-classes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sélectionne une sous-classe, ou crées-en une nouvelle'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nouvelle sous-classe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('subclass-name-field')),
      'Voie du Fer Sanglant',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('subclass-features-field')),
        matching: find.byType(TextField),
      ),
      'Frappe Sanglante',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Nouveau brouillon : le nom ne désigne plus que la carte enregistrée,
    // groupée sous la seule classe existante, prise par défaut comme parente.
    await tester.tap(find.byTooltip('Nouvelle sous-classe'));
    await tester.pumpAndSettle();
    expect(find.text('Voie du Fer Sanglant'), findsOneWidget);
    expect(find.text('GUERRIER'), findsOneWidget);
    expect(find.text('Choisie au niv. 3'), findsOneWidget);

    await tester.tap(find.text('Voie du Fer Sanglant'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Voie du Fer Sanglant'),
      findsOneWidget,
    );
    expect(
      find.text('Sous-classe créée pour ta table · modifiable'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Frappe Sanglante'), findsOneWidget);

    // Côté classe : le champ en lecture seule liste ses sous-classes.
    appRouter.go(AppRoutes.adminClasses);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guerrier'));
    await tester.pumpAndSettle();
    expect(find.text('Voie du Fer Sanglant'), findsOneWidget);
  });
}
