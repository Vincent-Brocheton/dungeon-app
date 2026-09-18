import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  test('bonus de maîtrise par palier', () {
    expect([1, 4].map(proficiencyBonus), everyElement(2));
    expect([5, 8].map(proficiencyBonus), everyElement(3));
    expect([9, 12].map(proficiencyBonus), everyElement(4));
    expect([13, 16].map(proficiencyBonus), everyElement(5));
    expect([17, 20].map(proficiencyBonus), everyElement(6));
  });

  test('niveau hors 1–20 refusé', () {
    expect(() => proficiencyBonus(0), throwsRangeError);
    expect(() => proficiencyBonus(21), throwsRangeError);
  });
}
