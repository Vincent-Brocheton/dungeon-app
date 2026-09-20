import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Éditeur d'espèces : liste (pack SRD + surcharges admin) à gauche, fiche
/// éditable à droite. Reprend `SpeciesEditorNoModal.dc.html` — sans la
/// sidebar (pas de pattern de navigation latérale ailleurs dans l'app) ni
/// l'import CSV (fonctionnalité à part entière, laissée pour plus tard : le
/// bouton existe mais annonce juste qu'il arrive).
class AdminSpeciesEditorScreen extends ConsumerStatefulWidget {
  const AdminSpeciesEditorScreen({super.key});

  @override
  ConsumerState<AdminSpeciesEditorScreen> createState() =>
      _AdminSpeciesEditorScreenState();
}

class _AdminSpeciesEditorScreenState
    extends ConsumerState<AdminSpeciesEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _speed = TextEditingController();
  final _vision = TextEditingController();
  final _languages = TextEditingController();
  final _traits = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _size = 'Moyenne';

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _speed,
      _vision,
      _languages,
      _traits,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(AdminSpeciesDoc doc) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = false;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _speed.text = doc.speed;
      _vision.text = doc.vision;
      _languages.text = doc.languages;
      _traits.text = doc.traits;
      _description.text = doc.description;
      _source = doc.source;
      _size = doc.size;
    });
  }

  void _createDraft() {
    final id = ref.read(adminSpeciesRepositoryProvider).newId();
    setState(() {
      _selectedId = id;
      _isNewDraft = true;
      _name.clear();
      _sourcebook.clear();
      _speed.clear();
      _vision.clear();
      _languages.clear();
      _traits.clear();
      _description.clear();
      _source = SpeciesSource.homebrew;
      _size = 'Moyenne';
    });
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminSpeciesRepositoryProvider)
          .upsert(
            AdminSpeciesDoc(
              id: id,
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              size: _size,
              speed: _speed.text.trim(),
              vision: _vision.text.trim(),
              languages: _languages.text.trim(),
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
          const AdminCompendiumTabs(current: AppRoutes.adminSpecies),
          Expanded(
            child: species.when(
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
                      width: 300,
                      child: _SpeciesList(
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
                                  'Sélectionne une espèce, ou crées-en une '
                                  'nouvelle',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                              : _SpeciesForm(
                                key: ValueKey(_selectedId),
                                isNew: _isNewDraft,
                                source: _source,
                                size: _size,
                                onSourceChanged:
                                    (s) => setState(() => _source = s),
                                onSizeChanged: (s) => setState(() => _size = s),
                                name: _name,
                                sourcebook: _sourcebook,
                                speed: _speed,
                                vision: _vision,
                                languages: _languages,
                                traits: _traits,
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

class _SpeciesList extends StatelessWidget {
  const _SpeciesList({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final List<AdminSpeciesDoc> items;
  final String? selectedId;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<AdminSpeciesDoc> onSelect;

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
              hintText: 'Chercher une espèce',
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpeciesForm extends StatelessWidget {
  const _SpeciesForm({
    super.key,
    required this.isNew,
    required this.source,
    required this.size,
    required this.onSourceChanged,
    required this.onSizeChanged,
    required this.name,
    required this.sourcebook,
    required this.speed,
    required this.vision,
    required this.languages,
    required this.traits,
    required this.description,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final SpeciesSource source;
  final String size;
  final ValueChanged<SpeciesSource> onSourceChanged;
  final ValueChanged<String> onSizeChanged;
  final TextEditingController name;
  final TextEditingController sourcebook;
  final TextEditingController speed;
  final TextEditingController vision;
  final TextEditingController languages;
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
                  key: const Key('species-name-field'),
                  controller: name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de l\'espèce',
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
                  label: 'Taille',
                  value: size,
                  items: const ['Petite', 'Moyenne'],
                  labelOf: (s) => s,
                  onChanged: onSizeChanged,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(label: 'Vitesse', controller: speed),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AdminLabeledField(label: 'Vision', controller: vision),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push(AppRoutes.adminSubspecies),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gérer les variantes rattachées à cette espèce '
                      '(ex. Haut-Elfe, Elfe des Bois…)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sous-espèces',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Langues', controller: languages),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Traits', controller: traits, maxLines: 3),
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
