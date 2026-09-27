import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_monster_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import 'admin_compendium_tabs.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Blocs d'entrées du bloc de stats : clé dans `toMap`, titre, bouton.
const _sections = [
  ('traits', 'Aptitudes', '+ Ajouter une aptitude'),
  ('actions', 'Actions', '+ Ajouter une action'),
  ('bonusActions', 'Actions bonus', '+ Ajouter'),
  ('reactions', 'Réactions', '+ Ajouter'),
  ('legendaryActions', 'Actions légendaires', '+ Ajouter'),
];

const _abilityShort = ['For', 'Dex', 'Con', 'Int', 'Sag', 'Cha'];

/// Libellés et champs texte de la fiche, dans l'ordre d'affichage des
/// défenses (clés de `AdminMonsterDoc.toMap`).
const _defenseFields = [
  ('savingThrows', 'Jets de sauvegarde', 'ex. Dex +5, Sag +5'),
  ('skills', 'Compétences', 'ex. Perception +4, Discrétion +4'),
  ('damageResistances', 'Résistances (dégâts)', '—'),
  ('damageImmunities', 'Immunités (dégâts)', '—'),
  ('damageVulnerabilities', 'Vulnérabilités (dégâts)', '—'),
  ('conditionImmunities', 'Immunités (états)', '—'),
  ('senses', 'Sens', 'ex. Vision dans le noir 18 m, Perception passive 14'),
  ('languages', 'Langues', '—'),
];

String _signed(int value) => value >= 0 ? '+$value' : '$value';

/// Entrée en cours d'édition ; `uid` identifie ses champs même quand une
/// entrée précédente est retirée.
class _EntryDraft {
  _EntryDraft(this.uid, MonsterEntry entry)
    : name = entry.name,
      text = entry.text,
      roll = entry.roll,
      saveAbility = entry.saveAbility,
      dc = entry.dc;

  final int uid;
  String name;
  String text;
  String roll;
  String saveAbility;
  String dc;

  MonsterEntry toEntry() => MonsterEntry(
    name: name.trim(),
    text: text.trim(),
    roll: roll,
    saveAbility: saveAbility,
    dc: dc.trim(),
  );
}

/// Éditeur de monstres (blocs de stats) : liste groupée par type à gauche,
/// fiche éditable à droite. Reprend `MonstersEditorNoModal.dc.html` — sans
/// sidebar ni import CSV (bouton présent, annonce juste qu'il arrive). La
/// résolution automatique des actions (jet, caractéristique, DD) est
/// stockée pour le futur suivi de combat, pas encore calculée ici.
class AdminMonsterEditorScreen extends ConsumerStatefulWidget {
  const AdminMonsterEditorScreen({super.key});

  @override
  ConsumerState<AdminMonsterEditorScreen> createState() =>
      _AdminMonsterEditorScreenState();
}

class _AdminMonsterEditorScreenState
    extends ConsumerState<AdminMonsterEditorScreen> {
  String? _selectedId;
  var _isNewDraft = false;
  var _saving = false;
  String? _typeFilter;

  final _search = TextEditingController();
  final _name = TextEditingController();
  final _texts = {
    for (final key in AdminMonsterDoc.textFields) key: TextEditingController(),
  };
  final _speeds = [for (var i = 0; i < 5; i++) TextEditingController()];
  final _scores = [for (var i = 0; i < 6; i++) TextEditingController()];
  var _source = SpeciesSource.homebrew;
  var _type = 'Humanoïde';
  var _alignment = 'Neutre';
  final _entries = <String, List<_EntryDraft>>{};
  var _nextUid = 0;

  @override
  void dispose() {
    for (final controller in [
      _search,
      _name,
      ..._texts.values,
      ..._speeds,
      ..._scores,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminMonsterDoc doc, {required bool isNew}) {
    final map = doc.toMap();
    setState(() {
      _selectedId = doc.id;
      _isNewDraft = isNew;
      _name.text = doc.name;
      for (final key in AdminMonsterDoc.textFields) {
        _texts[key]!.text = map[key]! as String;
      }
      for (var i = 0; i < 5; i++) {
        _speeds[i].text = doc.speeds[i];
      }
      for (var i = 0; i < 6; i++) {
        _scores[i].text = '${doc.abilityScores[i]}';
      }
      _source = doc.source;
      _type = doc.type;
      _alignment = doc.alignment;
      for (final (key, _, _) in _sections) {
        _entries[key] = [
          for (final e in (map[key]! as List).map(
            (m) => MonsterEntry.fromMap(m as Map),
          ))
            _EntryDraft(_nextUid++, e),
        ];
      }
    });
  }

  void _createDraft() {
    final id = ref.read(adminMonsterRepositoryProvider).newId();
    _load(
      AdminMonsterDoc(id: id, name: '', updatedAt: DateTime.now()),
      isNew: true,
    );
  }

  int _score(int i) => int.tryParse(_scores[i].text.trim()) ?? 10;

  Future<void> _save() async {
    final id = _selectedId;
    if (id == null || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminMonsterRepositoryProvider)
          .upsert(
            AdminMonsterDoc.fromMap(id, {
              'name': _name.text.trim(),
              'source': _source.name,
              'type': _type,
              'alignment': _alignment,
              for (final key in AdminMonsterDoc.textFields)
                key: _texts[key]!.text.trim(),
              'speeds': [for (final s in _speeds) s.text.trim()],
              'abilityScores': [for (var i = 0; i < 6; i++) _score(i)],
              for (final (key, _, _) in _sections)
                key: [for (final e in _entries[key]!) e.toEntry().toMap()],
              'updatedAt': DateTime.now(),
            }),
          );
      if (mounted) setState(() => _isNewDraft = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monsters = ref.watch(allMonstersProvider);

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
          const AdminCompendiumTabs(current: AppRoutes.adminMonsters),
          Expanded(
            child: monsters.when(
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
                                    'Sélectionne un monstre, ou crées-en un '
                                    'nouveau',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppTheme.textMuted),
                                  ),
                                )
                                : _buildForm(),
                      ),
                    ],
                  ),
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

  Widget _buildList(List<AdminMonsterDoc> monsters) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final query = _search.text.trim().toLowerCase();
    // Groupes : un par type (ordre de AdminMonsterDoc.types), le homebrew à
    // part, en dernier, quel que soit son type.
    final grouped = <String, List<AdminMonsterDoc>>{};
    for (final m in [...monsters]..sort((a, b) => a.name.compareTo(b.name))) {
      if (_typeFilter != null && m.type != _typeFilter) continue;
      if (!m.name.toLowerCase().contains(query)) continue;
      final group = m.source == SpeciesSource.homebrew ? 'Homebrew' : m.type;
      (grouped[group] ??= []).add(m);
    }
    final order = [...AdminMonsterDoc.types, 'Homebrew'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chercher un monstre',
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
              for (final group in order)
                if (grouped[group] != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Text(group.toUpperCase(), style: muted),
                  ),
                  for (final item in grouped[group]!) ...[
                    _MonsterTile(
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
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    const vgap = SizedBox(height: 14);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final preview = AdminMonsterDoc(
      id: '',
      name: '',
      updatedAt: DateTime(0),
      type: _type,
      subtype: _texts['subtype']!.text,
      size: _texts['size']!.text,
      alignment: _alignment,
      cr: _texts['cr']!.text,
    );

    Widget text(String key, String labelText, {String? hint, Key? fieldKey}) =>
        AdminLabeledField(
          key: fieldKey,
          label: labelText,
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
                  key: const Key('monster-name-field'),
                  controller: _name,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'Nom du monstre',
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
                  : preview.statLine,
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
          text('summary', 'Résumé'),
          vgap,
          Row(
            children: [
              Expanded(
                child: text(
                  'subtype',
                  'Sous-type / variante (optionnel)',
                  hint: 'ex. Lycanthrope, Gobelinoïde, Chromatique',
                ),
              ),
              gap,
              Expanded(
                child: AdminLabeledDropdown<String>(
                  key: const Key('monster-type-dropdown'),
                  label: 'Type de créature',
                  value: _type,
                  items: AdminMonsterDoc.types,
                  labelOf: (t) => t,
                  onChanged: (t) => setState(() => _type = t),
                ),
              ),
            ],
          ),
          vgap,
          Row(
            children: [
              Expanded(child: text('size', 'Taille')),
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
                child: text(
                  'cr',
                  'Dangerosité (FP)',
                  hint: 'ex. 3 (700 PX)',
                  fieldKey: const Key('monster-cr-field'),
                ),
              ),
              gap,
              Expanded(child: text('armorClass', 'Classe d\'armure')),
              gap,
              Expanded(
                child: text(
                  'hitPoints',
                  'Points de vie (formule)',
                  hint: 'ex. 71 (11d8 + 22)',
                ),
              ),
            ],
          ),
          vgap,
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VITESSES', style: label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) gap,
                      Expanded(
                        child: AdminLabeledField(
                          label: AdminMonsterDoc.speedLabels[i],
                          controller: _speeds[i],
                          hint: '—',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          vgap,
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARACTÉRISTIQUES (MODIFICATEURS CALCULÉS AUTOMATIQUEMENT)',
                  style: label,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) gap,
                      Expanded(
                        child: Column(
                          key: Key(
                            'monster-ability-${AdminClassDoc.abilities[i]}',
                          ),
                          children: [
                            Text(_abilityShort[i], style: label),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _scores[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(isDense: true),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _signed(abilityModifier(_score(i))),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          vgap,
          for (var i = 0; i < _defenseFields.length; i += 2) ...[
            Row(
              children: [
                for (final (key, labelText, hint) in _defenseFields.sublist(
                  i,
                  i + 2,
                )) ...[
                  if (key != _defenseFields[i].$1) gap,
                  Expanded(child: text(key, labelText, hint: hint)),
                ],
              ],
            ),
            vgap,
          ],
          for (final (key, title, addLabel) in _sections) ...[
            _buildSection(key, title, addLabel),
            vgap,
          ],
          AdminLabeledField(
            label: 'Description longue',
            controller: _texts['description']!,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String key, String title, String addLabel) {
    final theme = Theme.of(context);
    final entries = _entries[key]!;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    () => setState(
                      () => entries.add(
                        _EntryDraft(
                          _nextUid++,
                          const MonsterEntry(name: '', text: ''),
                        ),
                      ),
                    ),
                child: Text(addLabel),
              ),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            KeyedSubtree(
              key: ValueKey('entry-${entries[i].uid}'),
              child: _buildEntry(key, i, entries),
            ),
        ],
      ),
    );
  }

  Widget _buildEntry(String section, int i, List<_EntryDraft> entries) {
    final entry = entries[i];
    const gap = SizedBox(width: 12);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('$section-name-$i'),
                  initialValue: entry.name,
                  onChanged: (v) => entry.name = v,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Nom',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => entries.removeAt(i)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: Key('$section-text-$i'),
            initialValue: entry.text,
            onChanged: (v) => entry.text = v,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Description',
            ),
          ),
          // Résolution automatique : seulement pour les actions.
          if (section == 'actions') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AdminLabeledDropdown<String>(
                    key: Key('$section-roll-$i'),
                    label: 'Jet imposé',
                    value: entry.roll,
                    items: MonsterEntry.rolls,
                    labelOf: (r) => r,
                    onChanged: (r) => setState(() => entry.roll = r),
                  ),
                ),
                if (entry.roll == 'Sauvegarde') ...[
                  gap,
                  Expanded(
                    child: AdminLabeledDropdown<String>(
                      label: 'Caractéristique de la cible',
                      value: entry.saveAbility,
                      items: AdminClassDoc.abilities,
                      labelOf: (a) => a,
                      onChanged: (a) => setState(() => entry.saveAbility = a),
                    ),
                  ),
                  gap,
                  Expanded(
                    child: TextFormField(
                      initialValue: entry.dc,
                      onChanged: (v) => entry.dc = v,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'DD (vide = calculé)',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AdminMonsterDoc item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
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
                  child: Text(item.source.shortLabel, style: muted),
                ),
              ],
            ),
            Text(item.listLabel, style: muted),
          ],
        ),
      ),
    );
  }
}
