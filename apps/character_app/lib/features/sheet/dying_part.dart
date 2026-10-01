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
          if (saves.dead) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B3A2E),
              ),
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder: (context) => _DeathConfirmDialog(doc: doc),
                  ),
              child: const Text('Confirmer le décès'),
            ),
            const SizedBox(height: 6),
            Text(
              'Une résurrection ou une erreur ? Soigne le personnage avant '
              'de confirmer.',
              style: muted,
            ),
          ],
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

/// Décès (`CharacterDeathConfirm.dc.html`) : ce qui change, circonstances
/// facultatives, confirmation.
class _DeathConfirmDialog extends ConsumerStatefulWidget {
  const _DeathConfirmDialog({required this.doc});

  final CharacterDoc doc;

  @override
  ConsumerState<_DeathConfirmDialog> createState() =>
      _DeathConfirmDialogState();
}

class _DeathConfirmDialogState extends ConsumerState<_DeathConfirmDialog> {
  final _epitaph = TextEditingController();

  @override
  void dispose() {
    _epitaph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.doc.name} est mort·e'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• Statut « Décédé » dans Mes personnages.\n'
              '• La fiche devient un mémorial en lecture seule : plus de '
              'jets ni d’édition.\n'
              '• Tu peux créer un nouveau personnage pour continuer à jouer.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('epitaph-field'),
              controller: _epitaph,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Circonstances (facultatif)',
                hintText: 'Succombé à ses blessures face au chef gobelin…',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B3A2E)),
        onPressed: () {
          ref
              .read(charactersControllerProvider)
              .save(
                widget.doc.copyWith(
                  diedAt: DateTime.now(),
                  epitaph: _epitaph.text.trim(),
                ),
              );
          Navigator.pop(context);
        },
        child: const Text('Confirmer le décès'),
      ),
    ],
  );
}

/// Fiche d'un personnage décédé (`CharacterMemorial.dc.html`) : en lecture
/// seule, avec ses valeurs au moment du décès. Une résurrection le ramène à
/// 1 PV.
class _Memorial extends ConsumerWidget {
  const _Memorial({
    required this.doc,
    required this.subtitle,
    required this.maxHp,
    required this.armorClass,
  });

  final CharacterDoc doc;
  final String subtitle;
  final int maxHp;
  final int armorClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour à mes personnages',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.go(AppRoutes.home),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.name, style: const TextStyle(color: AppTheme.textMuted)),
            Text('$subtitle · Décédé', style: muted),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF201A14),
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Décédé — ${_noteDate(doc.diedAt!)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF8B7060),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (doc.epitaph.isNotEmpty) Text(doc.epitaph, style: muted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Fiche au moment du décès (figée)',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: _card,
                  child: Column(
                    children: [
                      row('Points de vie max.', '$maxHp'),
                      row("Classe d'armure", '$armorClass'),
                      row('Niveau', '${doc.level}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ce mémorial est en lecture seule : la fiche ne peut plus être '
                'modifiée ni utilisée pour des jets.',
                textAlign: TextAlign.center,
                style: muted,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Retour à Mes personnages'),
              ),
              TextButton(
                onPressed:
                    () => ref
                        .read(charactersControllerProvider)
                        .save(
                          doc.copyWith(
                            revive: true,
                            deathSaves: const DeathSaves(),
                            hpLost: maxHp - 1,
                          ),
                        ),
                child: const Text('Résurrection (revient à 1 PV)'),
              ),
            ],
          ),
        ),
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
