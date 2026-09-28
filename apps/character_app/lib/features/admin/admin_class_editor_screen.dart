import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Éditeur de classes : liste à gauche, fiche éditable à droite. Reprend
/// `ClassesEditorNoModal.dc.html` — sans sidebar ni import CSV (bouton
/// présent, annonce juste qu'il arrive). Aucune classe dans le pack SRD
/// statique : tout est admin-créé.
class AdminClassEditorScreen extends ConsumerStatefulWidget {
  const AdminClassEditorScreen({super.key});

  @override
  ConsumerState<AdminClassEditorScreen> createState() =>
      _AdminClassEditorScreenState();
}

class _AdminClassEditorScreenState
    extends ConsumerState<AdminClassEditorScreen> {
  String? _selectedId;

  /// Document chargé : enregistrer part de lui pour ne pas écraser les
  /// champs édités ailleurs (table de progression).
  AdminClassDoc? _loaded;
  var _isNewDraft = false;
  var _saving = false;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _sourcebook = TextEditingController();
  final _savingThrows = TextEditingController();
  final _skills = TextEditingController();
  final _resource = TextEditingController();
  final _description = TextEditingController();
  var _source = SpeciesSource.homebrew;
  var _hitDie = 'd8';
  var _primaryAbility = 'Force';
  var _recovery = 'Repos long';
  var _spellcaster = false;
  var _spellcastingAbility = 'Intelligence';

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      _sourcebook,
      _savingThrows,
      _skills,
      _resource,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminClassDoc doc, {required bool isNew}) {
    setState(() {
      _selectedId = doc.id;
      _loaded = doc;
      _isNewDraft = isNew;
      _name.text = doc.name;
      _sourcebook.text = doc.sourcebook;
      _savingThrows.text = doc.savingThrows;
      _skills.text = doc.skills;
      _resource.text = doc.resource;
      _description.text = doc.description;
      _source = doc.source;
      _hitDie = doc.hitDie;
      _primaryAbility = doc.primaryAbility;
      _recovery = doc.recovery;
      _spellcaster = doc.spellcaster;
      _spellcastingAbility = doc.spellcastingAbility;
    });
  }

  void _createDraft() {
    final id = ref.read(adminClassRepositoryProvider).newId();
    _load(
      AdminClassDoc(id: id, name: '', updatedAt: DateTime.now()),
      isNew: true,
    );
  }

  Future<void> _save() async {
    final loaded = _loaded;
    if (loaded == null || _name.text.trim().isEmpty) return;
    // Dernière version connue (la progression a pu être enregistrée depuis
    // le chargement), sinon le brouillon.
    final latest =
        ref
            .read(allClassesProvider)
            .value
            ?.where((c) => c.id == loaded.id)
            .firstOrNull ??
        loaded;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminClassRepositoryProvider)
          .upsert(
            latest.copyWith(
              name: _name.text.trim(),
              source: _source,
              sourcebook: _sourcebook.text.trim(),
              hitDie: _hitDie,
              primaryAbility: _primaryAbility,
              savingThrows: _savingThrows.text.trim(),
              skills: _skills.text.trim(),
              resource: _resource.text.trim(),
              recovery: _recovery,
              spellcaster: _spellcaster,
              spellcastingAbility: _spellcastingAbility,
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
          const AdminCompendiumTabs(current: AppRoutes.adminClasses),
          Expanded(
            child: classes.when(
              data: (list) {
                final query = _search.text.trim().toLowerCase();
                final filtered =
                    list
                        .where((c) => c.name.toLowerCase().contains(query))
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _ClassList(
                        items: filtered,
                        selectedId: _selectedId,
                        searchController: _search,
                        onSearchChanged: () => setState(() {}),
                        onSelect: (doc) => _load(doc, isNew: false),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    Expanded(
                      child:
                          _selectedId == null
                              ? Center(
                                child: Text(
                                  'Sélectionne une classe, ou crées-en une '
                                  'nouvelle',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                              : _buildForm(context),
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

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    final subclassNames =
        ref
            .watch(allSubclassesProvider)
            .value
            ?.where((sub) => sub.parentClassId == _selectedId)
            .map((sub) => sub.name)
            .join(', ') ??
        '';
    final progressionRoute =
        Uri(
          path: AppRoutes.adminLevelProgression,
          queryParameters: {'classId': _selectedId},
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
                  key: const Key('class-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom de la classe',
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
                  : adminSourceSubtitle(_source, 'Classe créée'),
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
                  label: 'Dé de vie',
                  value: _hitDie,
                  items: AdminClassDoc.hitDice,
                  labelOf: (d) => d,
                  onChanged: (d) => setState(() => _hitDie = d),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Caractéristique principale',
                  value: _primaryAbility,
                  items: AdminClassDoc.abilities,
                  labelOf: (a) => a,
                  onChanged: (a) => setState(() => _primaryAbility = a),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledField(
                  label: 'Jets de sauvegarde maîtrisés',
                  controller: _savingThrows,
                  hint: 'ex. Intelligence, Dextérité',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminLabeledField(
            label: 'Compétences (choix parmi)',
            controller: _skills,
            hint: 'ex. 2 parmi : Arcanes, Histoire, Investigation',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AdminLabeledField(
                  key: const Key('class-resource-field'),
                  label: 'Ressource principale',
                  controller: _resource,
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Récupération',
                  value: _recovery,
                  items: AdminClassDoc.recoveries,
                  labelOf: (r) => r,
                  onChanged: (r) => setState(() => _recovery = r),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdminLabeledDropdown<bool>(
                        key: const Key('class-caster-dropdown'),
                        label: 'Lanceur de sorts',
                        value: _spellcaster,
                        items: const [true, false],
                        labelOf: (b) => b ? 'Oui' : 'Non',
                        onChanged: (b) => setState(() => _spellcaster = b),
                      ),
                    ),
                    gap,
                    Expanded(
                      child:
                          _spellcaster
                              ? AdminLabeledDropdown<String>(
                                label: 'Caractéristique d\'incantation',
                                value: _spellcastingAbility,
                                items: AdminClassDoc.abilities,
                                labelOf: (a) => a,
                                onChanged:
                                    (a) => setState(
                                      () => _spellcastingAbility = a,
                                    ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
                if (_spellcaster)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Utilisée automatiquement par le compendium de sorts '
                      'pour chaque personnage de cette classe : DD de '
                      'sauvegarde = 8 + Bonus de Maîtrise + mod. '
                      '$_spellcastingAbility · Bonus d\'attaque de sort = '
                      'Bonus de Maîtrise + mod. $_spellcastingAbility.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Sous-classes',
              isDense: true,
              enabled: false,
            ),
            child: Text(
              subclassNames.isEmpty ? "Aucune pour l'instant" : subclassNames,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const AdminLinkCard(
            text:
                'Ajouter, éditer ou importer les sous-classes de cette classe',
            action: 'Sous-classes',
            route: AppRoutes.adminSubclasses,
          ),
          const SizedBox(height: 14),
          AdminLinkCard(
            text:
                'Configurer les aptitudes, ASI/Don et sorts débloqués niveau '
                'par niveau (1 à 20)',
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

class _ClassList extends StatelessWidget {
  const _ClassList({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final List<AdminClassDoc> items;
  final String? selectedId;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<AdminClassDoc> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher une classe',
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
              return AdminListTile(
                name: item.name,
                badge: item.source.shortLabel,
                active: active,
                onTap: () => onSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
