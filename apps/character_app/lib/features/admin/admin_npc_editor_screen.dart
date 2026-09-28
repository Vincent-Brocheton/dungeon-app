import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_monster_doc.dart';
import '../../data/admin_npc_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../theme/app_theme.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';
import 'admin_stat_block_fields.dart';

/// Éditeur de PNJ (fiches de scène du MJ) : liste groupée par type à
/// gauche, fiche éditable à droite, « Dupliquer » pour partir d'une fiche
/// existante. Reprend `NPCEditor.dc.html` — sans sidebar (accès par
/// l'icône « PNJ » du tableau de bord). Même résolution automatique des
/// actions que les monstres, stockée pour le futur suivi de combat.
class AdminNpcEditorScreen extends ConsumerStatefulWidget {
  const AdminNpcEditorScreen({super.key});

  @override
  ConsumerState<AdminNpcEditorScreen> createState() =>
      _AdminNpcEditorScreenState();
}

class _AdminNpcEditorScreenState extends ConsumerState<AdminNpcEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;
  String? _typeFilter;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _texts = {
    for (final key in AdminNpcDoc.textFields) key: TextEditingController(),
  };
  final _scores = [for (var i = 0; i < 6; i++) TextEditingController()];
  var _source = SpeciesSource.homebrew;
  var _speciesId = '';
  var _type = 'Humanoïde';
  var _size = 'Moyenne';
  var _alignment = 'Neutre';
  var _cr = '1/4';
  var _actions = <EntryDraft>[];

  @override
  void dispose() {
    for (final controller in [_search, _name, ..._texts.values, ..._scores]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminNpcDoc doc, {required bool isNew}) {
    final map = doc.toMap();
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = isNew;
      _name.text = doc.name;
      for (final key in AdminNpcDoc.textFields) {
        _texts[key]!.text = map[key]! as String;
      }
      for (var i = 0; i < 6; i++) {
        _scores[i].text = '${doc.abilityScores[i]}';
      }
      _source = doc.source;
      _speciesId = doc.speciesId;
      _type = doc.type;
      _size = doc.size;
      _alignment = doc.alignment;
      _cr = doc.cr;
      _actions = [for (final e in doc.actions) EntryDraft(e)];
    });
  }

  /// Fiche telle que saisie, sous l'identifiant [id].
  AdminNpcDoc _formDoc(String id, {required String name}) =>
      AdminNpcDoc.fromMap(id, {
        'name': name,
        'source': _source.name,
        'speciesId': _speciesId,
        'type': _type,
        'size': _size,
        'alignment': _alignment,
        'cr': _cr,
        for (final key in AdminNpcDoc.textFields) key: _texts[key]!.text.trim(),
        'abilityScores': [
          for (final s in _scores) AdminAbilityScores.scoreOf(s),
        ],
        'actions': [for (final e in _actions) e.toEntry().toMap()],
        'updatedAt': DateTime.now(),
      });

  void _createDraft() {
    final id = ref.read(adminNpcRepositoryProvider).newId();
    _load(
      AdminNpcDoc(id: id, name: '', updatedAt: DateTime.now()),
      isNew: true,
    );
  }

  void _duplicate() {
    final id = ref.read(adminNpcRepositoryProvider).newId();
    _load(_formDoc(id, name: '${_name.text.trim()} (copie)'), isNew: true);
  }

  Future<void> _save() async {
    final id = _selectedId;
    final name = _name.text.trim();
    if (id == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminNpcRepositoryProvider)
          .upsert(_formDoc(id, name: name));
      if (mounted) setState(() => _isNewDraft = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final npcs = ref.watch(allNpcsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PNJ'),
        actions: [
          IconButton(
            tooltip: 'Dupliquer',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _selectedId == null ? null : _duplicate,
          ),
          IconButton(
            tooltip: 'Nouveau PNJ',
            icon: const Icon(Icons.add),
            onPressed: _createDraft,
          ),
        ],
      ),
      body: npcs.when(
        data:
            (list) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 320, child: _buildList(list)),
                const VerticalDivider(width: 1, color: AppTheme.border),
                Expanded(
                  child:
                      _selectedId == null
                          ? Center(
                            child: Text(
                              'Sélectionne un PNJ, ou crées-en un nouveau',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textMuted),
                            ),
                          )
                          : _buildForm(),
                ),
              ],
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }

  Widget _buildList(List<AdminNpcDoc> npcs) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final query = _search.text.trim().toLowerCase();
    final grouped = <String, List<AdminNpcDoc>>{};
    for (final n in [...npcs]..sort((a, b) => a.name.compareTo(b.name))) {
      if (_typeFilter != null && n.type != _typeFilter) continue;
      if (!n.name.toLowerCase().contains(query)) continue;
      (grouped[n.type] ??= []).add(n);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher un PNJ',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: DropdownButtonFormField<String?>(
            initialValue: _typeFilter,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les types'),
              ),
              for (final t in AdminMonsterDoc.types)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              for (final type in AdminMonsterDoc.types)
                if (grouped[type] != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Text(type.toUpperCase(), style: muted),
                  ),
                  for (final item in grouped[type]!) ...[
                    AdminListTile(
                      name: item.name,
                      badge: item.source.shortLabel,
                      subtitle: item.listLabel,
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
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    const vgap = SizedBox(height: 14);
    final species = ref.watch(allSpeciesProvider).value ?? const [];

    Widget text(String key, String label, {String? hint, Key? fieldKey}) =>
        AdminLabeledField(
          key: fieldKey,
          label: label,
          controller: _texts[key]!,
          hint: hint,
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
                  key: const Key('npc-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom du PNJ',
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
                  : _formDoc('', name: '').statLine,
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
                  child: text(
                    'sourcebook',
                    'Ouvrage / édition',
                    hint: 'ex. Guide de Xanathar',
                  ),
                ),
              ],
            ),
          ),
          vgap,
          Row(
            children: [
              Expanded(
                child: text(
                  'role',
                  'Rôle dans la scène',
                  hint: 'ex. Chef gobelin, Boss de scène',
                  fieldKey: const Key('npc-role-field'),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  key: const Key('npc-species-dropdown'),
                  label: 'Espèce liée (optionnel)',
                  value: _speciesId,
                  items: ['', for (final s in species) s.id],
                  labelOf:
                      (id) =>
                          id.isEmpty
                              ? 'Aucune — créature du bestiaire'
                              : species
                                      .where((s) => s.id == id)
                                      .firstOrNull
                                      ?.name ??
                                  id,
                  onChanged: (id) => setState(() => _speciesId = id),
                ),
              ),
            ],
          ),
          vgap,
          Row(
            children: [
              Expanded(
                child: AdminLabeledDropdown<String>(
                  key: const Key('npc-type-dropdown'),
                  label: 'Type de créature',
                  value: _type,
                  items: AdminMonsterDoc.types,
                  labelOf: (t) => t,
                  onChanged: (t) => setState(() => _type = t),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Taille',
                  value: _size,
                  items: AdminNpcDoc.sizes,
                  labelOf: (s) => s,
                  onChanged: (s) => setState(() => _size = s),
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  label: 'Alignement',
                  value: _alignment,
                  items: AdminMonsterDoc.alignments,
                  labelOf: (a) => a,
                  onChanged: (a) => setState(() => _alignment = a),
                ),
              ),
            ],
          ),
          vgap,
          Row(
            children: [
              Expanded(
                child: AdminLabeledDropdown<String>(
                  key: const Key('npc-cr-dropdown'),
                  label: 'Dangerosité (PX)',
                  value: _cr,
                  items: [
                    for (final (cr, _) in AdminNpcDoc.challengeRatings) cr,
                  ],
                  labelOf: AdminNpcDoc.crLabel,
                  onChanged: (cr) => setState(() => _cr = cr),
                ),
              ),
              gap,
              Expanded(child: text('armorClass', 'Classe d\'armure')),
              gap,
              Expanded(
                child: text(
                  'hitPoints',
                  'Points de vie (formule)',
                  hint: 'ex. 7d8 (31)',
                ),
              ),
              gap,
              Expanded(
                child: text('speed', 'Vitesse', hint: 'ex. 9 m, Vol 18 m'),
              ),
            ],
          ),
          vgap,
          AdminAbilityScores(controllers: _scores, keyPrefix: 'npc'),
          vgap,
          Row(
            children: [
              Expanded(child: text('resistances', 'Résistances')),
              gap,
              Expanded(
                child: text(
                  'immunities',
                  'Immunités (dégâts / états)',
                  hint: 'ex. Poison · Charmé, effrayé',
                ),
              ),
              gap,
              Expanded(child: text('vulnerabilities', 'Vulnérabilités')),
            ],
          ),
          vgap,
          Row(
            children: [
              Expanded(child: text('senses', 'Sens')),
              gap,
              Expanded(child: text('languages', 'Langues')),
            ],
          ),
          vgap,
          AdminEntriesPanel(
            section: 'actions',
            title: 'Actions',
            addLabel: '+ Ajouter une action',
            entries: _actions,
            withResolution: true,
          ),
          vgap,
          AdminLabeledField(
            label: 'Description / tactiques',
            controller: _texts['description']!,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
