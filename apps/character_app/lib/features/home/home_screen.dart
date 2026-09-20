import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/character_doc.dart';
import '../../providers/content_providers.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../auth/auth_providers.dart';
import '../characters/characters_providers.dart';

/// « Mes personnages » : la liste synchronisée de l'utilisateur courant.
/// Reprend la maquette `CharList.dc.html` / `CharListWeb.dc.html` : cartes
/// pleine largeur sur mobile, grille responsive à partir de 340px par carte.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(myCharactersProvider);
    final user = ref.watch(authStateProvider).value;
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes personnages'),
        actions: [
          IconButton(
            tooltip: 'Nouveau personnage',
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.pointBuy),
          ),
          if (ref.watch(isAdminProvider).value ?? false)
            IconButton(
              tooltip: 'Admin : voir tous les personnages',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push(AppRoutes.admin),
            ),
          IconButton(
            tooltip:
                isAnonymous
                    ? 'Compte anonyme : lie-le pour retrouver tes persos ailleurs'
                    : user!.label,
            icon: Icon(
              isAnonymous ? Icons.person_outline : Icons.verified_user_outlined,
            ),
            onPressed: () => context.push(AppRoutes.account),
          ),
        ],
      ),
      body: characters.when(
        data: (list) => _CharacterList(list: list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }
}

/// Grille responsive (une carte par ligne sur mobile, plusieurs sur grand
/// écran) : chaque carte fait 340px de large, `Wrap` les répartit selon la
/// largeur dispo, sans breakpoint à gérer à la main.
class _CharacterList extends ConsumerWidget {
  const _CharacterList({required this.list});

  final List<CharacterDoc> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srdPack = ref.watch(srdPackProvider).value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final doc in list)
            _CharacterCard(
              doc: doc,
              speciesName:
                  doc.speciesId == null
                      ? null
                      : srdPack?.speciesById(doc.speciesId!)?.name,
            ),
          const _CreateCard(),
        ],
      ),
    );
  }
}

class _CharacterCard extends ConsumerWidget {
  const _CharacterCard({required this.doc, required this.speciesName});

  final CharacterDoc doc;
  final String? speciesName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('Supprimer ${doc.name} ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Supprimer'),
                        ),
                      ],
                    ),
              );
              if (confirmed ?? false) {
                await ref.read(charactersControllerProvider).delete(doc.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Carte de fin de liste, toujours présente : sert de bouton de création et,
/// quand elle est la seule carte affichée, d'état vide.
class _CreateCard extends StatelessWidget {
  const _CreateCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push(AppRoutes.pointBuy),
      child: Container(
        width: 340,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Créer un nouveau personnage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
