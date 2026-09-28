import 'admin_class_doc.dart' show levelTexts;
import 'admin_species_doc.dart' show SpeciesSource;
import 'content_repository.dart';

/// Une sous-classe (rattachée à une classe parente, ex. École d'Évocation
/// pour Magicien) : `content/subclasses/{id}` dans Firestore. Aucune dans le
/// pack SRD statique — tout est admin-créé, comme les classes.
class AdminSubclassDoc implements ContentDoc {
  const AdminSubclassDoc({
    required this.id,
    required this.name,
    required this.parentClassId,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.level = 3,
    this.features = '',
    this.description = '',
    this.levelFeatures = const [],
  });

  @override
  final String id;
  final String name;
  final String parentClassId;
  final SpeciesSource source;
  final String sourcebook;

  /// Niveau de classe auquel la sous-classe est choisie.
  final int level;

  /// Résumé des aptitudes principales, texte libre.
  final String features;
  final String description;

  /// Aptitudes de sous-classe par niveau (index 0 = niveau 1).
  final List<String> levelFeatures;
  final DateTime updatedAt;

  AdminSubclassDoc copyWith({
    String? name,
    String? parentClassId,
    SpeciesSource? source,
    String? sourcebook,
    int? level,
    String? features,
    String? description,
    List<String>? levelFeatures,
    DateTime? updatedAt,
  }) => AdminSubclassDoc(
    id: id,
    name: name ?? this.name,
    parentClassId: parentClassId ?? this.parentClassId,
    source: source ?? this.source,
    sourcebook: sourcebook ?? this.sourcebook,
    level: level ?? this.level,
    features: features ?? this.features,
    description: description ?? this.description,
    levelFeatures: levelFeatures ?? this.levelFeatures,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  Map<String, Object?> toMap() => {
    'name': name,
    'parentClassId': parentClassId,
    'source': source.name,
    'sourcebook': sourcebook,
    'level': level,
    'features': features,
    'description': description,
    'levelFeatures': levelFeatures,
    'updatedAt': updatedAt,
  };

  factory AdminSubclassDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminSubclassDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        parentClassId: map['parentClassId'] as String? ?? '',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        level: map['level'] as int? ?? 3,
        features: map['features'] as String? ?? '',
        description: map['description'] as String? ?? '',
        levelFeatures: levelTexts(map['levelFeatures']),
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
