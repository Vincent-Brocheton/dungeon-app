# Rôles admin/user — fondations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distinguer un rôle admin d'un rôle user, donner à l'admin une vue en lecture seule sur les personnages de tous les utilisateurs, sans toucher au contenu de règles (classes/dons/sorts — sous-projet 2, hors scope).

**Architecture:** Le rôle admin est déterminé par l'existence d'un document `admins/{uid}` dans Firestore (jamais un champ sur `users/{uid}`, que le propriétaire peut déjà écrire). Les règles Firestore ajoutent une fonction `isAdmin()` qui autorise la lecture cross-utilisateurs sur `users/{uid}/characters/{id}`. Côté app, deux nouveaux dépôts (`AdminRepository`, `AdminCharacterRepository`) suivent exactement le pattern `CharacterRepository` existant (interface + implémentation Firestore + implémentation en mémoire pour les tests), exposés par des providers Riverpod, et un écran `AdminCharactersScreen` liste tous les personnages via `collectionGroup('characters')`.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, cloud_firestore, firebase_auth — tout déjà en place, aucune nouvelle dépendance.

**Spec:** `docs/superpowers/specs/2026-09-18-admin-roles-design.md`

## Global Constraints

- Rôle admin = existence d'un document `admins/{uid}` (pas de champ `role` sur `users/{uid}`).
- Attribution du rôle admin : manuelle dans la console Firestore uniquement — aucune UI ni script d'app pour promouvoir un admin (hors scope de ce plan).
- Écran admin en lecture seule : aucune action d'écriture sur les personnages d'autrui.
- Filtrage/tri des personnages côté admin fait en mémoire (Dart), pas via `where`/`orderBy` Firestore — évite de déclarer un index composite.
- Comptes de test déjà créés : admin `k7noHdMOBnT7a0LIB7jxxFG6jTt1` (`admin@dungeon-app.test`), user `ewcOxFBrNfNPy5A0sjvYq20pvml2` (`user@dungeon-app.test`). Mots de passe dans `pass.txt` (racine du repo, ignoré par git).
- Projet Firebase : `dungeon-app-353e2`.
- Si le dépôt n'est pas encore un dépôt git (`git init` jamais lancé), lance-le avant la Task 1 : les étapes de commit de ce plan supposent un dépôt existant.

---

## Task 1: Règles Firestore — collection `admins` et lecture cross-utilisateurs

**Files:**
- Modify: `infra/firebase/firestore.rules`
- Modify: `README.md` (section `## Firebase`, ajout d'un point 6)

**Interfaces:**
- Consumes: rien (fondation).
- Produces: fonction de règle `isAdmin()`, collection `admins/{uid}` (lecture par le propriétaire ou un admin, écriture toujours fermée côté client), lecture admin sur `users/{uid}/characters/{characterId}`. Les tasks suivantes (données/UI) s'appuient sur ce comportement mais n'importent rien directement d'ici — c'est un contrat Firestore, pas du Dart.

- [ ] **Step 1: Modifier les règles Firestore**

Remplace le contenu de `infra/firebase/firestore.rules` par :

```
rules_version = '2';

// Modèle : users/{uid}/characters/{characterId}
// Un utilisateur (anonyme ou lié) ne voit et n'écrit que son propre sous-arbre.
// admins/{uid} : l'existence du document = rôle admin (lecture seule sur les personnages).
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    function isAdmin() {
      return request.auth != null
        && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    function validCharacter() {
      let d = request.resource.data;
      return d.keys().hasAll(['schemaVersion', 'name', 'updatedAt'])
        && d.schemaVersion is int && d.schemaVersion >= 1
        && d.name is string && d.name.size() > 0 && d.name.size() <= 80
        && d.updatedAt is timestamp
        && (!('deletedAt' in d) || d.deletedAt == null || d.deletedAt is timestamp)
        && (!('level' in d) || (d.level is int && d.level >= 1 && d.level <= 20));
    }

    match /admins/{uid} {
      allow read: if isOwner(uid) || isAdmin();
      allow write: if false;
    }

    match /users/{uid} {
      allow read, write: if isOwner(uid);

      match /characters/{characterId} {
        allow read: if isOwner(uid) || isAdmin();
        allow delete: if isOwner(uid);
        allow create, update: if isOwner(uid) && validCharacter();
      }
    }

    // Tout le reste est fermé.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 2: Déployer les règles**

Run: `cd infra/firebase && firebase deploy --only firestore:rules`
Expected: `+  Deploy complete!`

- [ ] **Step 3: Créer le document admin (manuel, console Firebase)**

Va sur https://console.firebase.google.com/project/dungeon-app-353e2/firestore/data
→ **Démarrer une collection** → Collection ID : `admins` → Document ID : `k7noHdMOBnT7a0LIB7jxxFG6jTt1`
→ ajoute un champ quelconque (ex. `note` = `admin`, type string) → **Enregistrer**.

- [ ] **Step 4: Vérifier les règles avec des requêtes REST réelles**

Remplace `<mot de passe user>` / `<mot de passe admin>` par les valeurs de `pass.txt`, puis lance :

```bash
API_KEY="AIzaSyDFrgp3kecKJFW_yjO4maQpMVWxsIJXQ5I"
PROJECT="dungeon-app-353e2"
USER_UID="ewcOxFBrNfNPy5A0sjvYq20pvml2"
ADMIN_UID="k7noHdMOBnT7a0LIB7jxxFG6jTt1"

USER_TOKEN=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@dungeon-app.test","password":"<mot de passe user>","returnSecureToken":true}' \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).idToken))")

# Crée un personnage de test sous le compte user — attendu : 200.
curl -s -o /dev/null -w "create character: %{http_code}\n" -X PATCH \
  "https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${USER_UID}/characters/test1?updateMask.fieldPaths=schemaVersion&updateMask.fieldPaths=name&updateMask.fieldPaths=updatedAt" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"schemaVersion":{"integerValue":"1"},"name":{"stringValue":"Test Rules"},"updatedAt":{"timestampValue":"2026-09-18T00:00:00Z"}}}'

ADMIN_TOKEN=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@dungeon-app.test","password":"<mot de passe admin>","returnSecureToken":true}' \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).idToken))")

# L'admin lit le personnage d'un autre uid — attendu : 200 (c'est le comportement ajouté par isAdmin()).
curl -s -o /dev/null -w "admin reads other's character: %{http_code}\n" \
  "https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${USER_UID}/characters/test1" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# L'admin tente d'écrire dans admins/ — attendu : 403 (écriture toujours fermée).
curl -s -o /dev/null -w "admin writes to admins/: %{http_code}\n" -X PATCH \
  "https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/admins/${ADMIN_UID}?updateMask.fieldPaths=note" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"note":{"stringValue":"hack"}}}'
```

Expected: `create character: 200`, `admin reads other's character: 200`, `admin writes to admins/: 403`.

- [ ] **Step 5: Documenter dans le README**

Dans `README.md`, section `## Firebase`, après le point 5 (`Authorized domains`), ajoute :

```
6. Rôle admin : dans la console Firestore, crée un document `admins/{uid}` (n'importe quel champ,
   même vide) pour l'uid à promouvoir. Aucune écriture cliente n'est possible sur cette collection ;
   c'est la seule façon de désigner un admin.
```

- [ ] **Step 6: Commit**

```bash
git add infra/firebase/firestore.rules README.md
git commit -m "feat(firebase): ajoute le rôle admin (collection admins/, lecture cross-utilisateurs)"
```

---

## Task 2: Dépôt des personnages, vue admin (`AdminCharacterRepository`)

**Files:**
- Create: `apps/character_app/lib/data/admin_character_entry.dart`
- Create: `apps/character_app/lib/data/admin_character_repository.dart`
- Create: `apps/character_app/lib/data/in_memory_admin_character_repository.dart`
- Create: `apps/character_app/lib/data/firestore_admin_character_repository.dart`
- Test: `apps/character_app/test/data/in_memory_admin_character_repository_test.dart`

**Interfaces:**
- Consumes: `CharacterDoc` (`apps/character_app/lib/data/character_doc.dart` — champs `id`, `name`, `updatedAt`, `isDeleted`, `level`, méthode `fromMap(String id, Map<String, Object?> map)`), `PointBuy.standardArray` (`package:rules_engine/rules_engine.dart`, test seulement).
- Produces: `class AdminCharacterEntry { final String ownerUid; final CharacterDoc doc; }`, `abstract class AdminCharacterRepository { Stream<List<AdminCharacterEntry>> watchAllCharacters(); }`, `class InMemoryAdminCharacterRepository implements AdminCharacterRepository` (constructeur `InMemoryAdminCharacterRepository({Iterable<AdminCharacterEntry> seed = const []})`), `class FirestoreAdminCharacterRepository implements AdminCharacterRepository` (constructeur `FirestoreAdminCharacterRepository(FirebaseFirestore db)`).

- [ ] **Step 1: Écrire le test qui échoue**

Crée `apps/character_app/test/data/in_memory_admin_character_repository_test.dart` :

```dart
import 'package:character_app/data/admin_character_entry.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

CharacterDoc _doc(
  String id,
  String name,
  DateTime updatedAt, {
  DateTime? deletedAt,
}) =>
    CharacterDoc(
      id: id,
      name: name,
      scores: PointBuy.standardArray,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );

void main() {
  test(
    'filtre les personnages supprimés et trie par updatedAt décroissant, '
    'tous propriétaires confondus',
    () async {
      final repo = InMemoryAdminCharacterRepository(
        seed: [
          AdminCharacterEntry(
            ownerUid: 'uid-a',
            doc: _doc('c1', 'Ancien', DateTime(2026, 1, 1)),
          ),
          AdminCharacterEntry(
            ownerUid: 'uid-b',
            doc: _doc('c2', 'Récent', DateTime(2026, 6, 1)),
          ),
          AdminCharacterEntry(
            ownerUid: 'uid-a',
            doc: _doc(
              'c3',
              'Supprimé',
              DateTime(2026, 9, 1),
              deletedAt: DateTime(2026, 9, 2),
            ),
          ),
        ],
      );

      final list = await repo.watchAllCharacters().first;

      expect(list.map((e) => e.doc.id), ['c2', 'c1']);
      expect(list.map((e) => e.ownerUid), ['uid-b', 'uid-a']);
    },
  );
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

Run: `cd apps/character_app && flutter test test/data/in_memory_admin_character_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:character_app/data/admin_character_entry.dart'` (les fichiers n'existent pas encore).

- [ ] **Step 3: Implémenter `AdminCharacterEntry`, `AdminCharacterRepository`, `InMemoryAdminCharacterRepository`**

`apps/character_app/lib/data/admin_character_entry.dart` :

```dart
import 'character_doc.dart';

/// Un personnage vu par l'admin, avec l'identifiant de son propriétaire.
class AdminCharacterEntry {
  const AdminCharacterEntry({required this.ownerUid, required this.doc});

  final String ownerUid;
  final CharacterDoc doc;
}
```

`apps/character_app/lib/data/admin_character_repository.dart` :

```dart
import 'admin_character_entry.dart';

/// Accès en lecture seule aux personnages de tous les utilisateurs, pour l'admin.
abstract class AdminCharacterRepository {
  /// Personnages non supprimés de tous les utilisateurs, du plus récemment
  /// mis à jour au plus ancien.
  Stream<List<AdminCharacterEntry>> watchAllCharacters();
}
```

`apps/character_app/lib/data/in_memory_admin_character_repository.dart` :

```dart
import 'dart:async';

import 'admin_character_entry.dart';
import 'admin_character_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminCharacterRepository implements AdminCharacterRepository {
  InMemoryAdminCharacterRepository({
    Iterable<AdminCharacterEntry> seed = const [],
  }) : _entries = [...seed];

  final List<AdminCharacterEntry> _entries;
  final _controller = StreamController<void>.broadcast();

  List<AdminCharacterEntry> _visible() =>
      (_entries.where((e) => !e.doc.isDeleted).toList()
        ..sort((a, b) => b.doc.updatedAt.compareTo(a.doc.updatedAt)));

  @override
  Stream<List<AdminCharacterEntry>> watchAllCharacters() async* {
    yield _visible();
    yield* _controller.stream.map((_) => _visible());
  }
}
```

- [ ] **Step 4: Lancer le test, vérifier qu'il passe**

Run: `cd apps/character_app && flutter test test/data/in_memory_admin_character_repository_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Implémenter `FirestoreAdminCharacterRepository`**

`apps/character_app/lib/data/firestore_admin_character_repository.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_character_entry.dart';
import 'admin_character_repository.dart';
import 'character_doc.dart';

/// Lecture cross-utilisateurs via une requête de groupe de collections sur `characters`.
///
/// Autorisée par la règle `users/{uid}/characters/{id}` : Firestore évalue la
/// règle par document, peu importe le type de requête (get, query, collection group).
class FirestoreAdminCharacterRepository implements AdminCharacterRepository {
  FirestoreAdminCharacterRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AdminCharacterEntry>> watchAllCharacters() =>
      _db.collectionGroup('characters').snapshots().map(_toEntries);

  static List<AdminCharacterEntry> _toEntries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = [
      for (final doc in snapshot.docs)
        AdminCharacterEntry(
          ownerUid: doc.reference.parent.parent!.id,
          doc: CharacterDoc.fromMap(doc.id, _fromFirestore(doc.data())),
        ),
    ]..removeWhere((e) => e.doc.isDeleted);
    entries.sort((a, b) => b.doc.updatedAt.compareTo(a.doc.updatedAt));
    return entries;
  }

  static Map<String, Object?> _fromFirestore(Map<String, dynamic> map) => {
        for (final entry in map.entries)
          entry.key: entry.value is Timestamp
              ? (entry.value as Timestamp).toDate()
              : entry.value,
      };
}
```

- [ ] **Step 6: Vérifier que tout compile**

Run: `cd apps/character_app && dart analyze lib/data/admin_character_entry.dart lib/data/admin_character_repository.dart lib/data/in_memory_admin_character_repository.dart lib/data/firestore_admin_character_repository.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add apps/character_app/lib/data/admin_character_entry.dart \
        apps/character_app/lib/data/admin_character_repository.dart \
        apps/character_app/lib/data/in_memory_admin_character_repository.dart \
        apps/character_app/lib/data/firestore_admin_character_repository.dart \
        apps/character_app/test/data/in_memory_admin_character_repository_test.dart
git commit -m "feat(admin): dépôt cross-utilisateurs des personnages (lecture seule)"
```

---

## Task 3: Dépôt du rôle admin (`AdminRepository`)

**Files:**
- Create: `apps/character_app/lib/data/admin_repository.dart`
- Create: `apps/character_app/lib/data/in_memory_admin_repository.dart`
- Create: `apps/character_app/lib/data/firestore_admin_repository.dart`

**Interfaces:**
- Consumes: rien de nouveau (juste `cloud_firestore`).
- Produces: `abstract class AdminRepository { Stream<bool> watchIsAdmin(String uid); }`, `class InMemoryAdminRepository implements AdminRepository` (constructeur `InMemoryAdminRepository({Set<String> admins = const {}})`), `class FirestoreAdminRepository implements AdminRepository` (constructeur `FirestoreAdminRepository(FirebaseFirestore db)`).

Logique triviale (vérification d'existence d'un document / appartenance à un `Set`) — pas de cycle de test dédié, la Task 5 la vérifie de bout en bout via un test de widget.

- [ ] **Step 1: Implémenter les trois fichiers**

`apps/character_app/lib/data/admin_repository.dart` :

```dart
/// Sait si un utilisateur a le rôle admin.
abstract class AdminRepository {
  /// `true` si un document `admins/{uid}` existe.
  Stream<bool> watchIsAdmin(String uid);
}
```

`apps/character_app/lib/data/in_memory_admin_repository.dart` :

```dart
import 'admin_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminRepository implements AdminRepository {
  InMemoryAdminRepository({Set<String> admins = const {}})
      : _admins = {...admins};

  final Set<String> _admins;

  @override
  Stream<bool> watchIsAdmin(String uid) => Stream.value(_admins.contains(uid));
}
```

`apps/character_app/lib/data/firestore_admin_repository.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_repository.dart';

/// Le rôle admin est déterminé par l'existence d'un document `admins/{uid}`.
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<bool> watchIsAdmin(String uid) =>
      _db.collection('admins').doc(uid).snapshots().map((doc) => doc.exists);
}
```

- [ ] **Step 2: Vérifier que tout compile**

Run: `cd apps/character_app && dart analyze lib/data/admin_repository.dart lib/data/in_memory_admin_repository.dart lib/data/firestore_admin_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/character_app/lib/data/admin_repository.dart \
        apps/character_app/lib/data/in_memory_admin_repository.dart \
        apps/character_app/lib/data/firestore_admin_repository.dart
git commit -m "feat(admin): dépôt du rôle admin (admins/{uid})"
```

---

## Task 4: Providers Riverpod

**Files:**
- Create: `apps/character_app/lib/features/admin/admin_providers.dart`

**Interfaces:**
- Consumes: `AdminRepository`, `FirestoreAdminRepository` (Task 3) ; `AdminCharacterRepository`, `FirestoreAdminCharacterRepository`, `AdminCharacterEntry` (Task 2) ; `currentUidProvider` (`apps/character_app/lib/features/auth/auth_providers.dart`, `Provider<String?>`).
- Produces: `adminRepositoryProvider` (`Provider<AdminRepository>`), `isAdminProvider` (`StreamProvider<bool>`), `adminCharacterRepositoryProvider` (`Provider<AdminCharacterRepository>`), `allCharactersProvider` (`StreamProvider<List<AdminCharacterEntry>>`) — utilisés par la Task 5.

- [ ] **Step 1: Implémenter les providers**

`apps/character_app/lib/features/admin/admin_providers.dart` :

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_character_entry.dart';
import '../../data/admin_character_repository.dart';
import '../../data/admin_repository.dart';
import '../../data/firestore_admin_character_repository.dart';
import '../../data/firestore_admin_repository.dart';
import '../auth/auth_providers.dart';

/// Dépôt du rôle admin ; remplacé par `InMemoryAdminRepository` dans les tests.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => FirestoreAdminRepository(FirebaseFirestore.instance),
);

/// `true` si l'utilisateur courant est admin (document `admins/{uid}` dans Firestore).
final isAdminProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(adminRepositoryProvider).watchIsAdmin(uid);
});

/// Dépôt cross-utilisateurs des personnages ; remplacé par
/// `InMemoryAdminCharacterRepository` dans les tests.
final adminCharacterRepositoryProvider = Provider<AdminCharacterRepository>(
  (ref) => FirestoreAdminCharacterRepository(FirebaseFirestore.instance),
);

/// Tous les personnages de tous les utilisateurs, en temps réel (vue admin).
final allCharactersProvider = StreamProvider<List<AdminCharacterEntry>>(
  (ref) => ref.watch(adminCharacterRepositoryProvider).watchAllCharacters(),
);
```

- [ ] **Step 2: Vérifier que tout compile**

Run: `cd apps/character_app && dart analyze lib/features/admin/admin_providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add apps/character_app/lib/features/admin/admin_providers.dart
git commit -m "feat(admin): providers Riverpod pour le rôle admin"
```

---

## Task 5: Écran admin, icône de navigation, route

**Files:**
- Create: `apps/character_app/lib/features/admin/admin_characters_screen.dart`
- Modify: `apps/character_app/lib/router.dart`
- Modify: `apps/character_app/lib/features/home/home_screen.dart`
- Test: `apps/character_app/test/admin_test.dart`

**Interfaces:**
- Consumes: `isAdminProvider`, `allCharactersProvider`, `adminRepositoryProvider`, `adminCharacterRepositoryProvider` (Task 4) ; `AdminCharacterEntry` (Task 2) ; `InMemoryAdminRepository` (Task 3) ; `InMemoryAdminCharacterRepository` (Task 2) ; `AppRoutes` (`apps/character_app/lib/router.dart`) ; `FakeAuthService`, `AppUser` (existant).
- Produces: `AppRoutes.admin` (`'/admin'`), `AdminCharactersScreen` (widget).

- [ ] **Step 1: Écrire le test de widget qui échoue**

Crée `apps/character_app/test/admin_test.dart` :

```dart
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
              AdminCharacterEntry(
                ownerUid: 'autre-uid',
                doc: _doc('c1', 'Brenna'),
              ),
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

  testWidgets('un utilisateur non-admin ne voit pas l\'icône admin', (tester) async {
    await tester.pumpWidget(_app(admin: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier qu'il échoue**

Run: `cd apps/character_app && flutter test test/admin_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:character_app/features/admin/admin_providers.dart'` ou équivalent (les fichiers de la Task 4 existent déjà, mais `AppRoutes.admin` / l'icône / l'écran n'existent pas encore).

- [ ] **Step 3: Implémenter `AdminCharactersScreen`**

`apps/character_app/lib/features/admin/admin_characters_screen.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';

/// Vue admin : tous les personnages de tous les utilisateurs, en lecture seule.
class AdminCharactersScreen extends ConsumerWidget {
  const AdminCharactersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(allCharactersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Personnages')),
      body: entries.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('Aucun personnage'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final entry = list[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${entry.doc.level}')),
                    title: Text(entry.doc.name),
                    subtitle: Text('Propriétaire : ${entry.ownerUid}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }
}
```

- [ ] **Step 4: Ajouter la route**

Dans `apps/character_app/lib/router.dart`, ajoute l'import et la route :

```dart
import 'package:go_router/go_router.dart';

import 'features/admin/admin_characters_screen.dart';
import 'features/auth/account_screen.dart';
import 'features/home/home_screen.dart';
import 'features/point_buy/point_buy_screen.dart';

/// Routes de l'app. Les chemins sont aussi les URL sur le web.
abstract final class AppRoutes {
  static const home = '/';
  static const pointBuy = '/point-buy';
  static const account = '/account';
  static const admin = '/admin';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'point-buy',
          builder: (context, state) => const PointBuyScreen(),
        ),
        GoRoute(
          path: 'account',
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(
          path: 'admin',
          builder: (context, state) => const AdminCharactersScreen(),
        ),
      ],
    ),
  ],
);
```

- [ ] **Step 5: Ajouter l'icône conditionnelle dans `HomeScreen`**

Dans `apps/character_app/lib/features/home/home_screen.dart`, remplace le bloc d'imports par :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/character_doc.dart';
import '../../router.dart';
import '../admin/admin_providers.dart';
import '../auth/auth_providers.dart';
import '../characters/characters_providers.dart';
```

Remplace le bloc `actions:` de l'`AppBar` par :

```dart
        actions: [
          if (ref.watch(isAdminProvider).value ?? false)
            IconButton(
              tooltip: 'Admin : voir tous les personnages',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push(AppRoutes.admin),
            ),
          IconButton(
            tooltip: isAnonymous
                ? 'Compte anonyme : lie-le pour retrouver tes persos ailleurs'
                : user!.label,
            icon: Icon(
              isAnonymous
                  ? Icons.person_outline
                  : Icons.verified_user_outlined,
            ),
            onPressed: () => context.push(AppRoutes.account),
          ),
        ],
```

- [ ] **Step 6: Lancer le test, vérifier qu'il passe**

Run: `cd apps/character_app && flutter test test/admin_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Lancer toute la suite de tests de l'app**

Run: `cd apps/character_app && flutter test`
Expected: PASS (tous les tests, y compris `app_test.dart` et `widget_test.dart` déjà existants).

- [ ] **Step 8: Commit**

```bash
git add apps/character_app/lib/features/admin/admin_characters_screen.dart \
        apps/character_app/lib/router.dart \
        apps/character_app/lib/features/home/home_screen.dart \
        apps/character_app/test/admin_test.dart
git commit -m "feat(admin): écran admin (lecture seule) et navigation conditionnelle"
```

---

## Task 6: Vérification manuelle de bout en bout (Firebase réel)

**Files:** aucun (validation seulement, pas de commit).

- [ ] **Step 1: Lancer l'app**

Run: `cd apps/character_app && flutter run -d chrome`

- [ ] **Step 2: Vérifier le compte user**

Dans l'app : icône compte (en haut à droite) → onglet « Déjà un compte ? Se connecter » → e-mail `user@dungeon-app.test`, mot de passe depuis `pass.txt` → Se connecter.
Vérifier : pas d'icône admin (`Icons.admin_panel_settings_outlined`) dans l'`AppBar` de l'écran « Personnages ». Créer un personnage (bouton « Nouveau personnage ») pour avoir une donnée à vérifier à l'étape suivante.

- [ ] **Step 3: Vérifier le compte admin**

Retour à l'icône compte → « Se déconnecter » → reconnexion avec `admin@dungeon-app.test` (même mot de passe fichier).
Vérifier : l'icône admin apparaît dans l'`AppBar`. Cliquer dessus → le personnage créé à l'étape 2 par `user@dungeon-app.test` apparaît dans la liste, avec son `ownerUid` affiché en sous-titre.

Si les deux vérifications passent, le sous-projet 1 est complet et prêt pour le brainstorming du sous-projet 2 (contenu éditable classes/dons/sorts).
