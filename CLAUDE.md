# Workflow de développement

Ce projet suit un workflow obligatoire pour toute fonctionnalité ou correction de bug.

## 1. Branche

Jamais de commit direct sur `main` (bloqué techniquement par un hook `.claude/settings.json`
qui refuse Edit/Write tant que la branche courante est `main`/`master`).
Avant toute modification, créer une branche depuis `main` :
- `feat/<nom>` pour une fonctionnalité
- `fix/<nom>` pour une correction de bug
- `chore/<nom>` pour le reste (config, refacto, outillage)

## 2. Tests

Tout développement doit être testé avant d'être poussé :
- `flutter test` dans `apps/character_app`
- `flutter test` dans `packages/content_srd52`
- `dart test` dans `packages/rules_engine`
- `dart analyze --fatal-infos` et `dart format --output=none --set-exit-if-changed packages apps`
  (ce que la CI vérifie aussi)

## 3. Push + Pull Request

Une fois le dev terminé et testé localement :
1. `git push -u origin <branche>`
2. Créer la PR avec `gh pr create` (contre `main`)

## 4. Vérifier la CI

Après ouverture de la PR, surveiller la CI jusqu'à ce qu'elle passe complètement
(`gh pr checks <numéro> --watch`). Le workflow `.github/workflows/ci.yml` a deux jobs :
`check` (format, analyse, tests) et `build` (APK + web). Corriger et repousser si un job échoue,
jusqu'à un run complet vert.

## 5. Security review

Une fois la CI passée au vert une première fois en entier (push + tests + CI OK), lancer le
skill `/security-review` sur la branche avant de considérer le dev terminé.

## 6. Merge

Dès que la CI est verte et que le security-review ne relève aucune faille (ou que les failles
relevées sont corrigées et re-vérifiées), merger la PR sans redemander confirmation :
`gh pr merge <numéro> --squash --delete-branch`.
Si le security-review relève une faille, la corriger, repousser, revérifier CI + security-review
avant de merger.

## 7. Déploiement Firestore

Si la PR mergée modifie `infra/firebase/firestore.rules` (ou `firestore.indexes.json`), déployer
tout de suite après le merge, sans redemander confirmation :
`cd infra/firebase && firebase deploy --only firestore:rules --project dungeon-app-353e2`
(remplacer `firestore:rules` par `firestore:rules,firestore:indexes` si les index ont aussi changé).
La CI ne déploie rien : ces fichiers ne prennent effet qu'après ce déploiement manuel.
