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
    this.inventory = const [],
    this.gold = 0,
    this.hpLost = 0,
    this.tempHp = 0,
    this.hitDiceUsed = 0,
    this.deathSuccesses = 0,
    this.deathFailures = 0,
    this.spellIds = const [],
    this.slotsUsed = const [],
    this.conditions = const [],
    this.exhaustion = 0,
    this.heroicInspiration = false,
    this.personalityTrait = '',
    this.ideal = '',
    this.bond = '',
    this.flaw = '',
    this.backstory = '',
    this.allies = '',
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

  /// Inventaire : objets, quantités, objets portés.
  final List<InventoryItem> inventory;

  /// Pièces d'or.
  final int gold;

  /// PV perdus : on stocke l'écart au maximum, qui lui est dérivé.
  final int hpLost;

  /// Points de vie temporaires.
  final int tempHp;

  /// Dés de vie dépensés depuis le dernier repos long.
  final int hitDiceUsed;

  /// Jets de sauvegarde contre la mort, à 0 PV (0 à 3 chacun).
  final int deathSuccesses;
  final int deathFailures;

  DeathSaves get deathSaves =>
      DeathSaves(successes: deathSuccesses, failures: deathFailures);

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

  /// Personnalité (onglet Notes) : trait, idéal, lien, défaut.
  final String personalityTrait;
  final String ideal;
  final String bond;
  final String flaw;

  /// Histoire du personnage.
  final String backstory;

  /// Alliés et organisations.
  final String allies;

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
    List<InventoryItem>? inventory,
    int? gold,
    int? hpLost,
    int? tempHp,
    int? hitDiceUsed,
    DeathSaves? deathSaves,
    List<String>? spellIds,
    List<int>? slotsUsed,
    List<String>? conditions,
    int? exhaustion,
    bool? heroicInspiration,
    String? personalityTrait,
    String? ideal,
    String? bond,
    String? flaw,
    String? backstory,
    String? allies,
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
    inventory: inventory ?? this.inventory,
    gold: gold ?? this.gold,
    hpLost: hpLost ?? this.hpLost,
    tempHp: tempHp ?? this.tempHp,
    hitDiceUsed: hitDiceUsed ?? this.hitDiceUsed,
    deathSuccesses: deathSaves?.successes ?? deathSuccesses,
    deathFailures: deathSaves?.failures ?? deathFailures,
    spellIds: spellIds ?? this.spellIds,
    slotsUsed: slotsUsed ?? this.slotsUsed,
    conditions: conditions ?? this.conditions,
    exhaustion: exhaustion ?? this.exhaustion,
    heroicInspiration: heroicInspiration ?? this.heroicInspiration,
    personalityTrait: personalityTrait ?? this.personalityTrait,
    ideal: ideal ?? this.ideal,
    bond: bond ?? this.bond,
    flaw: flaw ?? this.flaw,
    backstory: backstory ?? this.backstory,
    allies: allies ?? this.allies,
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
    'inventory': [for (final i in inventory) i.toMap()],
    'gold': gold,
    'hpLost': hpLost,
    'tempHp': tempHp,
    'hitDiceUsed': hitDiceUsed,
    'deathSuccesses': deathSuccesses,
    'deathFailures': deathFailures,
    'spellIds': spellIds,
    'slotsUsed': slotsUsed,
    'conditions': conditions,
    'exhaustion': exhaustion,
    'heroicInspiration': heroicInspiration,
    'personalityTrait': personalityTrait,
    'ideal': ideal,
    'bond': bond,
    'flaw': flaw,
    'backstory': backstory,
    'allies': allies,
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
      // Avant l'inventaire, l'équipement était une liste de noms.
      inventory: switch (map['inventory']) {
        final List<Object?> items => [
          for (final i in items)
            InventoryItem.fromMap((i! as Map).cast<String, Object?>()),
        ],
        _ => [
          for (final e in (map['equipment'] as List?) ?? const [])
            InventoryItem(name: e as String),
        ],
      },
      gold: map['gold'] as int? ?? 0,
      hpLost: map['hpLost'] as int? ?? 0,
      tempHp: map['tempHp'] as int? ?? 0,
      hitDiceUsed: map['hitDiceUsed'] as int? ?? 0,
      deathSuccesses: map['deathSuccesses'] as int? ?? 0,
      deathFailures: map['deathFailures'] as int? ?? 0,
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
      personalityTrait: map['personalityTrait'] as String? ?? '',
      ideal: map['ideal'] as String? ?? '',
      bond: map['bond'] as String? ?? '',
      flaw: map['flaw'] as String? ?? '',
      backstory: map['backstory'] as String? ?? '',
      allies: map['allies'] as String? ?? '',
      createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      deletedAt: map['deletedAt'] as DateTime?,
      schemaVersion: map['schemaVersion'] as int? ?? 1,
    );
  }
}

/// Un objet de l'inventaire.
class InventoryItem {
  const InventoryItem({
    required this.name,
    this.quantity = 1,
    this.equipped = false,
  });

  /// Nom ; sert à retrouver l'arme ou l'armure dans le pack.
  final String name;
  final int quantity;

  /// Porté (armure, bouclier, arme en main…).
  final bool equipped;

  InventoryItem copyWith({int? quantity, bool? equipped}) => InventoryItem(
    name: name,
    quantity: quantity ?? this.quantity,
    equipped: equipped ?? this.equipped,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'quantity': quantity,
    'equipped': equipped,
  };

  factory InventoryItem.fromMap(Map<String, Object?> map) => InventoryItem(
    name: map['name'] as String? ?? 'Objet',
    quantity: map['quantity'] as int? ?? 1,
    equipped: map['equipped'] as bool? ?? false,
  );
}

/// Note de session privée : `users/{uid}/notes/{id}`, hors du document du
/// personnage pour que le MJ (qui lit les personnages) ne la voie pas.
class CharacterNote {
  const CharacterNote({
    required this.id,
    required this.characterId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String characterId;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'characterId': characterId,
    'text': text,
    'createdAt': createdAt,
  };

  factory CharacterNote.fromMap(String id, Map<String, Object?> map) =>
      CharacterNote(
        id: id,
        characterId: map['characterId'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      );
}
