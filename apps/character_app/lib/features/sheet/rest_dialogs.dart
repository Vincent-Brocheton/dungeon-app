import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/character_doc.dart';
import '../../theme/app_theme.dart';
import '../characters/characters_providers.dart';
import '../wizard/wizard_rules.dart';
import 'roll_dialog.dart';

/// Repos court (`CharSheetRestShort.dc.html`) : dépense de dés de vie, tirés
/// automatiquement. Les règles de table (variantes, limite de repos courts)
/// et les aptitudes rechargées viendront avec leurs données.
Future<void> showShortRestDialog(
  BuildContext context, {
  required CharacterDoc doc,
  required int maxHp,
  required int hitDieSides,
}) => showDialog<void>(
  context: context,
  builder:
      (context) =>
          _ShortRestDialog(doc: doc, maxHp: maxHp, hitDieSides: hitDieSides),
);

/// Repos long (`CharSheetRestLong.dc.html`) : PV au maximum, PV temporaires
/// perdus, tous les dés de vie récupérés.
Future<void> showLongRestDialog(
  BuildContext context, {
  required CharacterDoc doc,
  required int maxHp,
  required int hitDieSides,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final current = (maxHp - doc.hpLost).clamp(0, maxHp);
    return _RestDialog(
      title: 'Repos long',
      subtitle: doc.name,
      body: [
        _Card(
          children: [
            _Effect(
              label: 'Points de vie',
              value: '$current → $maxHp (complet)',
              color: const Color(0xFF7FA86A),
            ),
            _Effect(
              label: 'Dés de vie récupérés',
              value: '${doc.level}d$hitDieSides (tous)',
            ),
            if (doc.tempHp > 0)
              _Effect(label: 'PV temporaires', value: '${doc.tempHp} → 0'),
          ],
        ),
      ],
      action: Consumer(
        builder:
            (context, ref, _) => FilledButton(
              onPressed: () {
                ref
                    .read(charactersControllerProvider)
                    .save(doc.copyWith(hpLost: 0, tempHp: 0, hitDiceUsed: 0));
                Navigator.pop(context);
              },
              child: const Text('Prendre un repos long'),
            ),
      ),
    );
  },
);

class _ShortRestDialog extends ConsumerStatefulWidget {
  const _ShortRestDialog({
    required this.doc,
    required this.maxHp,
    required this.hitDieSides,
  });

  final CharacterDoc doc;
  final int maxHp;
  final int hitDieSides;

  @override
  ConsumerState<_ShortRestDialog> createState() => _ShortRestDialogState();
}

class _ShortRestDialogState extends ConsumerState<_ShortRestDialog> {
  late final _available = (widget.doc.level - widget.doc.hitDiceUsed).clamp(
    0,
    widget.doc.level,
  );
  late var _count = _available > 0 ? 1 : 0;

  void _rest() {
    final doc = widget.doc;
    final con = abilityModifier(doc.scores.constitution);
    final rolls = rollDice(
      ref.read(diceRngProvider),
      _count,
      widget.hitDieSides,
    );
    final healed = hitDiceHealing(rolls, con);
    ref
        .read(charactersControllerProvider)
        .save(
          doc.copyWith(
            hpLost: (doc.hpLost - healed).clamp(0, widget.maxHp),
            hitDiceUsed: doc.hitDiceUsed + _count,
          ),
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (_count > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('+$healed PV (dés : ${rolls.join(', ')})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final con = abilityModifier(widget.doc.scores.constitution);
    final sides = widget.hitDieSides;
    final estimate = (sides / 2 + 0.5 + con).clamp(1, sides + con) * _count;
    return _RestDialog(
      title: 'Repos court',
      subtitle: widget.doc.name,
      body: [
        Text(
          'DÉPENSER DES DÉS DE VIE',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 6),
        _Card(
          children: [
            _Effect(
              label: 'Dés de vie disponibles',
              value:
                  '$_available d$sides (${widget.doc.hitDiceUsed} déjà '
                  'utilisé${widget.doc.hitDiceUsed > 1 ? 's' : ''})',
            ),
            Row(
              children: [
                const Expanded(child: Text('Dés à dépenser')),
                IconButton.outlined(
                  tooltip: 'Un dé de moins',
                  visualDensity: VisualDensity.compact,
                  onPressed: _count > 0 ? () => setState(() => _count--) : null,
                  icon: const Icon(Icons.remove, size: 16),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$_count',
                    key: const Key('hit-dice-count'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Un dé de plus',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _count < _available
                          ? () => setState(() => _count++)
                          : null,
                  icon: const Icon(Icons.add, size: 16),
                ),
              ],
            ),
            _Effect(
              label: 'PV récupérés (estimé)',
              value:
                  _count == 0
                      ? '—'
                      : '${_count}d$sides '
                          '${con >= 0 ? '+' : '−'} ${(_count * con).abs()} '
                          '(≈ ${estimate.round()} PV)',
              color: const Color(0xFF7FA86A),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Les dés sont tirés automatiquement, le modificateur de '
          'Constitution est ajouté par dé (au moins 1 PV par dé).',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
      action: FilledButton(
        onPressed: _rest,
        child: const Text('Prendre un repos court'),
      ),
    );
  }
}

class _RestDialog extends StatelessWidget {
  const _RestDialog({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
  });

  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              ...body,
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: action),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          c,
        ],
      ],
    ),
  );
}

class _Effect extends StatelessWidget {
  const _Effect({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: color ?? AppTheme.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
