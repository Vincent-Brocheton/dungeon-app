import 'admin_species_doc.dart' show SpeciesSource;

/// Un don : `content/feats/{id}` dans Firestore. Comme les sorts, aucun don
/// n'existe dans le pack SRD statique — tout est admin-créé.
class AdminFeatDoc {
  const AdminFeatDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.summary = '',
    this.category = 'Don général',
    this.levelMinimum = 1,
    this.otherPrerequisites = '',
    this.repeatable = false,
    this.eligibleAbilities = const [
      'Force',
      'Dextérité',
      'Constitution',
      'Intelligence',
      'Sagesse',
      'Charisme',
    ],
    this.pointsToDistribute = 2,
    this.distribution = defaultDistribution,
    this.maxValue = 20,
    this.effect = '',
  });

  static const defaultDistribution =
      'Une seule, ou 1 sur deux caractéristiques différentes';

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;
  final String summary;

  /// « Don d'origine », « Don général », « Don de style de combat » ou
  /// « Don de faveur épique ».
  final String category;
  final int levelMinimum;

  /// Texte libre (ex. « Force ou Dextérité 13 ou plus »).
  final String otherPrerequisites;
  final bool repeatable;

  /// Caractéristiques que le joueur peut choisir pour le bonus ci-dessous.
  final List<String> eligibleAbilities;
  final int pointsToDistribute;

  /// « Sur une seule caractéristique », « Une seule, ou 1 sur deux
  /// caractéristiques différentes » ou « Répartis librement (1 par
  /// caractéristique) ».
  final String distribution;
  final int maxValue;
  final String effect;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'summary': summary,
    'category': category,
    'levelMinimum': levelMinimum,
    'otherPrerequisites': otherPrerequisites,
    'repeatable': repeatable,
    'eligibleAbilities': eligibleAbilities,
    'pointsToDistribute': pointsToDistribute,
    'distribution': distribution,
    'maxValue': maxValue,
    'effect': effect,
    'updatedAt': updatedAt,
  };

  factory AdminFeatDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminFeatDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        summary: map['summary'] as String? ?? '',
        category: map['category'] as String? ?? 'Don général',
        levelMinimum: map['levelMinimum'] as int? ?? 1,
        otherPrerequisites: map['otherPrerequisites'] as String? ?? '',
        repeatable: map['repeatable'] as bool? ?? false,
        eligibleAbilities: [
          for (final a in (map['eligibleAbilities'] as List?) ?? const [])
            a as String,
        ],
        pointsToDistribute: map['pointsToDistribute'] as int? ?? 2,
        distribution: map['distribution'] as String? ?? defaultDistribution,
        maxValue: map['maxValue'] as int? ?? 20,
        effect: map['effect'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
