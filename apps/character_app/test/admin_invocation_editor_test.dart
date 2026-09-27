import 'package:character_app/app.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:character_app/data/in_memory_admin_invocation_repository.dart';
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
    adminInvocationRepositoryProvider.overrideWithValue(
      InMemoryAdminInvocationRepository(),
    ),
  ],
  child: const CharacterApp(),
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _pickDropdown(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('créer une manifestation résume ses prérequis dans la liste, '
      'en la sélectionnant à nouveau la version enregistrée est reprise', (
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
    await tester.tap(find.text('Manifestations occultes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sélectionne une manifestation, ou crées-en une nouvelle'),
      findsOneWidget,
    );

    // Sans prérequis.
    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invocation-name-field')),
      'Pacte de la lame',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Niveau 5 + prérequis texte, répétable.
    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invocation-name-field')),
      'Lame assoiffée',
    );
    await _pickDropdown(tester, 'invocation-level-dropdown', '5');
    await tester.enterText(
      _field('invocation-prerequisites-field'),
      'Pacte de la lame',
    );
    await _pickDropdown(tester, 'invocation-repeatable-dropdown', 'Oui');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nouveau contenu'));
    await tester.pumpAndSettle();
    expect(find.text('Sans prérequis'), findsOneWidget);
    expect(find.text('Niv. 5 · Pacte de la lame'), findsOneWidget);

    await tester.tap(find.text('Lame assoiffée'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Lame assoiffée'), findsOneWidget);
    expect(
      find.text('Manifestation créée pour ta table · modifiable'),
      findsOneWidget,
    );
    expect(find.text('Oui'), findsOneWidget);
  });
}
