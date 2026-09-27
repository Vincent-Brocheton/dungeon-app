import 'admin_species_doc.dart' show SpeciesSource;

/// Entrée nommée d'un bloc de stats (aptitude, action, réaction…), avec la
/// résolution automatique prévue pour le suivi de combat.
class MonsterEntry {
  const MonsterEntry({
    required this.name,
    required this.text,
    this.roll = 'Aucun',
    this.saveAbility = 'Constitution',
    this.dc = '',
  });

  static const rolls = ['Aucun', 'Attaque', 'Sauvegarde'];

  final String name;
  final String text;

  /// Jet imposé : « Aucun », « Attaque » ou « Sauvegarde ».
  final String roll;

  /// Caractéristique de la cible pour une sauvegarde.
  final String saveAbility;

  /// DD fixé par la source ; vide = à recalculer depuis les caractéristiques.
  final String dc;

  Map<String, Object?> toMap() => {
    'name': name,
    'text': text,
    'roll': roll,
    'saveAbility': saveAbility,
    'dc': dc,
  };

  factory MonsterEntry.fromMap(Map<Object?, Object?> map) => MonsterEntry(
    name: map['name'] as String? ?? '',
    text: map['text'] as String? ?? '',
    roll: map['roll'] as String? ?? 'Aucun',
    saveAbility: map['saveAbility'] as String? ?? 'Constitution',
    dc: map['dc'] as String? ?? '',
  );
}

/// Un monstre (bloc de stats) : `content/monsters/{id}` dans Firestore.
/// Aucun dans le pack SRD statique — tout est admin-créé.
class AdminMonsterDoc {
  const AdminMonsterDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.summary = '',
    this.subtype = '',
    this.type = 'Humanoïde',
    this.size = 'Moyenne',
    this.alignment = 'Neutre',
    this.cr = '',
    this.armorClass = '',
    this.hitPoints = '',
    this.speeds = const ['', '', '', '', ''],
    this.abilityScores = const [10, 10, 10, 10, 10, 10],
    this.savingThrows = '',
    this.skills = '',
    this.damageResistances = '',
    this.damageImmunities = '',
    this.damageVulnerabilities = '',
    this.conditionImmunities = '',
    this.senses = '',
    this.languages = '',
    this.traits = const [],
    this.actions = const [],
    this.bonusActions = const [],
    this.reactions = const [],
    this.legendaryActions = const [],
    this.description = '',
  });

  static const types = [
    'Humanoïde',
    'Bête',
    'Mort-vivant',
    'Fiélon',
    'Dragon',
    'Géant',
    'Monstruosité',
    'Céleste',
    'Élémentaire',
    'Fée',
    'Aberration',
    'Construction',
    'Vase',
    'Plante',
  ];
  static const alignments = [
    'Loyal Bon',
    'Neutre Bon',
    'Chaotique Bon',
    'Loyal Neutre',
    'Neutre',
    'Chaotique Neutre',
    'Loyal Mauvais',
    'Neutre Mauvais',
    'Chaotique Mauvais',
    'Non aligné',
  ];

  /// Libellés des 5 vitesses de [speeds], dans l'ordre.
  static const speedLabels = [
    'Marche',
    'Vol',
    'Nage',
    'Escalade',
    'Creusement',
  ];

  /// Champs texte du bloc de stats, clés de [toMap] (l'éditeur leur associe
  /// un champ de saisie chacun).
  static const textFields = [
    'sourcebook',
    'summary',
    'subtype',
    'size',
    'cr',
    'armorClass',
    'hitPoints',
    'savingThrows',
    'skills',
    'damageResistances',
    'damageImmunities',
    'damageVulnerabilities',
    'conditionImmunities',
    'senses',
    'languages',
    'description',
  ];

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;
  final String summary;
  final String subtype;
  final String type;
  final String size;
  final String alignment;

  /// Dangerosité, texte libre (ex. « 3 (700 PX) »).
  final String cr;
  final String armorClass;

  /// Texte libre (ex. « 71 (11d8 + 22) »).
  final String hitPoints;

  /// Marche, vol, nage, escalade, creusement (voir [speedLabels]).
  final List<String> speeds;

  /// For, Dex, Con, Int, Sag, Cha.
  final List<int> abilityScores;
  final String savingThrows;
  final String skills;
  final String damageResistances;
  final String damageImmunities;
  final String damageVulnerabilities;
  final String conditionImmunities;
  final String senses;
  final String languages;
  final List<MonsterEntry> traits;
  final List<MonsterEntry> actions;
  final List<MonsterEntry> bonusActions;
  final List<MonsterEntry> reactions;
  final List<MonsterEntry> legendaryActions;
  final String description;
  final DateTime updatedAt;

  /// « Monstruosité (lycanthrope) moyenne, chaotique mauvais · Dangerosité 3 ».
  String get statLine {
    final kind =
        subtype.trim().isEmpty
            ? type
            : '$type (${subtype.trim().toLowerCase()})';
    final line = '$kind ${size.toLowerCase()}, ${alignment.toLowerCase()}';
    return cr.trim().isEmpty ? line : '$line · Dangerosité ${cr.trim()}';
  }

  /// Sous le nom dans la liste : « FP 3 · Monstruosité ».
  String get listLabel {
    final fp = cr.trim().split(' ').first;
    return fp.isEmpty ? type : 'FP $fp · $type';
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'summary': summary,
    'subtype': subtype,
    'type': type,
    'size': size,
    'alignment': alignment,
    'cr': cr,
    'armorClass': armorClass,
    'hitPoints': hitPoints,
    'speeds': speeds,
    'abilityScores': abilityScores,
    'savingThrows': savingThrows,
    'skills': skills,
    'damageResistances': damageResistances,
    'damageImmunities': damageImmunities,
    'damageVulnerabilities': damageVulnerabilities,
    'conditionImmunities': conditionImmunities,
    'senses': senses,
    'languages': languages,
    'traits': [for (final e in traits) e.toMap()],
    'actions': [for (final e in actions) e.toMap()],
    'bonusActions': [for (final e in bonusActions) e.toMap()],
    'reactions': [for (final e in reactions) e.toMap()],
    'legendaryActions': [for (final e in legendaryActions) e.toMap()],
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminMonsterDoc.fromMap(String id, Map<String, Object?> map) {
    String text(String key) => map[key] as String? ?? '';
    List<MonsterEntry> entries(String key) => [
      for (final e in (map[key] as List?) ?? const [])
        MonsterEntry.fromMap(e as Map),
    ];
    final speeds = [for (final s in (map['speeds'] as List?) ?? const []) '$s'];
    final scores = [
      for (final s in (map['abilityScores'] as List?) ?? const []) s as int,
    ];
    return AdminMonsterDoc(
      id: id,
      name: map['name'] as String? ?? 'Sans nom',
      source: SpeciesSource.fromName(map['source'] as String?),
      sourcebook: text('sourcebook'),
      summary: text('summary'),
      subtype: text('subtype'),
      type: map['type'] as String? ?? 'Humanoïde',
      size: map['size'] as String? ?? 'Moyenne',
      alignment: map['alignment'] as String? ?? 'Neutre',
      cr: text('cr'),
      armorClass: text('armorClass'),
      hitPoints: text('hitPoints'),
      speeds: [for (var i = 0; i < 5; i++) i < speeds.length ? speeds[i] : ''],
      abilityScores: [
        for (var i = 0; i < 6; i++) i < scores.length ? scores[i] : 10,
      ],
      savingThrows: text('savingThrows'),
      skills: text('skills'),
      damageResistances: text('damageResistances'),
      damageImmunities: text('damageImmunities'),
      damageVulnerabilities: text('damageVulnerabilities'),
      conditionImmunities: text('conditionImmunities'),
      senses: text('senses'),
      languages: text('languages'),
      traits: entries('traits'),
      actions: entries('actions'),
      bonusActions: entries('bonusActions'),
      reactions: entries('reactions'),
      legendaryActions: entries('legendaryActions'),
      description: text('description'),
      updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
    );
  }
}
