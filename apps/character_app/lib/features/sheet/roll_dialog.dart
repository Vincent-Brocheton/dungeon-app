import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../theme/app_theme.dart';

/// Dégâts d'une attaque : dés, bonus et type (« tranchant »).
typedef DamageDice = ({int count, int sides, int bonus, String type});

/// Source d'aléa des jets ; remplacée par un générateur figé dans les tests.
final diceRngProvider = Provider<Random>((ref) => Random());

/// Jet de d20 d'un test, d'une sauvegarde ou de l'initiative. Reprend
/// `CharSheetRollSkill`, `CharSheetRollSave` et `CharSheetRollInitiative`
/// (et leurs variantes web, centrées à 560px). L'avantage ou le désavantage
/// se choisit à la main, en attendant l'inspiration et les conditions.
/// Avec [damage], c'est un jet d'attaque (`CharSheetRoll`) : les dégâts sont
/// lancés avec, dés doublés sur un 20 naturel.
Future<void> showRollDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String modifierLabel,
  required int modifier,
  required String hint,
  DamageDice? damage,
}) => showDialog<void>(
  context: context,
  builder:
      (context) => _RollDialog(
        title: title,
        subtitle: subtitle,
        modifierLabel: modifierLabel,
        modifier: modifier,
        hint: hint,
        damage: damage,
      ),
);

String _signed(int value) => value >= 0 ? '+$value' : '$value';

class _RollDialog extends ConsumerStatefulWidget {
  const _RollDialog({
    required this.title,
    required this.subtitle,
    required this.modifierLabel,
    required this.modifier,
    required this.hint,
    this.damage,
  });

  final String title;
  final String subtitle;
  final String modifierLabel;
  final int modifier;
  final String hint;
  final DamageDice? damage;

  @override
  ConsumerState<_RollDialog> createState() => _RollDialogState();
}

class _RollDialogState extends ConsumerState<_RollDialog> {
  var _mode = RollMode.normal;
  late D20Roll _roll;
  List<int> _damageDice = const [];

  @override
  void initState() {
    super.initState();
    _reroll();
  }

  bool get _critical => _roll.kept == 20;

  void _reroll() {
    final rng = ref.read(diceRngProvider);
    _roll = _newRoll();
    if (widget.damage case final d?) {
      _damageDice = rollDice(rng, _critical ? d.count * 2 : d.count, d.sides);
    }
  }

  D20Roll _newRoll() =>
      D20Roll.roll(ref.read(diceRngProvider), widget.modifier, mode: _mode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final twoDice = _roll.dice.length == 2;
    final keptIndex = _roll.dice.indexOf(_roll.kept);
    final discarded = twoDice ? _roll.dice[1 - keptIndex] : null;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              Text(widget.subtitle, style: muted),
              const SizedBox(height: 16),
              SegmentedButton<RollMode>(
                segments: const [
                  ButtonSegment(value: RollMode.normal, label: Text('Normal')),
                  ButtonSegment(
                    value: RollMode.advantage,
                    label: Text('Avantage'),
                  ),
                  ButtonSegment(
                    value: RollMode.disadvantage,
                    label: Text('Désavantage'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged:
                    (s) => setState(() {
                      _mode = s.single;
                      _reroll();
                    }),
              ),
              const SizedBox(height: 20),
              Text(
                switch (_mode) {
                  RollMode.normal => 'JET (1D20)',
                  RollMode.advantage => 'JET (2D20, AVANTAGE)',
                  RollMode.disadvantage => 'JET (2D20, DÉSAVANTAGE)',
                },
                textAlign: TextAlign.center,
                style: muted,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, d) in _roll.dice.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _Die(value: d, kept: i == keptIndex),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _Line(
                      label: twoDice ? 'd20 retenu' : 'd20',
                      value:
                          discarded == null
                              ? '${_roll.kept}'
                              : '${_roll.kept} ($discarded écarté)',
                    ),
                    const SizedBox(height: 8),
                    _Line(
                      label: widget.modifierLabel,
                      value: _signed(widget.modifier),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${_roll.total}',
                          key: const Key('roll-total'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.hint, textAlign: TextAlign.center, style: muted),
              if (widget.damage case final d?) ...[
                const SizedBox(height: 20),
                Text(
                  _critical
                      ? 'DÉGÂTS — COUP CRITIQUE, DÉS DOUBLÉS'
                      : "DÉGÂTS (SI L'ATTAQUE TOUCHE)",
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final v in _damageDice) _Die(value: v, kept: true),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _Line(
                        label: '${_damageDice.length}d${d.sides}',
                        value: '${_damageDice.fold(0, (a, b) => a + b)}',
                      ),
                      const SizedBox(height: 8),
                      _Line(label: 'Bonus', value: _signed(d.bonus)),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dégâts ${d.type}s',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${max(0, _damageDice.fold(0, (a, b) => a + b) + d.bonus)}',
                            key: const Key('damage-total'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFFC97227),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(_reroll),
                      child: const Text('Relancer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Die extends StatelessWidget {
  const _Die({required this.value, required this.kept});

  final int value;
  final bool kept;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: kept ? const Color(0xFF2A2114) : AppTheme.background,
      border: Border.all(
        color: kept ? AppTheme.accent : AppTheme.border,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '$value',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: kept ? AppTheme.accent : const Color(0xFF6B5A3A),
        fontWeight: FontWeight.w700,
        decoration: kept ? null : TextDecoration.lineThrough,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ),
      Text(value),
    ],
  );
}
