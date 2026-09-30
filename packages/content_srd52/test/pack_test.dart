import 'dart:io';

import 'package:content_srd52/content_srd52.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  // `flutter test` s'exécute depuis la racine du paquet.
  final raw = File('assets/srd52/pack.json').readAsStringSync();

  test(
    'le pack embarqué se parse et correspond au schéma lu par le moteur',
    () {
      final pack = parseContentPack(raw);
      expect(pack.schemaVersion, supportedSchemaVersion);
      expect(pack.id, 'srd-5.2');
      expect(pack.license, 'CC-BY-4.0');
      expect(
        pack.attribution,
        isNotEmpty,
        reason: 'CC-BY exige une attribution',
      );
    },
  );

  test('les identifiants sont uniques', () {
    final pack = parseContentPack(raw);
    final ids = [
      ...pack.species.map((s) => s.id),
      ...pack.backgrounds.map((b) => b.id),
      ...pack.weapons.map((w) => w.id),
    ];
    expect(ids.toSet().length, ids.length);
  });

  test("les armes du PHB 2024, nommées comme dans l'équipement", () {
    final weapons = {for (final w in parseContentPack(raw).weapons) w.name: w};
    expect(weapons['Épée longue']?.damage, '1d8');
    expect(weapons['Épée à deux mains']?.damage, '2d6');
    expect(weapons['Rapière']?.finesse, isTrue);
    expect(weapons['Arc long']?.ranged, isTrue);
  });

  test('loadSrd52Pack lit l\'asset via le bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pack = await loadSrd52Pack();
    expect(pack.species, isNotEmpty);
  });
}
