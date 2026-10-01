import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

const _leather = ArmorDef(
  id: 'cuir',
  name: 'Cuir',
  baseAc: 11,
  category: ArmorCategory.light,
);
const _halfPlate = ArmorDef(
  id: 'demi-plate',
  name: 'Demi-plate',
  baseAc: 15,
  category: ArmorCategory.medium,
);
const _chain = ArmorDef(
  id: 'cotte-de-mailles',
  name: 'Cotte de mailles',
  baseAc: 16,
  category: ArmorCategory.heavy,
);
const _shield = ArmorDef(
  id: 'bouclier',
  name: 'Bouclier',
  baseAc: 2,
  category: ArmorCategory.shield,
);

void main() {
  test('CA selon la catégorie d\'armure, bouclier en plus', () {
    expect(armorClass(3), 13);
    expect(armorClass(3, armor: _leather), 14);
    expect(armorClass(3, armor: _halfPlate), 17);
    expect(armorClass(-1, armor: _halfPlate), 14);
    expect(armorClass(3, armor: _chain), 16);
    expect(armorClass(3, armor: _chain, shield: _shield), 18);
    expect(armorClass(1, shield: _shield), 13);
  });

  test('lit une armure depuis le pack', () {
    final pack = ContentPack.fromJson({
      'id': 'p',
      'name': 'P',
      'schemaVersion': 1,
      'license': 'CC-BY-4.0',
      'armors': [
        {'id': 'cuir', 'name': 'Cuir', 'baseAc': 11, 'category': 'light'},
      ],
    });
    expect(pack.armors.single.category, ArmorCategory.light);
  });
}
