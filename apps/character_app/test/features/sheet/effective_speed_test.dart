import 'package:character_app/features/sheet/character_sheet_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  test('vitesse : 0 si une condition l\'annule, -1,5 m par niveau '
      'd\'épuisement', () {
    expect(effectiveSpeed('9 m', {}, 0), '9 m');
    expect(effectiveSpeed('9 m', {Condition.grappled}, 0), '0 m');
    expect(effectiveSpeed('9 m', {Condition.poisoned}, 1), '7,5 m');
    expect(effectiveSpeed('9 m', {}, 2), '6 m');
    expect(effectiveSpeed('—', {}, 2), '—');
  });
}
