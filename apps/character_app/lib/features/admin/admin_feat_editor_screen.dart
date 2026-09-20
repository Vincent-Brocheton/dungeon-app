import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_feat_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

const _categories = [
  "Don d'origine",
  'Don général',
  'Don de style de combat',
  'Don de faveur épique',
];

const _abilities = [
  'Force',
  'Dextérité',
  'Constitution',
  'Intelligence',
  'Sagesse',
  'Charisme',
];

const _distributions = [
  'Sur une seule caractéristique',
  AdminFeatDoc.defaultDistribution,
  'Répartis librement (1 par caractéristique)',
];

/// Regroupe par catégorie, sauf le contenu homebrew qui a son propre groupe
/// (peu importe la catégorie choisie) : plus facile à retrouver et à gérer
/// séparément du contenu SRD/officiel, qui lui reste organisé par catégorie
/// réelle de jeu.
String _groupKey(AdminFeatDoc f) =>
    f.source == SpeciesSource.homebrew ? 'Homebrew' : f.category;

String _groupLabel(String key) => switch (key) {
  "Don d'origine" => "Dons d'origine",
  'Don général' => 'Dons généraux',
  'Don de style de combat' => 'Dons de style de combat',
  'Don de faveur épique' => 'Dons de faveur épique',
  _ => key,
};

const _groupOrder = [..._categories, 'Homebrew'];

String _sourceSubtitle(SpeciesSource source) => switch (source) {
  SpeciesSource.srd => 'Contenu SRD 5.2 · modifiable',
  SpeciesSource.official => 'Contenu officiel · modifiable',
  SpeciesSource.homebrew => 'Don créé pour ta table · modifiable',
};

/// Éditeur de dons : liste (groupée par catégorie) à gauche, fiche éditable
/// à droite. Reprend `FeatsEditorNoModal.dc.html` — sans sidebar ni import
/// CSV (bouton présent, annonce juste qu'il arrive). Aucun don dans le pack
/// SRD statique : tout est admin-créé.
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
  final _summary = TextEditingController();
  final _levelMinimum = TextEditingController(text: '1');
  final _otherPrerequisites = TextEditingController();
  final _pointsToDistribute = TextEditingController(text: '2');
  final _maxValue = TextEditingController(text: '20');
  final _effect = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _category = 'Don général';
  var _repeatable = false;
  var _eligibleAbilities = List<String>.of(_abilities);
  var _distribution = AdminFeatDoc.defaultDistribution;

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _summary,
      _levelMinimum,
      _otherPrerequisites,
      _pointsToDistribute,
      _maxValue,
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
      _summary.text = doc.summary;
      _levelMinimum.text = '${doc.levelMinimum}';
      _otherPrerequisites.text = doc.otherPrerequisites;
      _pointsToDistribute.text = '${doc.pointsToDistribute}';
      _maxValue.text = '${doc.maxValue}';
      _effect.text = doc.effect;
      _source = doc.source;
      _category = doc.category;
      _repeatable = doc.repeatable;
      _eligibleAbilities = List.of(doc.eligibleAbilities);
      _distribution = doc.distribution;
    });
  }

  void _createDraft() {
    final id = ref.read(adminFeatRepositoryProvider).newId();
    setState(() {
      _selectedId = id;
      _isNewDraft = true;
      _name.clear();
      _sourcebook.clear();
      _summary.clear();
      _levelMinimum.text = '1';
      _otherPrerequisites.clear();
      _pointsToDistribute.text = '2';
      _maxValue.text = '20';
      _effect.clear();
      _source = SpeciesSource.homebrew;
      _category = 'Don général';
      _repeatable = false;
      _eligibleAbilities = List.of(_abilities);
      _distribution = AdminFeatDoc.defaultDistribution;
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
              summary: _summary.text.trim(),
              category: _category,
              levelMinimum: int.tryParse(_levelMinimum.text.trim()) ?? 1,
              otherPrerequisites: _otherPrerequisites.text.trim(),
              repeatable: _repeatable,
              eligibleAbilities: _eligibleAbilities,
              pointsToDistribute:
                  int.tryParse(_pointsToDistribute.text.trim()) ?? 2,
              distribution: _distribution,
              maxValue: int.tryParse(_maxValue.text.trim()) ?? 20,
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
                                eligibleAbilities: _eligibleAbilities,
                                distribution: _distribution,
                                onSourceChanged:
                                    (s) => setState(() => _source = s),
                                onCategoryChanged:
                                    (v) => setState(() => _category = v),
                                onRepeatableChanged:
                                    (v) => setState(() => _repeatable = v),
                                onEligibleAbilitiesChanged:
                                    (v) =>
                                        setState(() => _eligibleAbilities = v),
                                onDistributionChanged:
                                    (v) => setState(() => _distribution = v),
                                name: _name,
                                sourcebook: _sourcebook,
                                summary: _summary,
                                levelMinimum: _levelMinimum,
                                otherPrerequisites: _otherPrerequisites,
                                pointsToDistribute: _pointsToDistribute,
                                maxValue: _maxValue,
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

    final grouped = <String, List<AdminFeatDoc>>{};
    for (final item in items) {
      (grouped[_groupKey(item)] ??= []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final groupKeys = [
      for (final key in _groupOrder)
        if (grouped.containsKey(key)) key,
    ];

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              for (final key in groupKeys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    _groupLabel(key).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                for (final item in grouped[key]!) ...[
                  _FeatTile(
                    item: item,
                    active: item.id == selectedId,
                    onTap: () => onSelect(item),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatTile extends StatelessWidget {
  const _FeatTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AdminFeatDoc item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            color: active ? AppTheme.accent : AppTheme.border,
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
      ),
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
    required this.eligibleAbilities,
    required this.distribution,
    required this.onSourceChanged,
    required this.onCategoryChanged,
    required this.onRepeatableChanged,
    required this.onEligibleAbilitiesChanged,
    required this.onDistributionChanged,
    required this.name,
    required this.sourcebook,
    required this.summary,
    required this.levelMinimum,
    required this.otherPrerequisites,
    required this.pointsToDistribute,
    required this.maxValue,
    required this.effect,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final SpeciesSource source;
  final String category;
  final bool repeatable;
  final List<String> eligibleAbilities;
  final String distribution;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onRepeatableChanged;
  final ValueChanged<List<String>> onEligibleAbilitiesChanged;
  final ValueChanged<String> onDistributionChanged;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController summary;
  final TextEditingController levelMinimum;
  final TextEditingController otherPrerequisites;
  final TextEditingController pointsToDistribute;
  final TextEditingController maxValue;
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isNew
                  ? 'Nouveau contenu, pas encore enregistré'
                  : _sourceSubtitle(source),
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
          AdminLabeledField(label: 'Résumé', controller: summary),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  label: 'Niveau minimum',
                  controller: levelMinimum,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: AdminLabeledField(
                  key: const Key('feat-other-prerequisites-field'),
                  label: 'Autres prérequis',
                  controller: otherPrerequisites,
                  hint: 'ex. Force ou Dextérité 13 ou plus',
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
          Container(
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
                  'BONUS DE CARACTÉRISTIQUE (appliqué automatiquement à la '
                  'fiche)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'CARACTÉRISTIQUES ÉLIGIBLES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final a in _abilities)
                      _AbilityCheckbox(
                        label: a,
                        checked: eligibleAbilities.contains(a),
                        onChanged: (checked) {
                          final next = List<String>.of(eligibleAbilities);
                          if (checked) {
                            if (!next.contains(a)) next.add(a);
                          } else {
                            next.remove(a);
                          }
                          onEligibleAbilitiesChanged(next);
                        },
                      ),
                    _AbilityCheckbox(
                      label: 'Toutes',
                      accent: true,
                      checked: eligibleAbilities.length == _abilities.length,
                      onChanged:
                          (checked) => onEligibleAbilitiesChanged(
                            checked ? List.of(_abilities) : const [],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminLabeledField(
                        label: 'Points à répartir',
                        controller: pointsToDistribute,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AdminLabeledDropdown<String>(
                        label: 'Répartition',
                        value: distribution,
                        items: _distributions,
                        labelOf: (s) => s,
                        onChanged: onDistributionChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminLabeledField(
                        label: 'Maximum',
                        controller: maxValue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Choix fait par le joueur à l'attribution du don ; la "
                  'valeur et le modificateur sont recalculés automatiquement '
                  'sur la fiche.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Effet', controller: effect, maxLines: 6),
        ],
      ),
    );
  }
}

class _AbilityCheckbox extends StatelessWidget {
  const _AbilityCheckbox({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.accent = false,
  });

  final String label;
  final bool checked;
  final bool accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent ? AppTheme.accent : AppTheme.textPrimary,
              fontWeight: accent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
