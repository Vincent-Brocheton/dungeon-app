import 'admin_species_doc.dart' show SpeciesSource;

/// Document éditable par un admin (espèce, sort, monstre, PNJ…) : un
/// identifiant et sa représentation stockée.
abstract interface class ContentDoc {
  String get id;

  /// Origine du contenu (SRD, officiel, homebrew).
  SpeciesSource get source;

  Map<String, Object?> toMap();
}

/// Accès à une collection de [ContentDoc] éditée par un admin. Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract interface class ContentRepository<T extends ContentDoc> {
  Stream<List<T>> watchAll();

  Future<void> upsert(T doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
