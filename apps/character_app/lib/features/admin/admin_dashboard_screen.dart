import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_character_entry.dart';
import '../../providers/content_providers.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_providers.dart';

/// Tableau de bord admin : statistiques, accès au Compendium (à venir), et
/// tous les personnages des joueurs. Reprend la maquette `Dashboard.dc.html`
/// / `DashboardMobile.dc.html`, sans la sidebar (pas de pattern de
/// navigation latérale ailleurs dans l'app) ni les données non modélisées
/// (statut actif/brouillon, décompte par source de contenu).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  /// Les 9 éditeurs de compendium : route (sous `/admin`) et libellé.
  /// Écrans encore à bâtir (sous-projet 2) ; la navigation existe déjà.
  static const _compendiumSections = [
    (AppRoutes.adminSpecies, 'Espèces'),
    (AppRoutes.adminSubspecies, 'Sous-espèces'),
    (AppRoutes.adminClasses, 'Classes'),
    (AppRoutes.adminSubclasses, 'Sous-classes'),
    (AppRoutes.adminSpells, 'Sorts'),
    (AppRoutes.adminFeats, 'Dons'),
    (AppRoutes.adminBackgrounds, 'Historiques'),
    (AppRoutes.adminInvocations, 'Manifestations occultes'),
    (AppRoutes.adminLevelProgression, 'Tables de progression'),
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
    final srdPack = ref.watch(srdPackProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
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
                      for (final (path, label) in _compendiumSections)
                        _CompendiumCard(
                          label: label,
                          onTap: () => context.push(path),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('Personnages des joueurs'),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    Text(
                      'Aucun personnage',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final entry in list)
                          _PlayerCharacterCard(
                            entry: entry,
                            speciesName:
                                entry.doc.speciesId == null
                                    ? null
                                    : srdPack
                                        ?.speciesById(entry.doc.speciesId!)
                                        ?.name,
                          ),
                      ],
                    ),
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

class _CompendiumCard extends StatelessWidget {
  const _CompendiumCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _PlayerCharacterCard extends StatelessWidget {
  const _PlayerCharacterCard({required this.entry, required this.speciesName});

  final AdminCharacterEntry entry;
  final String? speciesName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = entry.doc;
    final subtitle = [
      'Niveau ${doc.level}',
      if (speciesName != null) speciesName!,
    ].join(' · ');

    return Container(
      width: 340,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              doc.name.isEmpty ? '?' : doc.name[0].toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.background,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  'Propriétaire : ${entry.ownerUid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
