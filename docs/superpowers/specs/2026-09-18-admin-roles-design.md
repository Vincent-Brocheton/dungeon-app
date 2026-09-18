# Rôles & permissions (user / admin) — sous-projet 1

## Contexte

Aujourd'hui tout utilisateur authentifié (anonyme ou lié) a les mêmes droits : lire/écrire
uniquement son propre sous-arbre `users/{uid}`. Il n'existe aucune notion de rôle.

Objectif final (demande initiale) : un compte **user** consulte/ajoute/modifie ses propres
personnages (déjà en place), un compte **admin** voit tous les personnages et pourra gérer le
contenu de règles (classes, espèces, dons, sorts).

Le contenu de règles (classes/dons/sorts) n'existe pas encore dans `ContentPack` (seuls species
et backgrounds sont modélisés) et vit dans un JSON statique embarqué, pas en base — l'éditer en
live demande de le migrer vers Firestore. C'est un chantier séparé et plus gros.

**Ce document couvre uniquement le sous-projet 1 : les fondations rôles/permissions** — assez
pour qu'un admin puisse être distingué d'un user et voir (lecture seule) tous les personnages.
Le sous-projet 2 (contenu éditable classes/dons/sorts, écrans CRUD admin) sera brainstormé et
spécifié séparément une fois ce socle en place.

## Comptes de test

Deux comptes Firebase Auth déjà créés (email/mot de passe) pour valider ce sous-projet :

| Rôle | Email | UID |
|---|---|---|
| Admin | `admin@dungeon-app.test` | `k7noHdMOBnT7a0LIB7jxxFG6jTt1` |
| User | `user@dungeon-app.test` | `ewcOxFBrNfNPy5A0sjvYq20pvml2` |

(Mots de passe dans `pass.txt`, local, ignoré par git.)

## Modèle de rôle

Nouvelle collection `admins/{uid}` : l'**existence** d'un document = admin (contenu du document
sans importance, un document vide suffit).

Pas de champ `role` sur `users/{uid}` : ce document est déjà en écriture libre pour son
propriétaire (`allow read, write: if isOwner(uid)`), donc un champ `role` là-bas serait une
faille d'auto-promotion. La collection `admins/` reste séparée et fermée en écriture côté
client.

## Attribution du rôle admin

Manuelle, dans la console Firebase (Firestore Database → collection `admins` → document dont
l'ID est l'UID à promouvoir). Pas d'outillage supplémentaire pour un besoin à un seul admin
pour l'instant. Un uid anonyme n'aura jamais de document dans `admins/` (il n'est jamais créé
que manuellement pour un uid stable lié à un e-mail/Google) : pas de garde-fou explicite à coder
pour exclure les comptes anonymes, c'est le cas par construction.

## Règles Firestore

```
function isAdmin() {
  return request.auth != null
    && exists(/databases/$(database)/documents/admins/$(request.auth.uid));
}

match /admins/{uid} {
  allow read: if isOwner(uid) || isAdmin();
  allow write: if false;
}

match /users/{uid}/characters/{characterId} {
  allow read: if isOwner(uid) || isAdmin();
  allow delete: if isOwner(uid);
  allow create, update: if isOwner(uid) && validCharacter();
}
```

Seul changement sur `characters` : ajout de `|| isAdmin()` en lecture. Écriture/suppression
restent réservées au propriétaire (l'admin est lecture seule sur les personnages dans ce
sous-projet).

Une requête `collectionGroup('characters')` côté admin est couverte par cette même règle : Firestore
évalue la règle par chemin de document, pas par type de requête (get vs query vs collection
group).

## Côté app

**Détection du rôle** — `lib/features/admin/admin_providers.dart` :

```dart
final isAdminProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists);
});
```

**Requête cross-utilisateurs** — `lib/features/admin/admin_character_repository.dart` :

- `AdminCharacterEntry` : `{ String ownerUid; CharacterDoc doc; }`
- `AdminCharacterRepository.watchAllCharacters()` : `collectionGroup('characters')`, `ownerUid`
  lu via `doc.reference.parent.parent!.id`. Filtrage des personnages supprimés
  (`deletedAt != null`) et tri par `updatedAt` décroissant faits côté client, en mémoire —
  évite de déclarer un index composite Firestore pour un simple tri/filtre en lecture seule.

**Écran** — `lib/features/admin/admin_characters_screen.dart` :

Liste en lecture seule (nom, niveau, `ownerUid`) des personnages de tous les utilisateurs. Pas
d'action d'écriture (pas de bouton supprimer/éditer — cohérent avec « admin voit, ne modifie
pas les persos des autres »).

**Navigation** :

- Route `/admin` ajoutée dans `router.dart`.
- Icône dans l'`AppBar` de `HomeScreen`, visible seulement si `isAdminProvider` vaut `true`.
- Pas de garde `redirect` go_router : l'icône n'apparaît juste pas pour un non-admin, et même
  en accès direct par URL, les règles Firestore bloquent la lecture cross-utilisateurs — rien
  de sensible n'est exposé sans le rôle.

## Hors scope (sous-projet 2, plus tard)

- Extension du modèle `ContentPack` (classes, dons, sorts).
- Migration du contenu de règles (espèces/backgrounds compris) vers Firestore pour édition live.
- Écrans admin CRUD sur ce contenu.
- Toute UI de gestion des rôles (promouvoir/rétrograder un admin depuis l'app).

## Tests

- Règles Firestore : cas à couvrir avec l'émulateur ou revue manuelle — un user non-admin ne
  peut pas lire les personnages d'un autre uid ; un admin le peut ; personne ne peut écrire dans
  `admins/`.
- `AdminCharacterRepository` : test sur le mapping/filtrage/tri (logique non triviale) avec un
  jeu de documents simulé, sur le modèle des tests existants d'`InMemoryCharacterRepository`.
