import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_feat_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

const _categories = ['Origine', 'Général', 'Combat', 'Épique'];

const _abilities = [
  'Force',
  'Dextérité',
  'Constitution',
  'Intelligence',
  'Sagesse',
  'Charisme',
];

/// Éditeur de dons : liste à gauche, fiche éditable à droite. Reprend
/// `FeatsEditorNoModal.dc.html` — sans sidebar ni import CSV (bouton
/// présent, annonce juste qu'il arrive, même choix que les éditeurs
/// précédents). Aucun don dans le pack SRD statique : tout est admin-créé.
class AdminFeatEditorScreen extends ConsumerStatefulWidget {
  const AdminFeatEditorScreen({super.key});

  @override
  ConsumerState<AdminFeatEditorScreen> createState() =>
      _AdminFeatEditorScreenState();
}

class _AdminFeatEditorScreenState extends ConsumerState<AdminFeatEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _prerequisite = TextEditingController();
  final _effect = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _category = 'Général';
  var _repeatable = false;
  var _abilityBonuses = const <FeatAbilityBonus>[];

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _prerequisite,
      _effect,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(AdminFeatDoc doc) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = false;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _prerequisite.text = doc.prerequisite;
      _effect.text = doc.effect;
      _source = doc.source;
      _category = doc.category;
      _repeatable = doc.repeatable;
      _abilityBonuses = doc.abilityBonuses;
    });
  }

  void _createDraft() {
    final id = ref.read(adminFeatRepositoryProvider).newId();
    setState(() {
      _selectedId = id;
      _isNewDraft = true;
      _name.clear();
      _sourcebook.clear();
      _prerequisite.clear();
      _effect.clear();
      _source = SpeciesSource.homebrew;
      _category = 'Général';
      _repeatable = false;
      _abilityBonuses = const [];
    });
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminFeatRepositoryProvider)
          .upsert(
            AdminFeatDoc(
              id: id,
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              category: _category,
              prerequisite: _prerequisite.text.trim(),
              repeatable: _repeatable,
              abilityBonuses: _abilityBonuses,
              effect: _effect.text.trim(),
              updatedAt: DateTime.now(),
            ),
          );
      if (mounted) setState(() => _isNewDraft = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feats = ref.watch(allFeatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compendium'),
        actions: [
          IconButton(
            tooltip: 'Importer un CSV',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed:
                () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Import CSV : bientôt disponible'),
                  ),
                ),
          ),
          IconButton(
            tooltip: 'Nouveau contenu',
            icon: const Icon(Icons.add),
            onPressed: _createDraft,
          ),
        ],
      ),
      body: Column(
        children: [
          const AdminCompendiumTabs(current: AppRoutes.adminFeats),
          Expanded(
            child: feats.when(
              data: (list) {
                final query = _search.text.trim().toLowerCase();
                final filtered =
                    query.isEmpty
                        ? list
                        : list
                            .where((f) => f.name.toLowerCase().contains(query))
                            .toList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _FeatList(
                        items: filtered,
                        selectedId: _selectedId,
                        searchController: _search,
                        onSearchChanged: () => setState(() {}),
                        onSelect: _select,
                      ),
                    ),
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    Expanded(
                      child:
                          _selectedId == null
                              ? Center(
                                child: Text(
                                  'Sélectionne un don, ou crées-en un '
                                  'nouveau',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                              : _FeatForm(
                                key: ValueKey(_selectedId),
                                isNew: _isNewDraft,
                                source: _source,
                                category: _category,
                                repeatable: _repeatable,
                                abilityBonuses: _abilityBonuses,
                                onSourceChanged:
                                    (s) => setState(() => _source = s),
                                onCategoryChanged:
                                    (v) => setState(() => _category = v),
                                onRepeatableChanged:
                                    (v) => setState(() => _repeatable = v),
                                onAbilityBonusesChanged:
                                    (v) => setState(() => _abilityBonuses = v),
                                name: _name,
                                sourcebook: _sourcebook,
                                prerequisite: _prerequisite,
                                effect: _effect,
                                saving: _saving,
                                onSave: _save,
                              ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) =>
                      Center(child: Text('Chargement impossible : $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatList extends StatelessWidget {
  const _FeatList({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final List<AdminFeatDoc> items;
  final String? selectedId;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<AdminFeatDoc> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher un don',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = items[index];
              final active = item.id == selectedId;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(
                      color: active ? AppTheme.accent : AppTheme.border,
                      width: active ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.source.shortLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeatForm extends StatelessWidget {
  const _FeatForm({
    super.key,
    required this.isNew,
    required this.source,
    required this.category,
    required this.repeatable,
    required this.abilityBonuses,
    required this.onSourceChanged,
    required this.onCategoryChanged,
    required this.onRepeatableChanged,
    required this.onAbilityBonusesChanged,
    required this.name,
    required this.sourcebook,
    required this.prerequisite,
    required this.effect,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final SpeciesSource source;
  final String category;
  final bool repeatable;
  final List<FeatAbilityBonus> abilityBonuses;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onRepeatableChanged;
  final ValueChanged<List<FeatAbilityBonus>> onAbilityBonusesChanged;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController prerequisite;
  final TextEditingController effect;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('feat-name-field'),
                  controller: name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom du don',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nouveau contenu, pas encore enregistré',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AdminLabeledDropdown<SpeciesSource>(
                    label: 'Source',
                    value: source,
                    items: SpeciesSource.values,
                    labelOf: (s) => s.label,
                    onChanged: onSourceChanged,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AdminLabeledField(
                    label: 'Ouvrage / édition',
                    controller: sourcebook,
                    hint: 'ex. Guide de Xanathar',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Catégorie',
                  value: category,
                  items: _categories,
                  labelOf: (s) => s,
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(
                  label: 'Prérequis',
                  controller: prerequisite,
                  hint: 'ex. Niveau 4+',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledDropdown<bool>(
                  label: 'Répétable',
                  value: repeatable,
                  items: const [false, true],
                  labelOf: (v) => v ? 'Oui' : 'Non',
                  onChanged: onRepeatableChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AbilityBonusesEditor(
            bonuses: abilityBonuses,
            onChanged: onAbilityBonusesChanged,
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Effet', controller: effect, maxLines: 6),
        ],
      ),
    );
  }
}

/// Liste dynamique de bonus de caractéristique : ajouter/retirer des lignes.
/// Le montant est un menu déroulant (+1 à +4) plutôt qu'un champ libre — les
/// dons n'accordent quasiment jamais plus que ça, et ça évite de gérer un
/// contrôleur de texte par ligne ajoutée/retirée.
class _AbilityBonusesEditor extends StatelessWidget {
  const _AbilityBonusesEditor({required this.bonuses, required this.onChanged});

  final List<FeatAbilityBonus> bonuses;
  final ValueChanged<List<FeatAbilityBonus>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BONUS DE CARACTÉRISTIQUE (appliqué automatiquement à la fiche)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  () => onChanged([
                    ...bonuses,
                    const FeatAbilityBonus(ability: 'Force', amount: 1),
                  ]),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Ajouter un bonus'),
            ),
          ),
          for (var i = 0; i < bonuses.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: bonuses[i].ability,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final a in _abilities)
                          DropdownMenuItem(
                            value: a,
                            child: Text(a, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        final next = [...bonuses];
                        next[i] = FeatAbilityBonus(
                          ability: v,
                          amount: bonuses[i].amount,
                        );
                        onChanged(next);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('+', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<int>(
                      initialValue: bonuses[i].amount,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final n in const [1, 2, 3, 4])
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        final next = [...bonuses];
                        next[i] = FeatAbilityBonus(
                          ability: bonuses[i].ability,
                          amount: v,
                        );
                        onChanged(next);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirer ce bonus',
                    icon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final next = [...bonuses]..removeAt(i);
                      onChanged(next);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
