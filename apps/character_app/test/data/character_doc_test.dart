import 'package:character_app/data/character_doc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un ancien document (équipement en noms) est relu en inventaire', () {
    final doc = CharacterDoc.fromMap('c', {
      'name': 'Durgan',
      'equipment': ['Épée longue', 'Corde'],
    });
    expect([for (final i in doc.inventory) i.name], ['Épée longue', 'Corde']);
    expect(doc.inventory.first.quantity, 1);
    expect(doc.inventory.first.equipped, isFalse);
  });

  test("l'inventaire fait l'aller-retour", () {
    final doc = CharacterDoc.fromMap('c', {
      'name': 'Durgan',
      'inventory': [
        {'name': 'Bouclier', 'quantity': 1, 'equipped': true},
        {'name': 'Rations', 'quantity': 5, 'equipped': false},
      ],
    });
    final again = CharacterDoc.fromMap('c', doc.toMap());
    expect(again.inventory.first.equipped, isTrue);
    expect(again.inventory.last.quantity, 5);
  });
}
