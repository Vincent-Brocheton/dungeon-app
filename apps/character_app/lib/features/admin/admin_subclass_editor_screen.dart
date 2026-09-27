import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../data/admin_subclass_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

String _sourceSubtitle(SpeciesSource source) => switch (source) {
  SpeciesSource.srd => 'Contenu SRD 5.2 · modifiable',
  SpeciesSource.official => 'Contenu officiel · modifiable',
  SpeciesSource.homebrew => 'Sous-classe créée pour ta table · modifiable',
};

/// Éditeur de sous-classes : liste groupée par classe parente à gauche,
/// fiche éditable à droite. Reprend `SubclassesEditor.dc.html` — sans
/// sidebar. Aucune sous-classe dans le pack SRD statique : tout est
/// admin-créé (`content/subclasses`).
class AdminSubclassEditorScreen extends ConsumerStatefulWidget {
  const AdminSubclassEditorScreen({super.key});

  @override
  ConsumerState<AdminSubclassEditorScreen> createState() =>
      _AdminSubclassEditorScreenState();
}

class _AdminSubclassEditorScreenState
    extends ConsumerState<AdminSubclassEditorScreen> {
  String? _selectedId;

  /// Document chargé : enregistrer part de lui pour ne pas écraser les
  /// aptitudes par niveau (table de progression).
  AdminSubclassDoc? _loaded;
  var _isNewDraft = false;
  var _saving = false;
  String? _parentFilter;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _features = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _parentClassId = '';
  var _level = 3;

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _features,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminSubclassDoc doc, {required bool isNew}) {
    setState(() {
      _selectedId = doc.id;
      _loaded = doc;
      _isNewDraft = isNew;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _features.text = doc.features;
      _description.text = doc.description;
      _source = doc.source;
      _parentClassId = doc.parentClassId;
      _level = doc.level;
    });
  }

  void _createDraft(List<AdminClassDoc> classes) {
    final id = ref.read(adminSubclassRepositoryProvider).newId();
    _load(
      AdminSubclassDoc(
        id: id,
        name: '',
        parentClassId:
            _parentFilter ?? (classes.isEmpty ? '' : classes.first.id),
        updatedAt: DateTime.now(),
      ),
      isNew: true,
    );
  }

  Future<void> _save() async {
    final loaded = _loaded;
    if (loaded == null || _name.text.trim().isEmpty || _parentClassId.isEmpty) {
      return;
    }
    // Dernière version connue (la progression a pu être enregistrée depuis
    // le chargement), sinon le brouillon.
    final latest =
        ref
            .read(allSubclassesProvider)
            .value
            ?.where((s) => s.id == loaded.id)
            .firstOrNull ??
        loaded;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminSubclassRepositoryProvider)
          .upsert(
            latest.copyWith(
              name: _name.text.trim(),
              parentClassId: _parentClassId,
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              level: _level,
              features: _features.text.trim(),
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
    final classes = ref.watch(allClassesProvider);
    final subclasses = ref.watch(allSubclassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sous-classes'),
        actions: [
          IconButton(
            tooltip: 'Nouvelle sous-classe',
            icon: const Icon(Icons.add),
            onPressed:
                classes.value == null
                    ? null
                    : () => _createDraft(classes.value!),
          ),
        ],
      ),
      body: classes.when(
        data:
            (classList) => subclasses.when(
              data: (subclassList) => _buildBody(classList, subclassList),
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

  Widget _buildBody(
    List<AdminClassDoc> classList,
    List<AdminSubclassDoc> subclassList,
  ) {
    final theme = Theme.of(context);
    final classNameById = {for (final c in classList) c.id: c.name};
    final query = _search.text.trim().toLowerCase();
    final grouped = <String, List<AdminSubclassDoc>>{};
    for (final sub
        in subclassList.toList()..sort((a, b) => a.name.compareTo(b.name))) {
      if (_parentFilter != null && sub.parentClassId != _parentFilter) {
        continue;
      }
      if (!sub.name.toLowerCase().contains(query)) continue;
      (grouped[sub.parentClassId] ??= []).add(sub);
    }
    final groupIds =
        grouped.keys.toList()..sort(
          (a, b) => (classNameById[a] ?? a).compareTo(classNameById[b] ?? b),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Chercher une sous-classe',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _parentFilter,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Classe parente : Toutes'),
                    ),
                    for (final c in classList)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('Classe parente : ${c.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _parentFilter = v),
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
                          (classNameById[groupId] ?? groupId).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      for (final item in grouped[groupId]!) ...[
                        _SubclassTile(
                          item: item,
                          active: item.id == _selectedId,
                          onTap: () => _load(item, isNew: false),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppTheme.border),
        Expanded(
          child:
              _selectedId == null
                  ? Center(
                    child: Text(
                      'Sélectionne une sous-classe, ou crées-en une nouvelle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                  : _buildForm(classList),
        ),
      ],
    );
  }

  Widget _buildForm(List<AdminClassDoc> classList) {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    final progressionRoute =
        Uri(
          path: AppRoutes.adminLevelProgression,
          queryParameters: {
            'classId': _parentClassId,
            'subclassId': _selectedId,
          },
        ).toString();
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
                  key: const Key('subclass-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de la sous-classe',
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
                  : _sourceSubtitle(_source),
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
          Row(
            children: [
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Classe parente',
                  value: _parentClassId,
                  items: [for (final c in classList) c.id],
                  labelOf:
                      (id) =>
                          classList
                              .where((c) => c.id == id)
                              .firstOrNull
                              ?.name ??
                          id,
                  onChanged: (id) => setState(() => _parentClassId = id),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<int>(
                  label: 'Niveau d\'obtention',
                  value: _level,
                  items: [for (var l = 1; l <= 20; l++) l],
                  labelOf: (l) => '$l',
                  onChanged: (l) => setState(() => _level = l),
                ),
              ),
            ],
          ),
          if (classList.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Crée d\'abord une classe pour pouvoir y rattacher une '
                'sous-classe.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 14),
          AdminLabeledField(
            key: const Key('subclass-features-field'),
            label: 'Aptitudes principales (résumé)',
            controller: _features,
          ),
          const SizedBox(height: 14),
          AdminLinkCard(
            text:
                'Configurer les aptitudes niveau par niveau de cette '
                'sous-classe',
            action: 'Table de progression',
            route: progressionRoute,
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

class _SubclassTile extends StatelessWidget {
  const _SubclassTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AdminSubclassDoc item;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            Text(
              'Choisie au niv. ${item.level}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
