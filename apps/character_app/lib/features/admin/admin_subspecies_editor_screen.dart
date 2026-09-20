import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_species_doc.dart';
import '../../data/admin_subspecies_doc.dart';
import '../../theme/app_theme.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Éditeur de sous-espèces : liste groupée par espèce parente à gauche,
/// fiche éditable à droite. Reprend `SubspeciesEditor.dc.html` — sans
/// sidebar ni import CSV (pas de pattern pour l'un ni l'autre ici : les
/// sous-espèces n'en ont pas dans la maquette, contrairement aux 6 éditeurs
/// de compendium). Aucune sous-espèce dans le pack SRD statique : tout est
/// admin-créé (`content/subspecies`), pas de fusion comme pour les espèces.
class AdminSubspeciesEditorScreen extends ConsumerStatefulWidget {
  const AdminSubspeciesEditorScreen({super.key});

  @override
  ConsumerState<AdminSubspeciesEditorScreen> createState() =>
      _AdminSubspeciesEditorScreenState();
}

class _AdminSubspeciesEditorScreenState
    extends ConsumerState<AdminSubspeciesEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;
  String? _parentFilter;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _speed = TextEditingController();
  final _vision = TextEditingController();
  final _extraTrait = TextEditingController();
  final _traits = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _parentSpeciesId = '';

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _speed,
      _vision,
      _extraTrait,
      _traits,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(AdminSubspeciesDoc doc) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = false;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _speed.text = doc.speed;
      _vision.text = doc.vision;
      _extraTrait.text = doc.extraTrait;
      _traits.text = doc.traits;
      _description.text = doc.description;
      _source = doc.source;
      _parentSpeciesId = doc.parentSpeciesId;
    });
  }

  void _createDraft(List<AdminSpeciesDoc> species) {
    final id = ref.read(adminSubspeciesRepositoryProvider).newId();
    setState(() {
      _selectedId = id;
      _isNewDraft = true;
      _name.clear();
      _sourcebook.clear();
      _speed.clear();
      _vision.clear();
      _extraTrait.clear();
      _traits.clear();
      _description.clear();
      _source = SpeciesSource.homebrew;
      _parentSpeciesId =
          _parentFilter ?? (species.isEmpty ? '' : species.first.id);
    });
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty || _parentSpeciesId.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(adminSubspeciesRepositoryProvider)
          .upsert(
            AdminSubspeciesDoc(
              id: id,
              name: _name.text.trim(),
              parentSpeciesId: _parentSpeciesId,
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              speed: _speed.text.trim(),
              vision: _vision.text.trim(),
              extraTrait: _extraTrait.text.trim(),
              traits: _traits.text.trim(),
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
    final species = ref.watch(allSpeciesProvider);
    final subspecies = ref.watch(allSubspeciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sous-espèces'),
        actions: [
          IconButton(
            tooltip: 'Nouvelle sous-espèce',
            icon: const Icon(Icons.add),
            onPressed:
                species.value == null
                    ? null
                    : () => _createDraft(species.value!),
          ),
        ],
      ),
      body: species.when(
        data:
            (speciesList) => subspecies.when(
              data:
                  (subspeciesList) => _Body(
                    speciesList: speciesList,
                    subspeciesList: subspeciesList,
                    selectedId: _selectedId,
                    isNewDraft: _isNewDraft,
                    saving: _saving,
                    source: _source,
                    parentSpeciesId: _parentSpeciesId,
                    parentFilter: _parentFilter,
                    searchController: _search,
                    name: _name,
                    sourcebook: _sourcebook,
                    speed: _speed,
                    vision: _vision,
                    extraTrait: _extraTrait,
                    traits: _traits,
                    description: _description,
                    onSearchChanged: () => setState(() {}),
                    onParentFilterChanged:
                        (v) => setState(() => _parentFilter = v),
                    onSelect: _select,
                    onSourceChanged: (s) => setState(() => _source = s),
                    onParentSpeciesChanged:
                        (id) => setState(() => _parentSpeciesId = id),
                    onSave: _save,
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) =>
                      Center(child: Text('Chargement impossible : $error')),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.speciesList,
    required this.subspeciesList,
    required this.selectedId,
    required this.isNewDraft,
    required this.saving,
    required this.source,
    required this.parentSpeciesId,
    required this.parentFilter,
    required this.searchController,
    required this.name,
    required this.sourcebook,
    required this.speed,
    required this.vision,
    required this.extraTrait,
    required this.traits,
    required this.description,
    required this.onSearchChanged,
    required this.onParentFilterChanged,
    required this.onSelect,
    required this.onSourceChanged,
    required this.onParentSpeciesChanged,
    required this.onSave,
  });

  final List<AdminSpeciesDoc> speciesList;
  final List<AdminSubspeciesDoc> subspeciesList;
  final String? selectedId;
  final bool isNewDraft;
  final bool saving;
  final SpeciesSource source;
  final String parentSpeciesId;
  final String? parentFilter;
  final TextEditingController searchController;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController speed;
  final TextEditingController vision;
  final TextEditingController extraTrait;
  final TextEditingController traits;
  final TextEditingController description;
  final VoidCallback onSearchChanged;
  final ValueChanged<String?> onParentFilterChanged;
  final ValueChanged<AdminSubspeciesDoc> onSelect;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<String> onParentSpeciesChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final speciesNameById = {for (final s in speciesList) s.id: s.name};
    final query = searchController.text.trim().toLowerCase();
    final filtered =
        subspeciesList.where((s) {
            if (parentFilter != null && s.parentSpeciesId != parentFilter) {
              return false;
            }
            return query.isEmpty || s.name.toLowerCase().contains(query);
          }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: _SubspeciesList(
            items: filtered,
            speciesNameById: speciesNameById,
            speciesList: speciesList,
            selectedId: selectedId,
            searchController: searchController,
            parentFilter: parentFilter,
            onSearchChanged: onSearchChanged,
            onParentFilterChanged: onParentFilterChanged,
            onSelect: onSelect,
          ),
        ),
        const VerticalDivider(width: 1, color: AppTheme.border),
        Expanded(
          child:
              selectedId == null
                  ? Center(
                    child: Text(
                      'Sélectionne une sous-espèce, ou crées-en une nouvelle',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                  : _SubspeciesForm(
                    key: ValueKey(selectedId),
                    isNew: isNewDraft,
                    source: source,
                    parentSpeciesId: parentSpeciesId,
                    speciesList: speciesList,
                    onSourceChanged: onSourceChanged,
                    onParentSpeciesChanged: onParentSpeciesChanged,
                    name: name,
                    sourcebook: sourcebook,
                    speed: speed,
                    vision: vision,
                    extraTrait: extraTrait,
                    traits: traits,
                    description: description,
                    saving: saving,
                    onSave: onSave,
                  ),
        ),
      ],
    );
  }
}

class _SubspeciesList extends StatelessWidget {
  const _SubspeciesList({
    required this.items,
    required this.speciesNameById,
    required this.speciesList,
    required this.selectedId,
    required this.searchController,
    required this.parentFilter,
    required this.onSearchChanged,
    required this.onParentFilterChanged,
    required this.onSelect,
  });

  final List<AdminSubspeciesDoc> items;
  final Map<String, String> speciesNameById;
  final List<AdminSpeciesDoc> speciesList;
  final String? selectedId;
  final TextEditingController searchController;
  final String? parentFilter;
  final VoidCallback onSearchChanged;
  final ValueChanged<String?> onParentFilterChanged;
  final ValueChanged<AdminSubspeciesDoc> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final grouped = <String, List<AdminSubspeciesDoc>>{};
    for (final item in items) {
      (grouped[item.parentSpeciesId] ??= []).add(item);
    }
    final groupIds =
        grouped.keys.toList()..sort(
          (a, b) =>
              (speciesNameById[a] ?? a).compareTo(speciesNameById[b] ?? b),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher une sous-espèce',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DropdownButtonFormField<String?>(
            initialValue: parentFilter,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Toutes')),
              for (final s in speciesList)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: onParentFilterChanged,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              for (final groupId in groupIds) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    (speciesNameById[groupId] ?? groupId).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                for (final item in grouped[groupId]!) ...[
                  _SubspeciesTile(
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

class _SubspeciesTile extends StatelessWidget {
  const _SubspeciesTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AdminSubspeciesDoc item;
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

class _SubspeciesForm extends StatelessWidget {
  const _SubspeciesForm({
    super.key,
    required this.isNew,
    required this.source,
    required this.parentSpeciesId,
    required this.speciesList,
    required this.onSourceChanged,
    required this.onParentSpeciesChanged,
    required this.name,
    required this.sourcebook,
    required this.speed,
    required this.vision,
    required this.extraTrait,
    required this.traits,
    required this.description,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final SpeciesSource source;
  final String parentSpeciesId;
  final List<AdminSpeciesDoc> speciesList;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<String> onParentSpeciesChanged;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController speed;
  final TextEditingController vision;
  final TextEditingController extraTrait;
  final TextEditingController traits;
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
                  key: const Key('subspecies-name-field'),
                  controller: name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de la sous-espèce',
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
          AdminLabeledDropdown<String>(
            label: 'Espèce parente',
            value: parentSpeciesId,
            items: [for (final s in speciesList) s.id],
            labelOf:
                (id) =>
                    speciesList.where((s) => s.id == id).firstOrNull?.name ??
                    id,
            onChanged: onParentSpeciesChanged,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledField(
                  label: 'Vitesse (remplace ou complète)',
                  controller: speed,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(label: 'Vision', controller: vision),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(
                  label: 'Trait supplémentaire',
                  controller: extraTrait,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Traits de sous-espèce',
            controller: traits,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Description',
            controller: description,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
