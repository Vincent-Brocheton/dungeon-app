import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_spell_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

const _schools = [
  'Abjuration',
  'Conjuration',
  'Divination',
  'Enchantement',
  'Évocation',
  'Illusion',
  'Nécromancie',
  'Transmutation',
];

const _rollTypes = ['Jet de sauvegarde', "Jet d'attaque de sort", 'Aucun'];

const _abilities = [
  'Force',
  'Dextérité',
  'Constitution',
  'Intelligence',
  'Sagesse',
  'Charisme',
];

const _onSuccessOptions = ['Moitié des dégâts', 'Aucun effet', 'Effet réduit'];

String _levelLabel(int level) => level == 0 ? 'Tour de magie' : 'Niveau $level';

/// Éditeur de sorts : liste à gauche, fiche éditable à droite. Reprend
/// `CompendiumEditorNoModal.dc.html` — sans sidebar ni import CSV (bouton
/// présent, annonce juste qu'il arrive, même choix que les espèces). Aucun
/// sort dans le pack SRD statique : tout est admin-créé.
class AdminSpellEditorScreen extends ConsumerStatefulWidget {
  const AdminSpellEditorScreen({super.key});

  @override
  ConsumerState<AdminSpellEditorScreen> createState() =>
      _AdminSpellEditorScreenState();
}

class _AdminSpellEditorScreenState
    extends ConsumerState<AdminSpellEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _castingTime = TextEditingController();
  final _range = TextEditingController();
  final _components = TextEditingController();
  final _duration = TextEditingController();
  final _classes = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _level = 1;
  var _school = 'Évocation';
  var _rollType = 'Aucun';
  var _saveAbility = 'Dextérité';
  var _onSuccess = 'Moitié des dégâts';

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _castingTime,
      _range,
      _components,
      _duration,
      _classes,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(AdminSpellDoc doc) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = false;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _castingTime.text = doc.castingTime;
      _range.text = doc.range;
      _components.text = doc.components;
      _duration.text = doc.duration;
      _classes.text = doc.classes;
      _description.text = doc.description;
      _source = doc.source;
      _level = doc.level;
      _school = doc.school;
      _rollType = doc.rollType;
      _saveAbility = doc.saveAbility;
      _onSuccess = doc.onSuccess;
    });
  }

  void _createDraft() {
    final id = ref.read(adminSpellRepositoryProvider).newId();
    setState(() {
      _selectedId = id;
      _isNewDraft = true;
      _name.clear();
      _sourcebook.clear();
      _castingTime.clear();
      _range.clear();
      _components.clear();
      _duration.clear();
      _classes.clear();
      _description.clear();
      _source = SpeciesSource.homebrew;
      _level = 1;
      _school = 'Évocation';
      _rollType = 'Aucun';
      _saveAbility = 'Dextérité';
      _onSuccess = 'Moitié des dégâts';
    });
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminSpellRepositoryProvider)
          .upsert(
            AdminSpellDoc(
              id: id,
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              level: _level,
              school: _school,
              castingTime: _castingTime.text.trim(),
              range: _range.text.trim(),
              components: _components.text.trim(),
              duration: _duration.text.trim(),
              classes: _classes.text.trim(),
              rollType: _rollType,
              saveAbility: _saveAbility,
              onSuccess: _onSuccess,
              description: _description.text.trim(),
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
    final spells = ref.watch(allSpellsProvider);

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
          const AdminCompendiumTabs(current: AppRoutes.adminSpells),
          Expanded(
            child: spells.when(
              data: (list) {
                final query = _search.text.trim().toLowerCase();
                final filtered =
                    query.isEmpty
                        ? list
                        : list
                            .where((s) => s.name.toLowerCase().contains(query))
                            .toList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _SpellList(
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
                                  'Sélectionne un sort, ou crées-en un '
                                  'nouveau',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                              : _SpellForm(
                                key: ValueKey(_selectedId),
                                isNew: _isNewDraft,
                                source: _source,
                                level: _level,
                                school: _school,
                                rollType: _rollType,
                                saveAbility: _saveAbility,
                                onSuccessOption: _onSuccess,
                                onSourceChanged:
                                    (s) => setState(() => _source = s),
                                onLevelChanged:
                                    (v) => setState(() => _level = v),
                                onSchoolChanged:
                                    (v) => setState(() => _school = v),
                                onRollTypeChanged:
                                    (v) => setState(() => _rollType = v),
                                onSaveAbilityChanged:
                                    (v) => setState(() => _saveAbility = v),
                                onSuccessChanged:
                                    (v) => setState(() => _onSuccess = v),
                                name: _name,
                                sourcebook: _sourcebook,
                                castingTime: _castingTime,
                                range: _range,
                                components: _components,
                                duration: _duration,
                                classes: _classes,
                                description: _description,
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

class _SpellList extends StatelessWidget {
  const _SpellList({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final List<AdminSpellDoc> items;
  final String? selectedId;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<AdminSpellDoc> onSelect;

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
              hintText: 'Chercher un sort',
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
                        '${_levelLabel(item.level)} · ${item.school}',
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

class _SpellForm extends StatelessWidget {
  const _SpellForm({
    super.key,
    required this.isNew,
    required this.source,
    required this.level,
    required this.school,
    required this.rollType,
    required this.saveAbility,
    required this.onSuccessOption,
    required this.onSourceChanged,
    required this.onLevelChanged,
    required this.onSchoolChanged,
    required this.onRollTypeChanged,
    required this.onSaveAbilityChanged,
    required this.onSuccessChanged,
    required this.name,
    required this.sourcebook,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.classes,
    required this.description,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final SpeciesSource source;
  final int level;
  final String school;
  final String rollType;
  final String saveAbility;
  final String onSuccessOption;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<String> onSchoolChanged;
  final ValueChanged<String> onRollTypeChanged;
  final ValueChanged<String> onSaveAbilityChanged;
  final ValueChanged<String> onSuccessChanged;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController castingTime;
  final TextEditingController range;
  final TextEditingController components;
  final TextEditingController duration;
  final TextEditingController classes;
  final TextEditingController description;
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
                  key: const Key('spell-name-field'),
                  controller: name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom du sort',
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
                child: AdminLabeledDropdown<int>(
                  label: 'Niveau',
                  value: level,
                  items: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
                  labelOf: _levelLabel,
                  onChanged: onLevelChanged,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'École',
                  value: school,
                  items: _schools,
                  labelOf: (s) => s,
                  onChanged: onSchoolChanged,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(
                  label: "Temps d'incantation",
                  controller: castingTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledField(label: 'Portée', controller: range),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(
                  label: 'Composantes',
                  controller: components,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(label: 'Durée', controller: duration),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Classes', controller: classes),
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
                  'RÉSOLUTION AUTOMATIQUE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AdminLabeledDropdown<String>(
                        label: 'Jet imposé',
                        value: rollType,
                        items: _rollTypes,
                        labelOf: (s) => s,
                        onChanged: onRollTypeChanged,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AdminLabeledDropdown<String>(
                        label: 'Caractéristique de la cible (sauvegarde)',
                        value: saveAbility,
                        items: _abilities,
                        labelOf: (s) => s,
                        onChanged: onSaveAbilityChanged,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AdminLabeledDropdown<String>(
                        label: 'Effet si réussite',
                        value: onSuccessOption,
                        items: _onSuccessOptions,
                        labelOf: (s) => s,
                        onChanged: onSuccessChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'DD calculé au jet, à partir de la classe du lanceur : '
                  '8 + Bonus de Maîtrise + mod. de sa Caractéristique '
                  "d'incantation (définie dans l'onglet Classes) — aucune "
                  'valeur à saisir ici.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Description',
            controller: description,
            maxLines: 6,
          ),
        ],
      ),
    );
  }
}
