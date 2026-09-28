/// Règle maison de la table, activable.
class HouseRule {
  const HouseRule({required this.name, this.enabled = true});

  final String name;
  final bool enabled;

  Map<String, Object?> toMap() => {'name': name, 'enabled': enabled};

  factory HouseRule.fromMap(Map<Object?, Object?> map) => HouseRule(
    name: map['name'] as String? ?? '',
    enabled: map['enabled'] as bool? ?? true,
  );
}

/// Entrée titrée : séance passée (historique) ou note du journal du MJ.
class TableEntry {
  const TableEntry({required this.title, required this.text});

  final String title;
  final String text;

  Map<String, Object?> toMap() => {'title': title, 'text': text};

  factory TableEntry.fromMap(Map<Object?, Object?> map) => TableEntry(
    title: map['title'] as String? ?? '',
    text: map['text'] as String? ?? '',
  );
}

/// La table du MJ : `table/main` dans Firestore, lisible par les seuls
/// admins (elle contient le journal privé du MJ). Une seule table pour
/// l'instant, comme un seul rôle admin.
class AdminTableDoc {
  const AdminTableDoc({
    required this.updatedAt,
    this.name = '',
    this.world = '',
    this.cadence = '',
    this.houseRules = const [],
    this.restVariant = 'Standard',
    this.maxShortRests = 2,
    this.hitDiceRecovery = 'Tous les dés de vie (règle 2024)',
    this.interruptedLongRest = 'Ne compte pas — à recommencer',
    this.diceRollsInApp = true,
    this.nextSessionWhen = '',
    this.nextSessionWhere = '',
    this.nextSessionNote = '',
    this.sessions = const [],
    this.journal = const [],
  });

  /// Variantes de repos et leur durée (repos court · repos long).
  static const restVariants = [
    ('Standard', 'Repos court 1h · repos long 8h'),
    ('Repos lent (survie)', 'Repos court 1h · repos long 3 jours'),
    ('Repos rapide (héroïque)', 'Repos court 5 min · repos long 1h'),
  ];
  static const hitDiceRecoveries = [
    'Tous les dés de vie (règle 2024)',
    'Moitié des dés de vie (règle classique)',
  ];
  static const interruptedLongRests = [
    'Ne compte pas — à recommencer',
    'Compte partiellement — progrès conservé',
  ];

  /// Champs texte, clés de [toMap] (l'éditeur leur associe un champ chacun).
  static const textFields = [
    'name',
    'world',
    'cadence',
    'nextSessionWhen',
    'nextSessionWhere',
    'nextSessionNote',
  ];

  final String name;
  final String world;

  /// Rythme des séances, texte libre (ex. « Toutes les 2 semaines »).
  final String cadence;
  final List<HouseRule> houseRules;
  final String restVariant;
  final int maxShortRests;
  final String hitDiceRecovery;
  final String interruptedLongRest;

  /// Jets de dés dans l'application ; sinon les joueurs lancent leurs dés
  /// physiques et saisissent le résultat.
  final bool diceRollsInApp;
  final String nextSessionWhen;
  final String nextSessionWhere;
  final String nextSessionNote;

  /// Séances jouées, la plus récente en premier.
  final List<TableEntry> sessions;

  /// Journal privé du MJ, l'entrée la plus récente en premier.
  final List<TableEntry> journal;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'world': world,
    'cadence': cadence,
    'houseRules': [for (final r in houseRules) r.toMap()],
    'restVariant': restVariant,
    'maxShortRests': maxShortRests,
    'hitDiceRecovery': hitDiceRecovery,
    'interruptedLongRest': interruptedLongRest,
    'diceRollsInApp': diceRollsInApp,
    'nextSessionWhen': nextSessionWhen,
    'nextSessionWhere': nextSessionWhere,
    'nextSessionNote': nextSessionNote,
    'sessions': [for (final s in sessions) s.toMap()],
    'journal': [for (final j in journal) j.toMap()],
    'updatedAt': updatedAt,
  };

  factory AdminTableDoc.fromMap(Map<String, Object?> map) {
    String text(String key) => map[key] as String? ?? '';
    List<TableEntry> entries(String key) => [
      for (final e in (map[key] as List?) ?? const [])
        TableEntry.fromMap(e as Map),
    ];
    return AdminTableDoc(
      name: text('name'),
      world: text('world'),
      cadence: text('cadence'),
      houseRules: [
        for (final r in (map['houseRules'] as List?) ?? const [])
          HouseRule.fromMap(r as Map),
      ],
      restVariant: map['restVariant'] as String? ?? 'Standard',
      maxShortRests: map['maxShortRests'] as int? ?? 2,
      hitDiceRecovery:
          map['hitDiceRecovery'] as String? ?? hitDiceRecoveries.first,
      interruptedLongRest:
          map['interruptedLongRest'] as String? ?? interruptedLongRests.first,
      diceRollsInApp: map['diceRollsInApp'] as bool? ?? true,
      nextSessionWhen: text('nextSessionWhen'),
      nextSessionWhere: text('nextSessionWhere'),
      nextSessionNote: text('nextSessionNote'),
      sessions: entries('sessions'),
      journal: entries('journal'),
      updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
    );
  }
}
