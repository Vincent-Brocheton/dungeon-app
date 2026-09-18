# Commandes du monorepo. `make` sans argument affiche l'aide.
ORG ?= dev.grimoire
APP := apps/character_app

.PHONY: help bootstrap get firebase-configure deploy-rules format fix-format analyze test test-engine test-content test-app build-apk build-web run-web run-android ci clean

help:
	@echo "bootstrap    Dépendances + génération des dossiers android/ et web/ (première fois)"
	@echo "get          flutter pub get sur tout le workspace"
	@echo "firebase-configure  Génère lib/firebase_options.dart (flutterfire configure)"
	@echo "deploy-rules Déploie les règles Firestore (infra/firebase)"
	@echo "format       Vérifie le formatage (échoue si un fichier n'est pas formaté)"
	@echo "analyze      dart analyze sur tout le workspace"
	@echo "test         Tous les tests (moteur, contenu, app)"
	@echo "build-apk    APK release -> $(APP)/build/app/outputs/flutter-apk/app-release.apk"
	@echo "build-web    Build web release -> $(APP)/build/web"
	@echo "run-web      Lance l'app dans Chrome"
	@echo "run-android  Lance l'app sur l'appareil/émulateur Android connecté"
	@echo "ci           format + analyze + test (ce que fait GitHub Actions)"

bootstrap: get
	cd $(APP) && flutter create --platforms=android,web --project-name character_app --org $(ORG) .
	@echo "-> Dossiers android/ et web/ générés. Commite-les."

get:
	cd $(APP) && flutter pub get

firebase-configure:
	cd $(APP) && flutterfire configure --platforms=android,web

deploy-rules:
	cd infra/firebase && firebase deploy --only firestore:rules,firestore:indexes

format:
	dart format --output=none --set-exit-if-changed packages apps

fix-format:
	dart format packages apps

analyze:
	dart analyze --fatal-infos

test: test-engine test-content test-app

test-engine:
	cd packages/rules_engine && dart test --reporter expanded

test-content:
	cd packages/content_srd52 && flutter test

test-app:
	cd $(APP) && flutter test

build-apk:
	cd $(APP) && flutter build apk --release

build-web:
	cd $(APP) && flutter build web --release

run-web:
	cd $(APP) && flutter run -d chrome

run-android:
	cd $(APP) && flutter run -d android

ci: format analyze test

clean:
	cd $(APP) && flutter clean
	rm -rf packages/*/.dart_tool packages/*/build
