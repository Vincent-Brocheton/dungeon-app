import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_invocation_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Éditeur de manifestations occultes : liste (prérequis résumés sous le
/// nom) à gauche, fiche éditable à droite. Reprend
/// `InvocationsEditorNoModal.dc.html` — sans sidebar ni import CSV (bouton
/// présent, annonce juste qu'il arrive). Aucune manifestation dans le pack
/// SRD statique : tout est admin-créé.
class AdminInvocationEditorScreen extends ConsumerStatefulWidget {
  const AdminInvocationEditorScreen({super.key});

  @override
  ConsumerState<AdminInvocationEditorScreen> createState() =>
      _AdminInvocationEditorScreenState();
}

class _AdminInvocationEditorScreenState
    extends ConsumerState<AdminInvocationEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _summary = TextEditingController();
  final _otherPrerequisites = TextEditingController();
  final _effect = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _level = 1;
  var _repeatable = false;

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _summary,
      _otherPrerequisites,
      _effect,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminInvocationDoc doc, {required bool isNew}) {
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = isNew;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _summary.text = doc.summary;
      _otherPrerequisites.text = doc.otherPrerequisites;
      _effect.text = doc.effect;
      _source = doc.source;
      _level = doc.level;
      _repeatable = doc.repeatable;
    });
  }

  void _createDraft() {
    final id = ref.read(adminInvocationRepositoryProvider).newId();
    _load(
      AdminInvocationDoc(id: id, name: '', updatedAt: DateTime.now()),
      isNew: true,
    );
  }

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminInvocationRepositoryProvider)
          .upsert(
            AdminInvocationDoc(
              id: id,
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              summary: _summary.text.trim(),
              level: _level,
              otherPrerequisites: _otherPrerequisites.text.trim(),
              repeatable: _repeatable,
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
    final invocations = ref.watch(allInvocationsProvider);

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
          const AdminCompendiumTabs(current: AppRoutes.adminInvocations),
          Expanded(
            child: invocations.when(
              data: (list) {
                final query = _search.text.trim().toLowerCase();
                final filtered =
                    list
                        .where((i) => i.name.toLowerCase().contains(query))
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
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
                                  'Sélectionne une manifestation, ou crées-en '
                                  'une nouvelle',
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

  Widget _buildList(List<AdminInvocationDoc> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher une manifestation',
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
                subtitle: item.prerequisitesLabel,
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
                  key: const Key('invocation-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de la manifestation',
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
                  : adminSourceSubtitle(_source, 'Manifestation créée'),
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
          AdminLabeledField(label: 'Résumé', controller: _summary),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledDropdown<int>(
                  key: const Key('invocation-level-dropdown'),
                  label: 'Niveau requis',
                  value: _level,
                  items: [for (var l = 1; l <= 20; l++) l],
                  labelOf: (l) => '$l',
                  onChanged: (l) => setState(() => _level = l),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledField(
                  key: const Key('invocation-prerequisites-field'),
                  label: 'Autres prérequis (texte libre)',
                  controller: _otherPrerequisites,
                  hint: 'ex. Manifestation Pacte de la lame',
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<bool>(
                  key: const Key('invocation-repeatable-dropdown'),
                  label: 'Répétable',
                  value: _repeatable,
                  items: const [false, true],
                  labelOf: (b) => b ? 'Oui' : 'Non',
                  onChanged: (b) => setState(() => _repeatable = b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminLabeledField(label: 'Effet', controller: _effect, maxLines: 6),
        ],
      ),
    );
  }
}
