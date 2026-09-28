import 'admin_species_doc.dart' show SpeciesSource;
import 'content_repository.dart';

/// Une manifestation occulte (aptitude de pacte de l'Occultiste) :
/// `content/invocations/{id}` dans Firestore. Aucune dans le pack SRD
/// statique — tout est admin-créé, comme les dons.
class AdminInvocationDoc implements ContentDoc {
  const AdminInvocationDoc({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.source = SpeciesSource.homebrew,
    this.sourcebook = '',
    this.summary = '',
    this.level = 1,
    this.otherPrerequisites = '',
    this.repeatable = false,
    this.effect = '',
  });

  @override
  final String id;
  final String name;
  final SpeciesSource source;
  final String sourcebook;
  final String summary;

  /// Niveau d'Occultiste requis ; 1 = aucun prérequis de niveau.
  final int level;

  /// Texte libre (ex. « Manifestation Pacte de la lame »).
  final String otherPrerequisites;
  final bool repeatable;
  final String effect;
  final DateTime updatedAt;

  /// Résumé des prérequis affiché sous le nom dans la liste
  /// (« Niv. 5 · Pacte de la lame », ou « Sans prérequis »).
  String get prerequisitesLabel {
    final parts = [
      if (level > 1) 'Niv. $level',
      if (otherPrerequisites.trim().isNotEmpty) otherPrerequisites.trim(),
    ];
    return parts.isEmpty ? 'Sans prérequis' : parts.join(' · ');
  }

  @override
  Map<String, Object?> toMap() => {
    'name': name,
    'source': source.name,
    'sourcebook': sourcebook,
    'summary': summary,
    'level': level,
    'otherPrerequisites': otherPrerequisites,
    'repeatable': repeatable,
    'effect': effect,
    'updatedAt': updatedAt,
  };

  factory AdminInvocationDoc.fromMap(String id, Map<String, Object?> map) =>
      AdminInvocationDoc(
        id: id,
        name: map['name'] as String? ?? 'Sans nom',
        source: SpeciesSource.fromName(map['source'] as String?),
        sourcebook: map['sourcebook'] as String? ?? '',
        summary: map['summary'] as String? ?? '',
        level: map['level'] as int? ?? 1,
        otherPrerequisites: map['otherPrerequisites'] as String? ?? '',
        repeatable: map['repeatable'] as bool? ?? false,
        effect: map['effect'] as String? ?? '',
        updatedAt: map['updatedAt'] as DateTime? ?? DateTime.now(),
      );
}
