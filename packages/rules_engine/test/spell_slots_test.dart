import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  test('emplacements d\'un lanceur complet (PHB 2024)', () {
    expect(fullCasterSlots(1), [2]);
    expect(fullCasterSlots(5), [4, 3, 2]);
    expect(fullCasterSlots(20), [4, 3, 3, 3, 3, 2, 2, 1, 1]);
    expect(() => fullCasterSlots(0), throwsRangeError);
  });

  test('le plus bas emplacement disponible à partir du niveau du sort', () {
    final slots = fullCasterSlots(5);
    expect(slotToSpend(slots, [], 1), 1);
    expect(slotToSpend(slots, [4], 1), 2);
    expect(slotToSpend(slots, [4, 3], 2), 3);
    expect(slotToSpend(slots, [4, 3, 2], 1), isNull);
    expect(slotToSpend(slots, [], 4), isNull);
  });
}
