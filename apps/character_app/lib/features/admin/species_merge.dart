import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_species_doc.dart';

/// Fusionne le pack SRD statique et les surcharges admin (Firestore) :
/// une espèce du pack sans override apparaît en lecture (source SRD,
/// convertie pour l'affichage) ; un override remplace entièrement l'entrée
/// correspondante, y compris pour un id d'origine SRD ; un override sans
/// entrée SRD correspondante s'ajoute (nouveau contenu homebrew).
List<AdminSpeciesDoc> mergeSpecies(
  ContentPack? pack,
  List<AdminSpeciesDoc> overrides,
) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final byId = <String, AdminSpeciesDoc>{
    for (final species in pack?.species ?? const <SpeciesDef>[])
      species.id: AdminSpeciesDoc(
        id: species.id,
        name: species.name,
        updatedAt: epoch,
        size: species.sizeOptions.contains('medium') ? 'Moyenne' : 'Petite',
        speed: '${(species.speed * 0.3).round()} m',
      ),
  };
  for (final override in overrides) {
    byId[override.id] = override;
  }
  return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
