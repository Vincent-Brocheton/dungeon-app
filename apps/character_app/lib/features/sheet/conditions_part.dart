part of 'character_sheet_screen.dart';

/// Vitesse affichée (« 9 m ») : 0 sous une condition qui l'annule, sinon
/// réduite de 1,5 m par niveau d'épuisement (PHB 2024).
String effectiveSpeed(String speed, Set<Condition> conditions, int exhaustion) {
  if (conditions.any((c) => c.zeroSpeed)) return '0 m';
  final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s*m').firstMatch(speed);
  if (exhaustion <= 0 || match == null) return speed;
  final meters = max(
    0.0,
    double.parse(match.group(1)!.replaceAll(',', '.')) - 1.5 * exhaustion,
  );
  final text =
      meters == meters.roundToDouble()
          ? '${meters.round()}'
          : meters.toStringAsFixed(1).replaceAll('.', ',');
  return '$text m';
}

/// Inspiration héroïque et conditions actives, sur le Résumé.
class _Status extends StatelessWidget {
  const _Status({required this.doc});

  final CharacterDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final active = doc.activeConditions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showInspiration(context, doc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  doc.heroicInspiration
                      ? const Color(0xFF2A2114)
                      : AppTheme.surface,
              border: Border.all(
                color:
                    doc.heroicInspiration ? AppTheme.accent : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  doc.heroicInspiration ? Icons.star : Icons.star_border,
                  size: 18,
                  color:
                      doc.heroicInspiration
                          ? AppTheme.accent
                          : AppTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.heroicInspiration
                        ? 'Inspiration héroïque disponible'
                        : "Pas d'Inspiration héroïque",
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'CONDITIONS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showConditions(context, doc.id),
              child: const Text('+ Gérer'),
            ),
          ],
        ),
        if (active.isEmpty && doc.exhaustion == 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _card,
            child: Text('Aucune condition.', style: muted),
          ),
        for (final c in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ActiveCondition(
              name: conditionLabels[c]!.$1,
              effect: conditionLabels[c]!.$2,
              onTap: () => _showConditions(context, doc.id),
            ),
          ),
        if (doc.exhaustion > 0)
          _ActiveCondition(
            name: 'Épuisement (niveau ${doc.exhaustion})',
            effect:
                '${-2 * doc.exhaustion} à tous les jets de d20 ; Vitesse '
                'réduite de '
                '${(1.5 * doc.exhaustion).toString().replaceAll('.', ',')} m.',
            onTap: () => _showConditions(context, doc.id),
          ),
      ],
    );
  }
}

class _ActiveCondition extends StatelessWidget {
  const _ActiveCondition({
    required this.name,
    required this.effect,
    required this.onTap,
  });

  final String name;
  final String effect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2114),
        border: Border.all(color: AppTheme.accent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            effect,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7B9CC4)),
          ),
        ],
      ),
    ),
  );
}

/// Conditions (`CharSheetConditions.dc.html`) : chaque condition s'active
/// ou se retire d'un toucher, l'épuisement se règle de 0 à 6 ; enregistré
/// aussitôt, appliqué à tous les jets de la fiche.
Future<void> _showConditions(
  BuildContext context,
  String characterId,
) => showDialog<void>(
  context: context,
  builder:
      (context) => Consumer(
        builder: (context, ref, _) {
          final doc = ref.watch(characterProvider(characterId)).value;
          final theme = Theme.of(context);
          final muted = theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          );
          if (doc == null) return const SizedBox.shrink();
          final controller = ref.read(charactersControllerProvider);
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conditions', style: theme.textTheme.titleLarge),
                        Text(
                          '${doc.name} · effets appliqués aux jets',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final c in Condition.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: CheckboxListTile(
                              value: doc.conditions.contains(c.name),
                              onChanged:
                                  (on) => controller.save(
                                    doc.copyWith(
                                      conditions: [
                                        for (final n in doc.conditions)
                                          if (n != c.name) n,
                                        if (on ?? false) c.name,
                                      ],
                                    ),
                                  ),
                              title: Text(conditionLabels[c]!.$1),
                              subtitle: Text(
                                conditionLabels[c]!.$2,
                                style: muted,
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color:
                                      doc.conditions.contains(c.name)
                                          ? AppTheme.accent
                                          : AppTheme.border,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: _card,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Épuisement'),
                                    Text(
                                      'Cumulatif : −2 aux jets de d20 et '
                                      '−1,5 m de Vitesse par niveau ; '
                                      'niveau 6 : mort.',
                                      style: muted,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: "Un niveau d'épuisement de moins",
                                onPressed:
                                    doc.exhaustion > 0
                                        ? () => controller.save(
                                          doc.copyWith(
                                            exhaustion: doc.exhaustion - 1,
                                          ),
                                        )
                                        : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Text(
                                '${doc.exhaustion}',
                                key: const Key('exhaustion-level'),
                              ),
                              IconButton(
                                tooltip: "Un niveau d'épuisement de plus",
                                onPressed:
                                    doc.exhaustion < 6
                                        ? () => controller.save(
                                          doc.copyWith(
                                            exhaustion: doc.exhaustion + 1,
                                          ),
                                        )
                                        : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
);

/// Inspiration héroïque (`CharSheetInspiration.dc.html`) : état, règles, et
/// bouton pour la noter quand le MJ l'accorde (ou la retirer).
Future<void> _showInspiration(BuildContext context, CharacterDoc doc) =>
    showDialog<void>(
      context: context,
      builder:
          (context) => Consumer(
            builder: (context, ref, _) {
              final theme = Theme.of(context);
              final muted = theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              );
              final has = doc.heroicInspiration;
              return AlertDialog(
                title: const Text('Inspiration héroïque'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        has ? 'Disponible' : 'Non disponible',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: has ? AppTheme.accent : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Elle ne se cumule pas : tant qu'elle n'est pas "
                        "dépensée, on n'en regagne pas.",
                        style: muted,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Avant un jet de d20 (test, sauvegarde, attaque), '
                        'dépense-la depuis la fenêtre du jet : tu lances 2d20 '
                        'et gardes le plus haut (avantage).',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Le MJ l’accorde (bonne idée, belle interprétation) ; '
                        'certains traits et dons en donnent aussi.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(charactersControllerProvider)
                          .save(doc.copyWith(heroicInspiration: !has));
                      Navigator.pop(context);
                    },
                    child: Text(has ? 'Retirer' : "Noter l'inspiration"),
                  ),
                ],
              );
            },
          ),
    );
