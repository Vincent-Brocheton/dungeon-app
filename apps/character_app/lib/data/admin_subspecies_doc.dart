import 'admin_species_doc.dart' show SpeciesSource;

/// Une sous-espèce (variante rattachée à une espèce parente, ex. Haut-Elfe
/// pour Elfe) : `content/subspecies/{id}` dans Firestore. Contrairement aux
/// espèces, il n'existe aucune sous-espèce dans le pack SRD statique — tout
/// vient d'ici, pas de fusion à faire.
class AdminSubspeciesDoc {
  const AdminSubspeciesDoc({
    required this.id,
    required this.name,
    required this.parentSpeciesId,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.speed = '',
    this.vision = '',
    this.extraTrait = '',
    this.traits = '',
    this.description = '',
  });

  final String id;
  final String name;
  final String parentSpeciesId;
  final SpeciesSource source;
  final String sourcebook;

  /// Remplace ou complète la vitesse de l'espèce parente (ex. « 9 m, Nage 9 m »).
  final String speed;
  final String vision;
  final String extraTrait;
  final String traits;
  final String description;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'parentSpeciesId': parentSpeciesId,
    'source': source.name,
    'sourcebook': sourcebook,
    'speed': speed,
    'vision': vision,
    'extraTrait': extraTrait,
    'traits': traits,
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminSubspeciesDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminSubspeciesDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        parentSpeciesId: map['parentSpeciesId'] as String? ?? '',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        speed: map['speed'] as String? ?? '',
        vision: map['vision'] as String? ?? '',
        extraTrait: map['extraTrait'] as String? ?? '',
        traits: map['traits'] as String? ?? '',
        description: map['description'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
