import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_background_doc.dart';
import '../../data/admin_class_doc.dart';
import '../../data/admin_species_doc.dart';

/// Fusionne le pack SRD statique et les surcharges admin (Firestore), comme
/// `mergeSpecies` : un historique du pack sans override apparaît tel quel
/// (source SRD) ; un override remplace entièrement l'entrée de même id ; un
/// override sans entrée SRD s'ajoute.
List<AdminBackgroundDoc> mergeBackgrounds(
  ContentPack? pack,
  List<AdminBackgroundDoc> overrides,
) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final byId = <String, AdminBackgroundDoc>{
    for (final bg in pack?.backgrounds ?? const <BackgroundDef>[])
      bg.id: AdminBackgroundDoc(
        id: bg.id,
        name: bg.name,
        updatedAt: epoch,
        source: SpeciesSource.srd,
        // Même ordre que l'enum Ability.
        abilities: [
          for (final a in Ability.values)
            if (bg.abilities.contains(a)) AdminClassDoc.abilities[a.index],
        ],
        originFeat: bg.originFeat,
        skills: bg.skills.join(', '),
        tool: bg.tool,
      ),
  };
  for (final override in overrides) {
    byId[override.id] = override;
  }
  return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
