/// Origine du contenu d'une espèce, affichée en badge dans l'éditeur.
enum SpeciesSource {
  srd('SRD 5.2 (contenu ouvert)', 'SRD'),
  official('Contenu officiel (ouvrage à préciser)', 'Officiel'),
  homebrew('Homebrew (contenu maison)', 'Homebrew');

  const SpeciesSource(this.label, this.shortLabel);

  final String label;

  /// Libellé court affiché en badge dans la liste.
  final String shortLabel;

  static SpeciesSource fromName(String? name) => SpeciesSource.values
      .firstWhere((s) => s.name == name, orElse: () => SpeciesSource.srd);
}

/// Une espèce telle qu'éditée par un admin : `content/species/{id}` dans
/// Firestore. Fusionnée à l'affichage avec le pack SRD statique (voir
/// `mergeSpecies` dans `admin_providers.dart`) — une espèce du pack sans
/// document ici reste en lecture · dès qu'un admin l'enregistre, ce document
/// prend le dessus, y compris pour une espèce d'origine SRD.
class AdminSpeciesDoc {
  const AdminSpeciesDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.srd,
    this.sourcebook = '',
    this.size = 'Moyenne',
    this.speed = '',
    this.vision = '',
    this.languages = '',
    this.traits = '',
    this.description = '',
  });

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;
  final String size;
  final String speed;
  final String vision;
  final String languages;
  final String traits;
  final String description;
  final DateTime updatedAt;

  AdminSpeciesDoc copyWith({
    String? name,
    SpeciesSource? source,
    String? sourcebook,
    String? size,
    String? speed,
    String? vision,
    String? languages,
    String? traits,
    String? description,
    DateTime? updatedAt,
  }) => AdminSpeciesDoc(
    id: id,
    name: name ?? this.name,
    source: source ?? this.source,
    sourcebook: sourcebook ?? this.sourcebook,
    size: size ?? this.size,
    speed: speed ?? this.speed,
    vision: vision ?? this.vision,
    languages: languages ?? this.languages,
    traits: traits ?? this.traits,
    description: description ?? this.description,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'size': size,
    'speed': speed,
    'vision': vision,
    'languages': languages,
    'traits': traits,
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminSpeciesDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminSpeciesDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        size: map['size'] as String? ?? 'Moyenne',
        speed: map['speed'] as String? ?? '',
        vision: map['vision'] as String? ?? '',
        languages: map['languages'] as String? ?? '',
        traits: map['traits'] as String? ?? '',
        description: map['description'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
