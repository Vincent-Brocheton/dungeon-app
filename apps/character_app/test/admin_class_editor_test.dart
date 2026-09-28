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
      InMemoryContentRepository<AdminClassDoc>(),
    ),
    adminSubclassRepositoryProvider.overrideWithValue(
      InMemoryContentRepository<AdminSubclassDoc>(),
    ),
  ],
  child: const CharacterApp(),
);

Future<void> _openClassEditor(WidgetTester tester) async {
  appRouter.go(AppRoutes.home);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Classes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('créer une classe homebrew lanceuse de sorts, en la '
      'sélectionnant à nouveau la version enregistrée est reprise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openClassEditor(tester);

    expect(
      find.text('Sélectionne une classe, ou crées-en une nouvelle'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('class-name-field')),
      'Artificier de Fortune',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('class-resource-field')),
        matching: find.byType(TextField),
      ),
      'Points d\'Inventivité',
    );

    // Pas lanceur par défaut : l'aide de calcul n'apparaît qu'en passant à Oui.
    expect(find.textContaining('DD de sauvegarde'), findsNothing);
    await tester.tap(find.byKey(const Key('class-caster-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('mod. Intelligence'), findsWidgets);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Nouveau brouillon : le nom ne désigne plus que la carte enregistrée.
    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    expect(find.text('Artificier de Fortune'), findsOneWidget);

    await tester.tap(find.text('Artificier de Fortune'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Artificier de Fortune'),
      findsOneWidget,
    );
    expect(
      find.text('Classe créée pour ta table · modifiable'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Points d\'Inventivité'),
      findsOneWidget,
    );
    expect(find.textContaining('DD de sauvegarde'), findsOneWidget);
  });
}
