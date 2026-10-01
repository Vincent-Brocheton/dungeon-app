import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  test('DD 10 : réussite à 10 et plus, échec en dessous', () {
    const start = DeathSaves();
    expect(start.roll(10).saves.successes, 1);
    expect(start.roll(9).saves.failures, 1);
  });

  test('1 naturel = 2 échecs, 20 naturel = 1 PV et compteurs remis à zéro', () {
    const s = DeathSaves(successes: 2, failures: 1);
    expect(s.roll(1).saves.failures, 3);
    expect(s.roll(1).saves.dead, isTrue);
    final twenty = s.roll(20);
    expect(twenty.revived, isTrue);
    expect((twenty.saves.successes, twenty.saves.failures), (0, 0));
  });

  test(
    'trois réussites : stable ; dégâts à 0 PV : échec, stabilité perdue',
    () {
      const stable = DeathSaves(successes: 3);
      expect(stable.stable, isTrue);
      final hit = stable.damaged();
      expect((hit.successes, hit.failures, hit.stable), (0, 1, false));
      expect(const DeathSaves(failures: 2).damaged(critical: true).failures, 3);
      final mid = const DeathSaves(successes: 2, failures: 1).damaged();
      expect((mid.successes, mid.failures), (2, 2));
    },
  );

  test('mort instantanée si le reliquat de dégâts atteint les PV max', () {
    expect(instantDeath(damage: 22, currentHp: 10, maxHp: 12), isTrue);
    expect(instantDeath(damage: 21, currentHp: 10, maxHp: 12), isFalse);
  });
}
