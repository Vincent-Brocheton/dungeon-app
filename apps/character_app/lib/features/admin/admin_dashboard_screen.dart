import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_character_entry.dart';
import '../../data/admin_species_doc.dart';
import '../../data/content_repository.dart';
import '../../providers/content_providers.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_providers.dart';

/// « il y a 2 h », « hier », « il y a 3 j ».
String _ago(DateTime date) {
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
  if (elapsed.inDays == 1) return 'hier';
  return 'il y a ${elapsed.inDays} j';
}

/// « 4 SRD · 1 Officiel · 1 Homebrew » (sources absentes omises).
String _bySource(List<ContentDoc> docs) => [
  for (final source in SpeciesSource.values)
    if (docs.where((d) => d.source == source).length case final n when n > 0)
      '$n ${source.shortLabel}',
].join(' · ');

/// Tableau de bord admin : statistiques, compendium (nombre d'éléments et
/// répartition par source), personnages récents des joueurs. Reprend
/// `Dashboard.dc.html` / `DashboardMobile.dc.html` — sans la sidebar (accès
/// à la table et aux PNJ par les icônes de la barre) ni les données non
/// modélisées (statut actif/brouillon, classe des personnages, nom des
/// joueurs).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  /// Les éditeurs de compendium : route (sous `/admin`), libellé, contenu.
  static final _compendiumSections =
      <(String, String, AsyncValue<List<ContentDoc>> Function(WidgetRef))>[
        (AppRoutes.adminSpecies, 'Espèces', (r) => r.watch(allSpeciesProvider)),
        (
          AppRoutes.adminSubspecies,
          'Sous-espèces',
          (r) => r.watch(allSubspeciesProvider),
        ),
        (AppRoutes.adminClasses, 'Classes', (r) => r.watch(allClassesProvider)),
        (
          AppRoutes.adminSubclasses,
          'Sous-classes',
          (r) => r.watch(allSubclassesProvider),
        ),
        (AppRoutes.adminSpells, 'Sorts', (r) => r.watch(allSpellsProvider)),
        (AppRoutes.adminFeats, 'Dons', (r) => r.watch(allFeatsProvider)),
        (
          AppRoutes.adminBackgrounds,
          'Historiques',
          (r) => r.watch(allBackgroundsProvider),
        ),
        (
          AppRoutes.adminInvocations,
          'Manifestations occultes',
          (r) => r.watch(allInvocationsProvider),
        ),
        (
          AppRoutes.adminMonsters,
          'Monstres',
          (r) => r.watch(allMonstersProvider),
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé aux administrateurs')),
      );
    }

    final entries = ref.watch(allCharactersProvider);
    final species = ref.watch(allSpeciesProvider).value;
    final srdPack = ref.watch(srdPackProvider).value;
    String? speciesName(String? id) {
      if (id == null) return null;
      return species?.where((s) => s.id == id).firstOrNull?.name ??
          srdPack?.speciesById(id)?.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            tooltip: 'Ma table',
            icon: const Icon(Icons.table_restaurant_outlined),
            onPressed: () => context.push(AppRoutes.adminTable),
          ),
          IconButton(
            tooltip: 'PNJ',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push(AppRoutes.adminNpcs),
          ),
        ],
      ),
      body: entries.when(
        data:
            (list) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatTile(label: 'Personnages', value: '${list.length}'),
                      _StatTile(
                        label: 'Joueurs',
                        value: '${list.map((e) => e.ownerUid).toSet().length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('Compendium'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (path, label, watch) in _compendiumSections)
                        _CompendiumCard(
                          label: label,
                          docs: watch(ref).value,
                          onTap: () => context.push(path),
                        ),
                      _CompendiumCard(
                        label: 'Tables de progression',
                        description:
                            'Aptitudes, ASI/Don et sorts débloqués niveau par '
                            'niveau, pour chaque classe et sous-classe',
                        action: 'Configurer',
                        onTap:
                            () => context.push(AppRoutes.adminLevelProgression),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('Personnages récents'),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    Text(
                      'Aucun personnage',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    )
                  else
                    _CharacterTable(entries: list, speciesName: speciesName),
                ],
              ),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppTheme.textMuted,
      letterSpacing: 0.05,
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// Carte d'un éditeur : nombre d'éléments et répartition par source si
/// [docs] est connu, sinon [description] et [action].
class _CompendiumCard extends StatelessWidget {
  const _CompendiumCard({
    required this.label,
    required this.onTap,
    this.docs,
    this.description,
    this.action,
  });

  final String label;
  final List<ContentDoc>? docs;
  final String? description;
  final String? action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final docs = this.docs;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: description == null ? 180 : 372,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            if (description != null) ...[
              Text(description!, style: muted),
              const SizedBox(height: 6),
              Text(
                action ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              Text(
                docs == null ? '—' : '${docs.length}',
                style: theme.textTheme.headlineSmall,
              ),
              if (docs != null && docs.isNotEmpty)
                Text(_bySource(docs), style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Personnages les plus récemment modifiés, en tableau.
class _CharacterTable extends StatelessWidget {
  const _CharacterTable({required this.entries, required this.speciesName});

  final List<AdminCharacterEntry> entries;
  final String? Function(String? id) speciesName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: cells[0]),
          Expanded(flex: 3, child: cells[1]),
          Expanded(flex: 2, child: cells[2]),
          Expanded(flex: 2, child: cells[3]),
          Expanded(flex: 2, child: cells[4]),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          row([
            for (final h in [
              'PERSONNAGE',
              'JOUEUR',
              'NIVEAU',
              'ESPÈCE',
              'DERNIÈRE MAJ',
            ])
              Text(h, style: header),
          ]),
          for (final entry in entries) ...[
            const Divider(height: 1, color: AppTheme.border),
            row([
              Text(entry.doc.name, style: theme.textTheme.bodyMedium),
              Text(
                entry.ownerUid,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
              Text('Niv. ${entry.doc.level}', style: muted),
              Text(speciesName(entry.doc.speciesId) ?? '—', style: muted),
              Text(_ago(entry.doc.updatedAt), style: muted),
            ]),
          ],
        ],
      ),
    );
  }
}
