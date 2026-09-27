import 'admin_species_doc.dart' show SpeciesSource;

/// Une classe : `content/classes/{id}` dans Firestore. Aucune classe dans le
/// pack SRD statique — tout est admin-créé, comme les sorts et les dons.
class AdminClassDoc {
  const AdminClassDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.hitDie = 'd8',
    this.primaryAbility = 'Force',
    this.savingThrows = '',
    this.skills = '',
    this.resource = '',
    this.recovery = 'Repos long',
    this.spellcaster = false,
    this.spellcastingAbility = 'Intelligence',
    this.description = '',
  });

  static const hitDice = ['d6', 'd8', 'd10', 'd12'];
  static const abilities = [
    'Force',
    'Dextérité',
    'Constitution',
    'Intelligence',
    'Sagesse',
    'Charisme',
  ];
  static const recoveries = ['Repos court', 'Repos long'];

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;
  final String hitDie;
  final String primaryAbility;

  /// Texte libre (ex. « Intelligence, Dextérité »).
  final String savingThrows;

  /// Texte libre (ex. « 2 parmi : Arcanes, Histoire… »).
  final String skills;

  /// Ressource principale, texte libre (ex. « Points de Ki »).
  final String resource;
  final String recovery;
  final bool spellcaster;

  /// Utilisée pour le DD de sauvegarde et le bonus d'attaque des sorts.
  final String spellcastingAbility;
  final String description;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'hitDie': hitDie,
    'primaryAbility': primaryAbility,
    'savingThrows': savingThrows,
    'skills': skills,
    'resource': resource,
    'recovery': recovery,
    'spellcaster': spellcaster,
    'spellcastingAbility': spellcastingAbility,
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminClassDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminClassDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        hitDie: map['hitDie'] as String? ?? 'd8',
        primaryAbility: map['primaryAbility'] as String? ?? 'Force',
        savingThrows: map['savingThrows'] as String? ?? '',
        skills: map['skills'] as String? ?? '',
        resource: map['resource'] as String? ?? '',
        recovery: map['recovery'] as String? ?? 'Repos long',
        spellcaster: map['spellcaster'] as bool? ?? false,
        spellcastingAbility:
            map['spellcastingAbility'] as String? ?? 'Intelligence',
        description: map['description'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
