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

  test("le journal de la bourse fait l'aller-retour, date en ms", () {
    final at = DateTime.fromMillisecondsSinceEpoch(1790000000000);
    final doc = CharacterDoc.fromMap('c', {'name': 'Durgan'}).copyWith(
      silver: 3,
      moneyLog: [
        MoneyMovement(label: 'Vente', coin: Coin.silver, amount: -2, at: at),
      ],
    );
    final map = doc.toMap();
    expect(
      (map['moneyLog']! as List).single,
      containsPair('at', 1790000000000),
    );
    final again = CharacterDoc.fromMap('c', map);
    expect(again.silver, 3);
    expect(again.moneyLog.single.coin, Coin.silver);
    expect(again.moneyLog.single.amount, -2);
    expect(again.moneyLog.single.at, at);
  });
}
