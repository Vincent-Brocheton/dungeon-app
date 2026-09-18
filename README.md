# Grimoire — gestionnaire de personnages compatible SRD 5.2 (règles 2024)

Monorepo Flutter/Dart : un seul code pour l'APK Android et l'app web. Spec et plan : voir le doc
« Spec & Plan de dev — App Personnages D&D 2024 ».

> « Grimoire » est un nom provisoire. Ne pas utiliser « Dungeons & Dragons » dans le nom ni
> les stores : marque déposée. Le contenu embarqué se limite au SRD 5.2.1 (CC-BY-4.0).

## Structure

```
.
├── pubspec.yaml                 # pub workspace (Dart ≥ 3.6)
├── Makefile                     # commandes du quotidien
├── .github/workflows/           # ci.yml (PR/main) · release.yml (tags v*)
├── infra/firebase/              # firestore.rules, firebase.json (déploiement des règles)
├── packages/
│   ├── rules_engine/            # moteur de règles, Dart pur, 0 dépendance Flutter
│   └── content_srd52/           # pack SRD 5.2.1 en JSON + schéma + attribution
└── apps/
    └── character_app/           # l'app Flutter (Riverpod + go_router + Firebase)
```

Règle d'architecture : `rules_engine` ne connaît ni Flutter, ni la base de données, ni les
textes utilisateur. Il reçoit des choix + un `ContentPack` et renvoie des valeurs dérivées ou des
`RuleViolation` (codes stables, traduits côté UI).

## Démarrage

Prérequis : Flutter stable ≥ 3.29 (Dart ≥ 3.7), Android SDK pour l'APK, Chrome pour le web,
un projet Firebase (plan Spark) avec Firestore et Auth activés.

```bash
make bootstrap          # pub get + génère apps/character_app/android/ et web/ (à commiter)
make fix-format         # une fois avant le premier commit : le squelette est écrit à la main
make ci                 # format + analyse + tous les tests (aucun accès Firebase requis)
make firebase-configure # génère lib/firebase_options.dart — indispensable avant de lancer l'app
make run-web            # ou : make run-android
```

Si `flutter pub get` refuse les contraintes Firebase du pubspec, remplace-les par les
dernières : `cd apps/character_app && flutter pub add firebase_core firebase_auth cloud_firestore`.

## Firebase

1. Console Firebase → nouveau projet → **Authentication** : activer *Anonyme*, *E-mail/mot de passe*,
   *Google* ; **Firestore** : créer la base en mode production (les règles sont déployées à l'étape 3).
2. `dart pub global activate flutterfire_cli` puis `make firebase-configure` : remplace le stub
   `lib/firebase_options.dart`. Le fichier se commite (clés publiques côté client).
3. `npm i -g firebase-tools`, `firebase login`, `cp infra/firebase/.firebaserc.example infra/firebase/.firebaserc`
   (mettre l'id du projet), puis `make deploy-rules`.
4. Android : dans `apps/character_app/android/app/build.gradle.kts` (généré par `make bootstrap`),
   mettre `minSdk = 23` (exigé par Firebase Auth).
5. Web : dans Authentication → Settings → *Authorized domains*, ajouter le domaine Cloudflare Pages.
6. Rôle admin : dans la console Firestore, crée un document `admins/{uid}` (n'importe quel champ,
   même vide) pour l'uid à promouvoir. Aucune écriture cliente n'est possible sur cette collection ;
   c'est la seule façon de désigner un admin.

Fonctionnement : session **anonyme** au premier lancement, persos écrits en local et synchronisés
par le SDK Firestore (cache hors-ligne activé dans `main.dart`). L'écran « Mon compte » lie la
session à un e-mail ou à Google **sans changer d'`uid`**, donc sans migration. Google Sign-In est
câblé sur le web (popup) ; sur Android il faut ajouter `google_sign_in` et l'empreinte SHA-1 dans
la console — prévu en phase 4. La suppression de compte efface les documents puis l'utilisateur.

Le code ne touche Firebase qu'à travers `AuthService` et `CharacterRepository` ; les tests de
widgets tournent avec `FakeAuthService` et `InMemoryCharacterRepository`, sans réseau.

`bootstrap` lance `flutter create --platforms=android,web .` dans l'app : il ajoute les dossiers
de plateforme sans toucher à `lib/`. Change l'identifiant Android avec `make bootstrap ORG=fr.tondomaine`.

Pour passer aux dernières majeures des dépendances : `cd apps/character_app && flutter pub upgrade --major-versions`.

## Ce que le squelette contient déjà

- `rules_engine` : caractéristiques et modificateurs, `AbilityScores` immuable, Achat de points
  (27 pts, 8–15), bonus de Background (+2/+1 ou +1/+1/+1, plafond 20), bonus de maîtrise,
  modèle `ContentPack` (espèces, backgrounds) avec contrôle de version de schéma. Tests unitaires
  sur chaque règle.
- `content_srd52` : `pack.json` minimal, `schema/content_pack.schema.json` (v1), `ATTRIBUTION.md`,
  chargeur `loadSrd52Pack()`, tests de cohérence du pack.
- `character_app` : auth anonyme → liaison e-mail / Google, liste « Mes personnages » synchronisée
  (Firestore, hors-ligne), écran Achat de points branché sur le moteur avec enregistrement d'un
  personnage, écran « Mon compte » (lier, se connecter, se déconnecter, supprimer). Tests de widgets.

## CI / CD

- **ci.yml** : sur PR et `main` — formatage, `dart analyze --fatal-infos`, tests des trois paquets,
  puis build APK + web en artefacts (14 jours).
- **release.yml** : sur tag `v*` — APK sur GitHub Releases ; déploiement Cloudflare Pages si les
  secrets `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` et la variable `CF_PAGES_PROJECT` existent ;
  signature release si `ANDROID_KEYSTORE_BASE64` (+ mots de passe et alias) existent, sinon signature
  debug (suffisante pour le sideload).

Publier : `git tag v0.1.0 && git push --tags`.

## Prochaines étapes (Phase 0 → 1)

1. Inventorier le SRD 5.2.1 et remplir `pack.json` (espèces, backgrounds, puis classes/sorts/objets)
   en étendant le schéma et `ContentPack` d'un pas à la fois.
2. Ajouter les effets déclaratifs au moteur (CA, ressources, maîtrises d'armes) — jamais de
   `if (classe == …)`.
3. Faire grossir `CharacterDoc` avec le domaine `Character` du moteur (classe, background, état de
   session) en incrémentant `schemaVersion` et en migrant dans `fromMap`.
4. Modèles `freezed` quand les entités grossissent (`build_runner` à ajouter alors).
5. Drift/SQLite uniquement si le compendium (V1) réclame la recherche plein texte.
