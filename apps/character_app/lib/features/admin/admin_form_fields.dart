import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Champ texte labellisé, style commun aux fiches d'édition de compendium
/// (espèces, sous-espèces, puis les éditeurs à venir).
class AdminLabeledField extends StatelessWidget {
  const AdminLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, isDense: true),
        ),
      ],
    );
  }
}

/// Menu déroulant labellisé, même style que [AdminLabeledField].
class AdminLabeledDropdown<T> extends StatelessWidget {
  const AdminLabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          initialValue: items.contains(value) ? value : null,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

/// Encadré de regroupement des fiches de compendium (ex. source + ouvrage).
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

/// Carte de navigation vers un éditeur lié (ex. sous-classes d'une classe).
class AdminLinkCard extends StatelessWidget {
  const AdminLinkCard({
    super.key,
    required this.text,
    required this.action,
    required this.route,
  });

  final String text;
  final String action;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
            const SizedBox(width: 10),
            Text(
              action,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 14, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}
