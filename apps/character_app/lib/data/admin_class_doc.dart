import 'admin_species_doc.dart' show SpeciesSource;
import 'content_repository.dart';

/// 20 entrées (niveaux 1 à 20), complétées par des chaînes vides si la liste
/// stockée est plus courte ou absente.
List<String> levelTexts(Object? raw) {
  final list = [for (final v in (raw as List?) ?? const []) '$v'];
  return [for (var i = 0; i < 20; i++) i < list.length ? list[i] : ''];
}

/// Colonne de ressource de la table de progression (ex. « Sursauts
/// d'Action ») : un nom et une valeur par niveau.
class ResourceColumn {
  const ResourceColumn({required this.name, required this.values});

  final String name;

  /// 20 valeurs, niveaux 1 à 20.
  final List<String> values;

  Map<String, Object?> toMap() => {'name': name, 'values': values};

  factory ResourceColumn.fromMap(Map<Object?, Object?> map) => ResourceColumn(
    name: map['name'] as String? ?? '',
    values: levelTexts(map['values']),
  );
}

/// Une classe : `content/classes/{id}` dans Firestore. Aucune classe dans le
/// pack SRD statique — tout est admin-créé, comme les sorts et les dons.
class AdminClassDoc implements ContentDoc {
  const AdminClassDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.hitDie = 'd8',
    this.primaryAbility = 'Force',
    this.savingThrows = '',
    this.skills = '',
    this.resource = '',
    this.recovery = 'Repos long',
    this.spellcaster = false,
    this.spellcastingAbility = 'Intelligence',
    this.description = '',
    this.levelFeatures = const [],
    this.asiLevels = defaultAsiLevels,
    this.resourceColumns = const [],
  });

  static const defaultAsiLevels = [4, 8, 12, 16, 19];

  static const hitDice = ['d6', 'd8', 'd10', 'd12'];
  static const abilities = [
    'Force',
    'Dextérité',
    'Constitution',
    'Intelligence',
    'Sagesse',
    'Charisme',
  ];
  static const recoveries = ['Repos court', 'Repos long'];

  @override
  final String id;
  final String name;
  @override
  final SpeciesSource source;
  final String sourcebook;
  final String hitDie;
  final String primaryAbility;

  /// Texte libre (ex. « Intelligence, Dextérité »).
  final String savingThrows;

  /// Texte libre (ex. « 2 parmi : Arcanes, Histoire… »).
  final String skills;

  /// Ressource principale, texte libre (ex. « Points de Ki »).
  final String resource;
  final String recovery;
  final bool spellcaster;

  /// Utilisée pour le DD de sauvegarde et le bonus d'attaque des sorts.
  final String spellcastingAbility;
  final String description;

  /// Aptitudes de classe par niveau (index 0 = niveau 1), voir [levelTexts].
  final List<String> levelFeatures;

  /// Niveaux qui donnent une amélioration de caractéristique ou un don.
  final List<int> asiLevels;
  final List<ResourceColumn> resourceColumns;
  final DateTime updatedAt;

  AdminClassDoc copyWith({
    String? name,
    SpeciesSource? source,
    String? sourcebook,
    String? hitDie,
    String? primaryAbility,
    String? savingThrows,
    String? skills,
    String? resource,
    String? recovery,
    bool? spellcaster,
    String? spellcastingAbility,
    String? description,
    List<String>? levelFeatures,
    List<int>? asiLevels,
    List<ResourceColumn>? resourceColumns,
    DateTime? updatedAt,
  }) => AdminClassDoc(
    id: id,
    name: name ?? this.name,
    source: source ?? this.source,
    sourcebook: sourcebook ?? this.sourcebook,
    hitDie: hitDie ?? this.hitDie,
    primaryAbility: primaryAbility ?? this.primaryAbility,
    savingThrows: savingThrows ?? this.savingThrows,
    skills: skills ?? this.skills,
    resource: resource ?? this.resource,
    recovery: recovery ?? this.recovery,
    spellcaster: spellcaster ?? this.spellcaster,
    spellcastingAbility: spellcastingAbility ?? this.spellcastingAbility,
    description: description ?? this.description,
    levelFeatures: levelFeatures ?? this.levelFeatures,
    asiLevels: asiLevels ?? this.asiLevels,
    resourceColumns: resourceColumns ?? this.resourceColumns,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'hitDie': hitDie,
    'primaryAbility': primaryAbility,
    'savingThrows': savingThrows,
    'skills': skills,
    'resource': resource,
    'recovery': recovery,
    'spellcaster': spellcaster,
    'spellcastingAbility': spellcastingAbility,
    'description': description,
    'levelFeatures': levelFeatures,
    'asiLevels': asiLevels,
    'resourceColumns': [for (final c in resourceColumns) c.toMap()],
    'updatedAt': updatedAt,
  };

  factory AdminClassDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminClassDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        hitDie: map['hitDie'] as String? ?? 'd8',
        primaryAbility: map['primaryAbility'] as String? ?? 'Force',
        savingThrows: map['savingThrows'] as String? ?? '',
        skills: map['skills'] as String? ?? '',
        resource: map['resource'] as String? ?? '',
        recovery: map['recovery'] as String? ?? 'Repos long',
        spellcaster: map['spellcaster'] as bool? ?? false,
        spellcastingAbility:
            map['spellcastingAbility'] as String? ?? 'Intelligence',
        description: map['description'] as String? ?? '',
        levelFeatures: levelTexts(map['levelFeatures']),
        asiLevels:
            map['asiLevels'] == null
                ? defaultAsiLevels
                : [for (final l in map['asiLevels'] as List) l as int],
        resourceColumns: [
          for (final c in (map['resourceColumns'] as List?) ?? const [])
            ResourceColumn.fromMap(c as Map),
        ],
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
