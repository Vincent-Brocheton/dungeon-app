import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Écran temporaire pour un éditeur de compendium (classes, dons, sorts...) :
/// le CRUD et la migration du contenu vers Firestore ne sont pas encore bâtis
/// (sous-projet 2, cf. `docs/superpowers/specs/2026-09-18-admin-roles-design.md`)
/// mais la route existe déjà, accessible depuis le tableau de bord admin.
class AdminEditorStubScreen extends StatelessWidget {
  const AdminEditorStubScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.construction_outlined,
                size: 48,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 16),
              Text('Bientôt disponible', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'L\'édition « $title » arrive dans une prochaine mise à jour.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
