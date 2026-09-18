import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/character_doc.dart';
import '../../router.dart';
import '../auth/auth_providers.dart';
import '../characters/characters_providers.dart';

/// « Mes personnages » : la liste synchronisée de l'utilisateur courant.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(myCharactersProvider);
    final user = ref.watch(authStateProvider).value;
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnages'),
        actions: [
          IconButton(
            tooltip: isAnonymous
                ? 'Compte anonyme : lie-le pour retrouver tes persos ailleurs'
                : user!.label,
            icon: Icon(
              isAnonymous
                  ? Icons.person_outline
                  : Icons.verified_user_outlined,
            ),
            onPressed: () => context.push(AppRoutes.account),
          ),
        ],
      ),
      body: characters.when(
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) =>
                    _CharacterTile(doc: list[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.pointBuy),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau personnage'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun personnage pour l\'instant',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _CharacterTile extends ConsumerWidget {
  const _CharacterTile({required this.doc});

  final CharacterDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = Ability.values
        .map((a) => '${a.code} ${doc.scores[a]}')
        .join(' · ');

    return ListTile(
      leading: CircleAvatar(child: Text('${doc.level}')),
      title: Text(doc.name),
      subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Supprimer',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
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
    );
  }
}
