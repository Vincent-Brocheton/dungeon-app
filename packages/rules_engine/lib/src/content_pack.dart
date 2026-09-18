import 'ability.dart';

/// Version du schéma JSON de pack que ce moteur sait lire.
const int supportedSchemaVersion = 1;

/// Un pack de contenu (SRD 5.2, homebrew...) chargé depuis du JSON.
///
/// Le moteur ne contient aucune donnée de jeu : tout vient d'ici.
class ContentPack {
  /// Crée un pack.
  const ContentPack({
    required this.id,
    required this.name,
    required this.schemaVersion,
    required this.license,
    this.attribution = '',
    this.species = const [],
    this.backgrounds = const [],
  });

  /// Lit un pack depuis son JSON décodé.
  ///
  /// Lève [UnsupportedSchemaVersion] si le pack est plus récent que le moteur,
  /// [FormatException] si un champ obligatoire manque.
  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requireInt(json, 'schemaVersion');
    if (schemaVersion > supportedSchemaVersion) {
      throw UnsupportedSchemaVersion(schemaVersion);
    }
    return ContentPack(
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      schemaVersion: schemaVersion,
      license: _requireString(json, 'license'),
      attribution: json['attribution'] as String? ?? '',
      species: _listOfMaps(json, 'species').map(SpeciesDef.fromJson).toList(),
      backgrounds:
          _listOfMaps(json, 'backgrounds').map(BackgroundDef.fromJson).toList(),
    );
  }

  /// Identifiant stable (`srd-5.2`).
  final String id;

  /// Nom affichable.
  final String name;

  /// Version du schéma JSON du pack.
  final int schemaVersion;

  /// Licence du contenu (`CC-BY-4.0`).
  final String license;

  /// Texte d'attribution imposé par la licence.
  final String attribution;

  /// Espèces.
  final List<SpeciesDef> species;

  /// Backgrounds.
  final List<BackgroundDef> backgrounds;

  /// Espèce par identifiant, ou `null`.
  SpeciesDef? speciesById(String id) =>
      species.where((s) => s.id == id).firstOrNull;

  /// Background par identifiant, ou `null`.
  BackgroundDef? backgroundById(String id) =>
      backgrounds.where((b) => b.id == id).firstOrNull;
}

/// Une espèce (PHB 2024 : aucune espèce ne donne de bonus de caractéristique).
class SpeciesDef {
  /// Crée une espèce.
  const SpeciesDef({
    required this.id,
    required this.name,
    required this.sizeOptions,
    required this.speed,
  });

  /// Lit une espèce depuis son JSON.
  factory SpeciesDef.fromJson(Map<String, dynamic> json) => SpeciesDef(
        id: _requireString(json, 'id'),
        name: _requireString(json, 'name'),
        sizeOptions: _list(json, 'sizeOptions').cast<String>().toList(),
        speed: _requireInt(json, 'speed'),
      );

  /// Identifiant stable.
  final String id;

  /// Nom.
  final String name;

  /// Tailles possibles (`small`, `medium`) ; plusieurs = choix du joueur.
  final List<String> sizeOptions;

  /// Vitesse en pieds (30 = 9 m).
  final int speed;
}

/// Un Background (PHB 2024) : 3 caracs, un Don d'Origine, 2 compétences, 1 outil.
class BackgroundDef {
  /// Crée un Background.
  const BackgroundDef({
    required this.id,
    required this.name,
    required this.abilities,
    required this.originFeat,
    required this.skills,
    required this.tool,
  });

  /// Lit un Background depuis son JSON.
  factory BackgroundDef.fromJson(Map<String, dynamic> json) {
    final abilities = _list(json, 'abilities')
        .cast<String>()
        .map(Ability.parse)
        .toSet();
    if (abilities.length != 3) {
      throw FormatException(
        'Background ${json['id']} : 3 caractéristiques attendues, ${abilities.length} reçues',
      );
    }
    return BackgroundDef(
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      abilities: abilities,
      originFeat: _requireString(json, 'originFeat'),
      skills: _list(json, 'skills').cast<String>().toList(),
      tool: _requireString(json, 'tool'),
    );
  }

  /// Identifiant stable.
  final String id;

  /// Nom.
  final String name;

  /// Les trois caractéristiques bonifiables.
  final Set<Ability> abilities;

  /// Identifiant du Don d'Origine accordé.
  final String originFeat;

  /// Identifiants des deux compétences accordées.
  final List<String> skills;

  /// Identifiant de l'outil maîtrisé.
  final String tool;
}

/// Le pack est écrit pour un schéma plus récent que ce moteur.
class UnsupportedSchemaVersion implements Exception {
  /// Crée l'exception pour la [version] rencontrée.
  const UnsupportedSchemaVersion(this.version);

  /// Version rencontrée.
  final int version;

  @override
  String toString() =>
      'Pack au schéma v$version, ce moteur lit au plus v$supportedSchemaVersion';
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Champ "$key" manquant ou vide');
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Champ "$key" manquant ou non entier');
}

List<Map<String, dynamic>> _listOfMaps(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is List) return value.cast<Map<String, dynamic>>();
  throw FormatException('Champ "$key" : liste attendue');
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is List) return value;
  throw FormatException('Champ "$key" : liste attendue');
}
