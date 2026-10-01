import 'package:rules_engine/rules_engine.dart';

/// Un personnage tel qu'il est stocké : les choix du joueur, jamais les valeurs dérivées.
///
/// Modèle volontairement minimal tant que le domaine `Character` du moteur n'existe pas ;
/// il grossira avec les phases 1 et 2. `schemaVersion` permet de migrer à la lecture.
class CharacterDoc {
  const CharacterDoc({
    required this.id,
    required this.name,
    required this.scores,
    required this.createdAt,
    required this.updatedAt,
    this.level = 1,
    this.speciesId,
    this.backgroundId,
    this.classId,
    this.subspeciesId,
    this.alignment,
    this.languages = const [],
    this.equipment = const [],
    this.gold = 0,
    this.hpLost = 0,
    this.tempHp = 0,
    this.hitDiceUsed = 0,
    this.spellIds = const [],
    this.slotsUsed = const [],
    this.conditions = const [],
    this.exhaustion = 0,
    this.heroicInspiration = false,
    this.deletedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Version du schéma de document écrite par cette app.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;
  final AbilityScores scores;
  final int level;
  final String? speciesId;
  final String? backgroundId;
  final String? classId;
  final String? subspeciesId;

  /// Ex. « Loyal Bon ».
  final String? alignment;

  /// Langues parlées, Commun compris.
  final List<String> languages;

  /// Équipement de départ, un objet par entrée (en attendant l'inventaire).
  final List<String> equipment;

  /// Pièces d'or.
  final int gold;

  /// PV perdus : on stocke l'écart au maximum, qui lui est dérivé.
  final int hpLost;

  /// Points de vie temporaires.
  final int tempHp;

  /// Dés de vie dépensés depuis le dernier repos long.
  final int hitDiceUsed;

  /// Sorts connus ou préparés (identifiants de `content/spells`).
  final List<String> spellIds;

  /// Emplacements dépensés depuis le dernier repos long (index 0 = niveau 1).
  final List<int> slotsUsed;

  /// Conditions actives (noms de [Condition]).
  final List<String> conditions;

  /// Niveau d'épuisement, 0 à 6.
  final int exhaustion;

  /// Inspiration héroïque disponible.
  final bool heroicInspiration;

  /// [conditions] reconnues par le moteur.
  Set<Condition> get activeConditions => {
    for (final c in Condition.values)
      if (conditions.contains(c.name)) c,
  };
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Suppression douce : le document reste pour la synchro, l'UI le masque.
  final DateTime? deletedAt;
  final int schemaVersion;

  bool get isDeleted => deletedAt != null;

  CharacterDoc copyWith({
    String? name,
    AbilityScores? scores,
    int? level,
    String? speciesId,
    String? backgroundId,
    String? classId,
    String? subspeciesId,
    String? alignment,
    List<String>? languages,
    List<String>? equipment,
    int? gold,
    int? hpLost,
    int? tempHp,
    int? hitDiceUsed,
    List<String>? spellIds,
    List<int>? slotsUsed,
    List<String>? conditions,
    int? exhaustion,
    bool? heroicInspiration,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => CharacterDoc(
    id: id,
    name: name ?? this.name,
    scores: scores ?? this.scores,
    level: level ?? this.level,
    speciesId: speciesId ?? this.speciesId,
    backgroundId: backgroundId ?? this.backgroundId,
    classId: classId ?? this.classId,
    subspeciesId: subspeciesId ?? this.subspeciesId,
    alignment: alignment ?? this.alignment,
    languages: languages ?? this.languages,
    equipment: equipment ?? this.equipment,
    gold: gold ?? this.gold,
    hpLost: hpLost ?? this.hpLost,
    tempHp: tempHp ?? this.tempHp,
    hitDiceUsed: hitDiceUsed ?? this.hitDiceUsed,
    spellIds: spellIds ?? this.spellIds,
    slotsUsed: slotsUsed ?? this.slotsUsed,
    conditions: conditions ?? this.conditions,
    exhaustion: exhaustion ?? this.exhaustion,
    heroicInspiration: heroicInspiration ?? this.heroicInspiration,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    schemaVersion: schemaVersion,
  );

  /// Forme sérialisée, sans type propre à un backend (les dates restent des [DateTime]).
  Map<String, Object?> toMap() => {
    'schemaVersion': schemaVersion,
    'name': name,
    'level': level,
    'speciesId': speciesId,
    'backgroundId': backgroundId,
    'classId': classId,
    'subspeciesId': subspeciesId,
    'alignment': alignment,
    'languages': languages,
    'equipment': equipment,
    'gold': gold,
    'hpLost': hpLost,
    'tempHp': tempHp,
    'hitDiceUsed': hitDiceUsed,
    'spellIds': spellIds,
    'slotsUsed': slotsUsed,
    'conditions': conditions,
    'exhaustion': exhaustion,
    'heroicInspiration': heroicInspiration,
    'abilityScores': {for (final a in Ability.values) a.code: scores[a]},
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
  };

  /// Lit un document. Point d'entrée des futures migrations par `schemaVersion`.
  factory CharacterDoc.fromMap(String id, Map<String, Object?> map) {
    final rawScores =
        (map['abilityScores'] as Map<Object?, Object?>?)
            ?.cast<String, Object?>() ??
        const <String, Object?>{};
    return CharacterDoc(
      id: id,
      name: map['name'] as String? ?? 'Sans nom',
      scores: AbilityScores.fromMap({
        for (final a in Ability.values)
          if (rawScores[a.code] is int) a: rawScores[a.code] as int,
      }),
      level: map['level'] as int? ?? 1,
      speciesId: map['speciesId'] as String?,
      backgroundId: map['backgroundId'] as String?,
      classId: map['classId'] as String?,
      subspeciesId: map['subspeciesId'] as String?,
      alignment: map['alignment'] as String?,
      languages: [
        for (final l in (map['languages'] as List?) ?? const []) l as String,
      ],
      equipment: [
        for (final e in (map['equipment'] as List?) ?? const []) e as String,
      ],
      gold: map['gold'] as int? ?? 0,
      hpLost: map['hpLost'] as int? ?? 0,
      tempHp: map['tempHp'] as int? ?? 0,
      hitDiceUsed: map['hitDiceUsed'] as int? ?? 0,
      spellIds: [
        for (final s in (map['spellIds'] as List?) ?? const []) s as String,
      ],
      slotsUsed: [
        for (final n in (map['slotsUsed'] as List?) ?? const []) n as int,
      ],
      conditions: [
        for (final c in (map['conditions'] as List?) ?? const []) c as String,
      ],
      exhaustion: map['exhaustion'] as int? ?? 0,
      heroicInspiration: map['heroicInspiration'] as bool? ?? false,
      createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      deletedAt: map['deletedAt'] as DateTime?,
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }
}
