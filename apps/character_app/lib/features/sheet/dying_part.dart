part of 'character_sheet_screen.dart';

const _danger = Color(0xFFE0806A);
const _success = Color(0xFF7FA86A);

/// À 0 PV (`CharSheetDying.dc.html`) : mourant, stable ou mort, compteurs de
/// jets contre la mort et bouton de jet. Soigner remet à zéro (cf. carte
/// PV) ; l'écran de mort et le mémorial viendront avec leurs maquettes.
class _Dying extends StatelessWidget {
  const _Dying({required this.doc, required this.maxHp});

  final CharacterDoc doc;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final saves = doc.deathSaves;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final (title, subtitle) = switch (saves) {
      DeathSaves(dead: true) => (
        'Mort',
        'Trois échecs aux jets contre la mort.',
      ),
      DeathSaves(stable: true) => (
        'Stable — Inconscient',
        'Plus de jets à faire, jusqu’à être soigné ou blessé à nouveau.',
      ),
      _ => (
        'Mourant — Inconscient',
        "Tombé à 0 PV : incapable d'agir. Un jet contre la mort au début de "
            'chacun de tes tours.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF241613),
        border: Border.all(color: const Color(0xFF8B3A2E)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(subtitle, style: muted),
          const SizedBox(height: 12),
          _SaveDots(saves: saves),
          if (!saves.dead && !saves.stable) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (context) => _DeathSaveDialog(doc: doc, maxHp: maxHp),
                  ),
              child: const Text('Jet contre la mort (1d20, DD 10)'),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '20 naturel : 1 PV et conscience. 1 naturel : 2 échecs. Dégâts à '
            '0 PV : 1 échec (2 sur un critique). Un allié peut te stabiliser '
            '(Médecine DD 10).',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _SaveDots extends StatelessWidget {
  const _SaveDots({required this.saves});

  final DeathSaves saves;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int count, Color color) => Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: color))),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              i < count ? Icons.circle : Icons.circle_outlined,
              size: 16,
              color: color,
            ),
          ),
      ],
    );
    return Semantics(
      label:
          '${saves.successes} réussite(s), ${saves.failures} échec(s) '
          'contre la mort',
      child: Column(
        children: [
          row('Réussites', saves.successes, _success),
          const SizedBox(height: 6),
          row('Échecs', saves.failures, _danger),
        ],
      ),
    );
  }
}

/// Jet contre la mort (`CharSheetRollDeathSave.dc.html`) : le d20 est lancé
/// et enregistré à l'ouverture.
class _DeathSaveDialog extends ConsumerStatefulWidget {
  const _DeathSaveDialog({required this.doc, required this.maxHp});

  final CharacterDoc doc;
  final int maxHp;

  @override
  ConsumerState<_DeathSaveDialog> createState() => _DeathSaveDialogState();
}

class _DeathSaveDialogState extends ConsumerState<_DeathSaveDialog> {
  late final int _d20 = ref.read(diceRngProvider).nextInt(20) + 1;
  late final _result = widget.doc.deathSaves.roll(_d20);

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    ref
        .read(charactersControllerProvider)
        .save(
          doc.copyWith(
            deathSaves: _result.saves,
            hpLost: _result.revived ? widget.maxHp - 1 : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saves = _result.saves;
    final (verdict, color) = switch (_d20) {
      20 => ('20 naturel — 1 PV, tu reprends conscience !', _success),
      1 => ('1 naturel — deux échecs', _danger),
      >= 10 => ('Réussite ($_d20 ≥ DD 10)', _success),
      _ => ('Échec ($_d20 < DD 10)', _danger),
    };
    return AlertDialog(
      title: const Text('Sauvegarde contre la mort'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$_d20',
                key: const Key('death-save-d20'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            verdict,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          if (!_result.revived) ...[
            const SizedBox(height: 16),
            _SaveDots(saves: saves),
            if (saves.stable || saves.dead) ...[
              const SizedBox(height: 10),
              Text(
                saves.dead
                    ? 'Trois échecs : ton personnage meurt.'
                    : 'Trois réussites : tu es stable et inconscient.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
