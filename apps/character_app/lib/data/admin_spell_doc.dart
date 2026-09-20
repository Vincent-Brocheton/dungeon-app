import 'admin_species_doc.dart' show SpeciesSource;

/// Un sort : `content/spells/{id}` dans Firestore. Comme les sous-espèces,
/// aucun sort n'existe dans le pack SRD statique — tout est admin-créé, pas
/// de fusion à faire.
class AdminSpellDoc {
  const AdminSpellDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.level = 1,
    this.school = 'Évocation',
    this.castingTime = '',
    this.range = '',
    this.components = '',
    this.duration = '',
    this.classes = '',
    this.rollType = 'Aucun',
    this.saveAbility = 'Dextérité',
    this.onSuccess = 'Moitié des dégâts',
    this.description = '',
  });

  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;

  /// 0 = tour de magie, 1 à 9 sinon.
  final int level;
  final String school;
  final String castingTime;
  final String range;
  final String components;
  final String duration;

  /// Liste libre, séparée par des virgules (ex. « Ensorceleur, Magicien »).
  final String classes;

  /// « Jet de sauvegarde », « Jet d'attaque de sort » ou « Aucun ».
  final String rollType;

  /// Caractéristique visée par le jet de sauvegarde, si `rollType` en impose un.
  final String saveAbility;

  /// Effet en cas de réussite du jet (sauvegarde ou attaque).
  final String onSuccess;
  final String description;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'level': level,
    'school': school,
    'castingTime': castingTime,
    'range': range,
    'components': components,
    'duration': duration,
    'classes': classes,
    'rollType': rollType,
    'saveAbility': saveAbility,
    'onSuccess': onSuccess,
    'description': description,
    'updatedAt': updatedAt,
  };

  factory AdminSpellDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminSpellDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        level: map['level'] as int? ?? 1,
        school: map['school'] as String? ?? 'Évocation',
        castingTime: map['castingTime'] as String? ?? '',
        range: map['range'] as String? ?? '',
        components: map['components'] as String? ?? '',
        duration: map['duration'] as String? ?? '',
        classes: map['classes'] as String? ?? '',
        rollType: map['rollType'] as String? ?? 'Aucun',
        saveAbility: map['saveAbility'] as String? ?? 'Dextérité',
        onSuccess: map['onSuccess'] as String? ?? 'Moitié des dégâts',
        description: map['description'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
