import 'admin_species_doc.dart' show SpeciesSource;
import 'content_repository.dart';

/// Un historique (PHB 2024 : 3 caractéristiques, un Don d'Origine, 2
/// compétences, 1 outil) tel qu'édité par un admin : `content/backgrounds/{id}`
/// dans Firestore. Fusionné avec le pack SRD statique comme les espèces
/// (voir `mergeBackgrounds`).
class AdminBackgroundDoc implements ContentDoc {
  const AdminBackgroundDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.abilities = const [],
    this.originFeat = '',
    this.skills = '',
    this.tool = '',
    this.equipment = '',
    this.description = '',
  });

  @override
  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;

  /// Les 3 caractéristiques éligibles (libellés français).
  final List<String> abilities;
  final String originFeat;

  /// Texte libre (ex. « Discrétion, Persuasion »).
  final String skills;
  final String tool;
  final String equipment;
  final String description;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'abilities': abilities,
    'originFeat': originFeat,
    'skills': skills,
    'tool': tool,
    'equipment': equipment,
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminBackgroundDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminBackgroundDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        abilities: [
          for (final a in (map['abilities'] as List?) ?? const []) a as String,
        ],
        originFeat: map['originFeat'] as String? ?? '',
        skills: map['skills'] as String? ?? '',
        tool: map['tool'] as String? ?? '',
        equipment: map['equipment'] as String? ?? '',
        description: map['description'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
