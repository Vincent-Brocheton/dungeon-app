import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../characters/characters_providers.dart';
import 'point_buy_notifier.dart';

/// Première tranche verticale : l'Achat de points branché sur le moteur de règles.
class PointBuyScreen extends ConsumerWidget {
  const PointBuyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(pointBuyProvider);
    final notifier = ref.read(pointBuyProvider.notifier);
    final remaining = PointBuy.remaining(scores);
    final violations = PointBuy.validate(scores);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achat de points'),
        actions: [
          IconButton(
            tooltip: 'Tableau standard',
            icon: const Icon(Icons.table_rows_outlined),
            onPressed: notifier.useStandardArray,
          ),
          IconButton(
            tooltip: 'Réinitialiser',
            icon: const Icon(Icons.restart_alt),
            onPressed: notifier.reset,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: violations.isEmpty
            ? () => _save(context, ref, scores)
            : null,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Enregistrer'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                violations.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
                color: violations.isEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              title: Text('Points restants : $remaining / ${PointBuy.budget}'),
              subtitle: Text(
                violations.isEmpty
                    ? 'Répartition valide (scores 8–15, avant bonus de Background)'
                    : violations.map((v) => v.message).join('\n'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final ability in Ability.values)
            _AbilityRow(
              ability: ability,
              score: scores[ability],
              remaining: remaining,
              onIncrement: () => notifier.increment(ability),
              onDecrement: () => notifier.decrement(ability),
            ),
        ],
      ),
    );
  }
}

/// Demande un nom, crée le personnage, réinitialise l'écran et revient à la liste.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  AbilityScores scores,
) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nom du personnage'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Ex. Brenna la Rousse'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Créer'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim().isEmpty) return;

  await ref
      .read(charactersControllerProvider)
      .create(name: name, scores: scores);
  ref.read(pointBuyProvider.notifier).reset();
  if (context.mounted) context.pop();
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    required this.ability,
    required this.score,
    required this.remaining,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Ability ability;
  final int score;
  final int remaining;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  bool get _canIncrement =>
      score < PointBuy.maxScore &&
      PointBuy.deltaCost(score, score + 1) <= remaining;

  bool get _canDecrement => score > PointBuy.minScore;

  @override
  Widget build(BuildContext context) {
    final modifier = abilityModifier(score);
    final modifierLabel = modifier >= 0 ? '+$modifier' : '$modifier';
    final nextCost =
        score < PointBuy.maxScore ? PointBuy.deltaCost(score, score + 1) : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(ability.code)),
        title: Text(_label(ability)),
        subtitle: Text(
          nextCost == null
              ? 'Modificateur $modifierLabel · maximum atteint'
              : 'Modificateur $modifierLabel · +1 coûte $nextCost pt',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _canDecrement ? onDecrement : null,
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$score',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _canIncrement ? onIncrement : null,
            ),
          ],
        ),
      ),
    );
  }

  // Les libellés vivront dans l'i18n (V1) ; en attendant, en dur ici, pas dans le moteur.
  static String _label(Ability ability) => switch (ability) {
        Ability.strength => 'Force',
        Ability.dexterity => 'Dextérité',
        Ability.constitution => 'Constitution',
        Ability.intelligence => 'Intelligence',
        Ability.wisdom => 'Sagesse',
        Ability.charisma => 'Charisme',
      };
}
