import 'admin_monster_doc.dart';
import 'admin_species_doc.dart' show SpeciesSource;

/// Un PNJ (fiche de scène du MJ) : `npcs/{id}` dans Firestore, lisible par
/// les seuls admins. Bloc de stats plus léger que [AdminMonsterDoc] (une
/// seule vitesse, immunités regroupées, seulement des actions), avec un rôle
/// dans la scène et une espèce liée optionnelle.
class AdminNpcDoc {
  const AdminNpcDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.role = '',
    this.speciesId = '',
    this.type = 'Humanoïde',
    this.size = 'Moyenne',
    this.alignment = 'Neutre',
    this.cr = '1/4',
    this.armorClass = '',
    this.hitPoints = '',
    this.speed = '',
    this.abilityScores = const [10, 10, 10, 10, 10, 10],
    this.resistances = '',
    this.immunities = '',
    this.vulnerabilities = '',
    this.senses = '',
    this.languages = '',
    this.actions = const [],
    this.description = '',
  });

  static const sizes = [
    'Très petite',
    'Petite',
    'Moyenne',
    'Grande',
    'Très grande',
    'Gigantesque',
  ];

  /// Dangerosités et leurs PX (DMG 2024).
  static const challengeRatings = [
    ('0', 10),
    ('1/8', 25),
    ('1/4', 50),
    ('1/2', 100),
    ('1', 200),
    ('2', 450),
    ('3', 700),
    ('4', 1100),
    ('5', 1800),
    ('6', 2300),
    ('7', 2900),
    ('8', 3900),
    ('9', 5000),
    ('10', 5900),
    ('11', 7200),
    ('12', 8400),
    ('13', 10000),
    ('14', 11500),
    ('15', 13000),
    ('16', 15000),
    ('17', 18000),
    ('18', 20000),
    ('19', 22000),
    ('20', 25000),
    ('21', 33000),
    ('22', 41000),
    ('23', 50000),
    ('24', 62000),
    ('25', 75000),
    ('26', 90000),
    ('27', 105000),
    ('28', 120000),
    ('29', 135000),
    ('30', 155000),
  ];

  /// Champs texte, clés de [toMap] (l'éditeur leur associe un champ chacun).
  static const textFields = [
    'sourcebook',
    'role',
    'armorClass',
    'hitPoints',
    'speed',
    'resistances',
    'immunities',
    'vulnerabilities',
    'senses',
    'languages',
    'description',
  ];

  /// « 3 (700 PX) » ; séparateur de milliers à la française.
  static String crLabel(String cr) {
    final xp =
        challengeRatings.where((c) => c.$1 == cr).firstOrNull?.$2.toString();
    if (xp == null) return cr;
    final grouped = xp.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$cr ($grouped PX)';
  }

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;

  /// Rôle dans la scène (ex. « Chef gobelin », « Boss de scène »).
  final String role;

  /// Espèce jouable liée ; vide = créature du bestiaire.
  final String speciesId;
  final String type;
  final String size;
  final String alignment;

  /// Dangerosité, une des clés de [challengeRatings].
  final String cr;
  final String armorClass;
  final String hitPoints;
  final String speed;

  /// For, Dex, Con, Int, Sag, Cha.
  final List<int> abilityScores;
  final String resistances;

  /// Dégâts et états (ex. « Poison · Charmé, effrayé »).
  final String immunities;
  final String vulnerabilities;
  final String senses;
  final String languages;
  final List<MonsterEntry> actions;
  final String description;
  final DateTime updatedAt;

  /// « Mort-vivant moyenne, chaotique mauvais · Dangerosité 3 (700 PX) ».
  String get statLine =>
      '$type ${size.toLowerCase()}, ${alignment.toLowerCase()} · '
      'Dangerosité ${crLabel(cr)}';

  /// Sous le nom dans la liste : « DP 3 · Boss de scène ».
  String get listLabel =>
      role.trim().isEmpty ? 'DP $cr' : 'DP $cr · ${role.trim()}';

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'role': role,
    'speciesId': speciesId,
    'type': type,
    'size': size,
    'alignment': alignment,
    'cr': cr,
    'armorClass': armorClass,
    'hitPoints': hitPoints,
    'speed': speed,
    'abilityScores': abilityScores,
    'resistances': resistances,
    'immunities': immunities,
    'vulnerabilities': vulnerabilities,
    'senses': senses,
    'languages': languages,
    'actions': [for (final e in actions) e.toMap()],
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminNpcDoc.fromMap(String id, Map<String, Object?> map) {
    String text(String key) => map[key] as String? ?? '';
    final scores = [
      for (final s in (map['abilityScores'] as List?) ?? const []) s as int,
    ];
    return AdminNpcDoc(
      id: id,
      name: map['name'] as String? ?? 'Sans nom',
      source: SpeciesSource.fromName(map['source'] as String?),
      sourcebook: text('sourcebook'),
      role: text('role'),
      speciesId: text('speciesId'),
      type: map['type'] as String? ?? 'Humanoïde',
      size: map['size'] as String? ?? 'Moyenne',
      alignment: map['alignment'] as String? ?? 'Neutre',
      cr: map['cr'] as String? ?? '1/4',
      armorClass: text('armorClass'),
      hitPoints: text('hitPoints'),
      speed: text('speed'),
      abilityScores: [
        for (var i = 0; i < 6; i++) i < scores.length ? scores[i] : 10,
      ],
      resistances: text('resistances'),
      immunities: text('immunities'),
      vulnerabilities: text('vulnerabilities'),
      senses: text('senses'),
      languages: text('languages'),
      actions: [
        for (final e in (map['actions'] as List?) ?? const [])
          MonsterEntry.fromMap(e as Map),
      ],
      description: text('description'),
      updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
    );
  }
}
