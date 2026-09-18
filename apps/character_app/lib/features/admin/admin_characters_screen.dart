import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_providers.dart';

/// Vue admin : tous les personnages de tous les utilisateurs, en lecture seule.
class AdminCharactersScreen extends ConsumerWidget {
  const AdminCharactersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé aux administrateurs')),
      );
    }

    final entries = ref.watch(allCharactersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Personnages')),
      body: entries.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('Aucun personnage'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final entry = list[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${entry.doc.level}')),
                    title: Text(entry.doc.name),
                    subtitle: Text('Propriétaire : ${entry.ownerUid}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }
}
