import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';

/// Onglets partagés par les éditeurs de compendium (espèces, sorts, puis
/// les éditeurs à venir) : navigue entre eux, met en avant l'onglet courant.
/// Les onglets encore sans vrai éditeur mènent à `AdminEditorStubScreen`.
class AdminCompendiumTabs extends StatelessWidget {
  const AdminCompendiumTabs({super.key, required this.current});

  /// Route (`AppRoutes.adminXxx`) de l'éditeur affiché.
  final String current;

  static const _tabs = [
    ('Espèces', AppRoutes.adminSpecies),
    ('Classes', AppRoutes.adminClasses),
    ('Sorts', AppRoutes.adminSpells),
    ('Dons', AppRoutes.adminFeats),
    ('Historiques', AppRoutes.adminBackgrounds),
    ('Manifestations occultes', AppRoutes.adminInvocations),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (final (label, path) in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: InkWell(
                  onTap: path == current ? null : () => context.push(path),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              path == current
                                  ? AppTheme.accent
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            path == current
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                        fontWeight:
                            path == current
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
