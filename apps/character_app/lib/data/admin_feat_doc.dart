import 'admin_species_doc.dart' show SpeciesSource;

/// Un bonus de caractéristique accordé par un don (ex. Constitution +1),
/// appliqué automatiquement à la fiche.
class FeatAbilityBonus {
  const FeatAbilityBonus({required this.ability, required this.amount});

  final String ability;
  final int amount;

  Map<String, Object?> toMap() => {'ability': ability, 'amount': amount};

  factory FeatAbilityBonus.fromMap(Map<String, Object?> map) =>
      FeatAbilityBonus(
        ability: map['ability'] as String? ?? 'Force',
        amount: map['amount'] as int? ?? 1,
      );
}

/// Un don : `content/feats/{id}` dans Firestore. Comme les sorts, aucun don
/// n'existe dans le pack SRD statique — tout est admin-créé.
class AdminFeatDoc {
  const AdminFeatDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.category = 'Général',
    this.prerequisite = '',
    this.repeatable = false,
    this.abilityBonuses = const [],
    this.effect = '',
  });

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;

  /// « Origine », « Général », « Combat » ou « Épique ».
  final String category;
  final String prerequisite;
  final bool repeatable;
  final List<FeatAbilityBonus> abilityBonuses;
  final String effect;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'category': category,
    'prerequisite': prerequisite,
    'repeatable': repeatable,
    'abilityBonuses': [for (final b in abilityBonuses) b.toMap()],
    'effect': effect,
    'updatedAt': updatedAt,
  };

  factory AdminFeatDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminFeatDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        category: map['category'] as String? ?? 'Général',
        prerequisite: map['prerequisite'] as String? ?? '',
        repeatable: map['repeatable'] as bool? ?? false,
        abilityBonuses: [
          for (final raw in (map['abilityBonuses'] as List?) ?? const [])
            FeatAbilityBonus.fromMap((raw as Map).cast<String, Object?>()),
        ],
        effect: map['effect'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
