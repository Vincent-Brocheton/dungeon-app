/// Chargement du pack SRD 5.2.1 embarqué dans les assets de ce paquet.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:rules_engine/rules_engine.dart';

/// Chemin de l'asset tel que l'app le voit (préfixe `packages/<paquet>/`).
const String srd52AssetPath = 'packages/content_srd52/assets/srd52/pack.json';

/// Charge et parse le pack SRD 5.2.1.
///
/// [bundle] permet d'injecter un bundle de test ; par défaut [rootBundle].
Future<ContentPack> loadSrd52Pack({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString(srd52AssetPath);
  return parseContentPack(raw);
}

/// Parse un pack depuis sa chaîne JSON.
ContentPack parseContentPack(String raw) =>
    ContentPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
