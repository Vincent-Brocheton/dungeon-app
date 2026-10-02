import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_doc.dart';
import '../../data/table_membership.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../characters/characters_providers.dart';
import 'table_providers.dart';

String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Historique des jets faits depuis la fiche. Avec [characterId] : ceux du
/// personnage (`RollHistory`). Sans : ceux des personnages joués à la table,
/// pour le MJ (`TableRollHistory`), filtrables par joueur.
class RollHistoryScreen extends ConsumerStatefulWidget {
  const RollHistoryScreen({super.key, this.characterId});

  final String? characterId;

  @override
  ConsumerState<RollHistoryScreen> createState() => _RollHistoryScreenState();
}

class _RollHistoryScreenState extends ConsumerState<RollHistoryScreen> {
  String? _player;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    final id = widget.characterId;
    final List<RollRecord> rolls;
    final String subtitle;
    final String notice;
    var players = <String>[];
    if (id != null) {
      rolls = ref.watch(characterRollsProvider(id)).value ?? [];
      subtitle =
          (ref.watch(myCharactersProvider).value ?? <CharacterDoc>[])
              .where((c) => c.id == id)
              .firstOrNull
              ?.name ??
          '';
      notice =
          'Seuls tes propres jets apparaissent ici. Le MJ peut consulter ceux '
          'de toute la table depuis la console MJ.';
    } else {
      final atTable = {
        for (final m
            in ref.watch(tableMembersProvider).value ?? <TableMember>[])
          if (m.characterId != null) m.characterId,
      };
      final all = [
        for (final r in ref.watch(allRollsProvider).value ?? <RollRecord>[])
          if (atTable.contains(r.characterId)) r,
      ];
      players = {for (final r in all) r.characterName}.toList()..sort();
      rolls = [
        for (final r in all)
          if (_player == null || r.characterName == _player) r,
      ];
      subtitle = ref.watch(tablePublicProvider).value?.name ?? '';
      notice =
          'En tant que MJ, tu vois les jets des personnages joués à ta table. '
          'Chaque joueur, de son côté, ne voit que les siens.';
    }

    final children = <Widget>[];
    String? lastDay;
    for (final r in rolls) {
      final day = _day(r.createdAt);
      if (day != lastDay) {
        lastDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(day, style: muted),
          ),
        );
      }
      children.add(_RollCard(roll: r, showName: id == null));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              id == null
                  ? 'Historique des jets de la table'
                  : 'Historique de mes jets',
            ),
            if (subtitle.isNotEmpty) Text(subtitle, style: muted),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(notice, style: muted),
              if (players.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in [null, ...players])
                      ChoiceChip(
                        label: Text(p ?? 'Tous les joueurs'),
                        selected: _player == p,
                        onSelected: (_) => setState(() => _player = p),
                      ),
                  ],
                ),
              ],
              if (rolls.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text('Aucun jet pour l’instant.', style: muted),
                ),
              ...children,
              const SizedBox(height: 16),
              Text(
                'L’historique conserve les jets faits depuis la fiche. Les '
                'résultats annoncés à la table de vive voix ne sont pas '
                'enregistrés automatiquement.',
                textAlign: TextAlign.center,
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollCard extends StatelessWidget {
  const _RollCard({required this.roll, required this.showName});

  final RollRecord roll;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(
          color: roll.inspired ? AppTheme.accent : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showName
                      ? '${roll.characterName} · ${roll.label}'
                      : roll.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(roll.detail, style: muted),
                if (roll.inspired)
                  Text(
                    'Inspiration héroïque dépensée',
                    style: muted?.copyWith(color: AppTheme.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${roll.total}',
            style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}
