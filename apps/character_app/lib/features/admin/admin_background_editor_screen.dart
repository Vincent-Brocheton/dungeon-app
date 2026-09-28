import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_background_doc.dart';
import '../../data/admin_class_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Éditeur d'historiques : liste (pack SRD + surcharges admin) à gauche,
/// fiche éditable à droite. Reprend `BackgroundsEditorNoModal.dc.html` —
/// sans sidebar ni import CSV (bouton présent, annonce juste qu'il arrive).
/// PHB 2024 : exactement 3 caractéristiques éligibles, imposé à la saisie.
class AdminBackgroundEditorScreen extends ConsumerStatefulWidget {
  const AdminBackgroundEditorScreen({super.key});

  @override
  ConsumerState<AdminBackgroundEditorScreen> createState() =>
      _AdminBackgroundEditorScreenState();
}

class _AdminBackgroundEditorScreenState
    extends ConsumerState<AdminBackgroundEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;
  var _showAbilityError = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _originFeat = TextEditingController();
  final _skills = TextEditingController();
  final _tool = TextEditingController();
  final _equipment = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _abilities = <String>[];

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _originFeat,
      _skills,
      _tool,
      _equipment,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminBackgroundDoc doc, {required bool isNew}) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = isNew;
      _showAbilityError = false;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _originFeat.text = doc.originFeat;
      _skills.text = doc.skills;
      _tool.text = doc.tool;
      _equipment.text = doc.equipment;
      _description.text = doc.description;
      _source = doc.source;
      _abilities = List.of(doc.abilities);
    });
  }

  void _createDraft() {
    final id = ref.read(adminBackgroundRepositoryProvider).newId();
    _load(
      AdminBackgroundDoc(id: id, name: '', updatedAt: DateTime.now()),
      isNew: true,
    );
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    if (_abilities.length != 3) {
      setState(() => _showAbilityError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(adminBackgroundRepositoryProvider)
          .upsert(
            AdminBackgroundDoc(
              id: id,
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              // Ordre canonique Force → Charisme, quel que soit l'ordre coché.
              abilities: [
                for (final a in AdminClassDoc.abilities)
                  if (_abilities.contains(a)) a,
              ],
              originFeat: _originFeat.text.trim(),
              skills: _skills.text.trim(),
              tool: _tool.text.trim(),
              equipment: _equipment.text.trim(),
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
    final backgrounds = ref.watch(allBackgroundsProvider);

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
          const AdminCompendiumTabs(current: AppRoutes.adminBackgrounds),
          Expanded(
            child: backgrounds.when(
              data: (list) {
                final query = _search.text.trim().toLowerCase();
                final filtered =
                    list
                        .where((b) => b.name.toLowerCase().contains(query))
                        .toList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 300, child: _buildList(filtered)),
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    Expanded(
                      child:
                          _selectedId == null
                              ? Center(
                                child: Text(
                                  'Sélectionne un historique, ou crées-en un '
                                  'nouveau',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                              : _buildForm(),
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

  Widget _buildList(List<AdminBackgroundDoc> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher un historique',
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
              final active = item.id == _selectedId;
              return AdminListTile(
                name: item.name,
                badge: item.source.shortLabel,
                active: active,
                onTap: () => _load(item, isNew: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    return SingleChildScrollView(
      key: ValueKey(_selectedId),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('background-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de l\'historique',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _isNewDraft
                  ? 'Nouveau contenu, pas encore enregistré'
                  : adminSourceSubtitle(_source, 'Historique créé'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AdminPanel(
            child: Row(
              children: [
                Expanded(
                  child: AdminLabeledDropdown<SpeciesSource>(
                    label: 'Source',
                    value: _source,
                    items: SpeciesSource.values,
                    labelOf: (s) => s.label,
                    onChanged: (s) => setState(() => _source = s),
                  ),
                ),
                gap,
                Expanded(
                  child: AdminLabeledField(
                    label: 'Ouvrage / édition',
                    controller: _sourcebook,
                    hint: 'ex. Guide de Xanathar',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARACTÉRISTIQUES ÉLIGIBLES (LE JOUEUR RÉPARTIT +2/+1 OU '
                  '+1/+1/+1 PARMI LES 3 COCHÉES)',
                  style: muted,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    for (final a in AdminClassDoc.abilities)
                      AdminCheckbox(
                        checkboxKey: Key('ability-$a'),
                        label: a,
                        checked: _abilities.contains(a),
                        enabled:
                            _abilities.contains(a) || _abilities.length < 3,
                        onChanged:
                            (checked) => setState(() {
                              checked
                                  ? _abilities.add(a)
                                  : _abilities.remove(a);
                            }),
                      ),
                  ],
                ),
                if (_showAbilityError && _abilities.length != 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Coche exactement 3 caractéristiques',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Don d\'Origine', controller: _originFeat),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledField(
                  label: 'Compétences',
                  controller: _skills,
                  hint: 'ex. Discrétion, Persuasion',
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledField(
                  key: const Key('background-tool-field'),
                  label: 'Outil',
                  controller: _tool,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Équipement de départ',
            controller: _equipment,
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Description',
            controller: _description,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
