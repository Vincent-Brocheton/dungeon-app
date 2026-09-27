import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_subclass_doc.dart';
import '../../theme/app_theme.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Table de progression niveaux 1 à 20 d'une classe : aptitudes de classe,
/// aptitudes de la sous-classe affichée, ASI/Don et colonnes de ressource.
/// Reprend `LevelProgressionEditor.dc.html` — sans sidebar. Tout est stocké
/// sur les documents existants (`content/classes`, `content/subclasses`) :
/// pas de collection dédiée. Changer de classe abandonne les modifications
/// non enregistrées.
class AdminLevelProgressionEditorScreen extends ConsumerStatefulWidget {
  const AdminLevelProgressionEditorScreen({
    super.key,
    this.initialClassId,
    this.initialSubclassId,
  });

  final String? initialClassId;
  final String? initialSubclassId;

  @override
  ConsumerState<AdminLevelProgressionEditorScreen> createState() =>
      _AdminLevelProgressionEditorScreenState();
}

class _AdminLevelProgressionEditorScreenState
    extends ConsumerState<AdminLevelProgressionEditorScreen> {
  String? _classId;
  String? _subclassId;
  String? _loadedClassId;
  var _saving = false;

  var _classFeatures = <String>[];
  var _asi = <int>{};
  var _columnIds = <int>[];
  var _columnNames = <String>[];
  var _columnValues = <List<String>>[];
  var _nextColumnId = 0;

  /// Aptitudes des sous-classes affichées depuis le chargement de la classe.
  final _subFeatures = <String, List<String>>{};

  void _loadClass(AdminClassDoc doc, List<AdminSubclassDoc> subclasses) {
    _loadedClassId = doc.id;
    _classFeatures = levelTexts(doc.levelFeatures);
    _asi = doc.asiLevels.toSet();
    _columnIds = [for (final _ in doc.resourceColumns) _nextColumnId++];
    _columnNames = [for (final c in doc.resourceColumns) c.name];
    _columnValues = [
      for (final c in doc.resourceColumns) [...c.values],
    ];
    _subFeatures.clear();
    if (_subclassId != null &&
        !subclasses.any(
          (s) => s.id == _subclassId && s.parentClassId == doc.id,
        )) {
      _subclassId = null;
    }
  }

  Future<void> _save(
    AdminClassDoc classDoc,
    List<AdminSubclassDoc> subclasses,
  ) async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await ref
          .read(adminClassRepositoryProvider)
          .upsert(
            classDoc.copyWith(
              levelFeatures: [..._classFeatures],
              asiLevels: _asi.toList()..sort(),
              resourceColumns: [
                for (var i = 0; i < _columnIds.length; i++)
                  ResourceColumn(
                    name: _columnNames[i],
                    values: [..._columnValues[i]],
                  ),
              ],
              updatedAt: now,
            ),
          );
      for (final entry in _subFeatures.entries) {
        final sub = subclasses.where((s) => s.id == entry.key).firstOrNull;
        if (sub == null) continue;
        await ref
            .read(adminSubclassRepositoryProvider)
            .upsert(
              sub.copyWith(levelFeatures: [...entry.value], updatedAt: now),
            );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(allClassesProvider);
    final subclasses = ref.watch(allSubclassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Table de progression')),
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
    if (classList.isEmpty) {
      return Center(
        child: Text(
          'Crée d\'abord une classe pour configurer sa progression.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
      );
    }
    final sortedClasses = [...classList]
      ..sort((a, b) => a.name.compareTo(b.name));

    // Premier affichage : classe (et sous-classe) passées en paramètre, sinon
    // la première classe par ordre alphabétique.
    if (_classId == null) {
      _classId =
          classList.any((c) => c.id == widget.initialClassId)
              ? widget.initialClassId
              : sortedClasses.first.id;
      _subclassId = widget.initialSubclassId;
    }
    final classDoc =
        classList.where((c) => c.id == _classId).firstOrNull ??
        sortedClasses.first;
    if (_loadedClassId != classDoc.id) _loadClass(classDoc, subclassList);

    final classSubclasses =
        subclassList.where((s) => s.parentClassId == classDoc.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final subclass =
        classSubclasses.where((s) => s.id == _subclassId).firstOrNull;
    final subFeatures =
        subclass == null
            ? null
            : _subFeatures.putIfAbsent(
              subclass.id,
              () => levelTexts(subclass.levelFeatures),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Niveaux 1 à 20 — aptitudes de classe fusionnées avec '
                      'celles de la sous-classe sélectionnée',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        _saving ? null : () => _save(classDoc, subclassList),
                    child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 220,
                    child: AdminLabeledDropdown<String>(
                      key: ValueKey('class-${classDoc.id}'),
                      label: 'Classe',
                      value: classDoc.id,
                      items: [for (final c in sortedClasses) c.id],
                      labelOf:
                          (id) => classList.firstWhere((c) => c.id == id).name,
                      onChanged:
                          (id) => setState(() {
                            _classId = id;
                            _subclassId = null;
                          }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: AdminLabeledDropdown<String?>(
                      key: const Key('progression-subclass-dropdown'),
                      label: 'Sous-classe affichée',
                      value: subclass?.id,
                      items: [null, for (final s in classSubclasses) s.id],
                      labelOf:
                          (id) =>
                              id == null
                                  ? 'Classe seule'
                                  : classSubclasses
                                      .firstWhere((s) => s.id == id)
                                      .name,
                      onChanged: (id) => setState(() => _subclassId = id),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed:
                        () => setState(() {
                          _columnIds.add(_nextColumnId++);
                          _columnNames.add('');
                          _columnValues.add(List.filled(20, ''));
                        }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Colonne de ressource'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(classDoc.id),
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Column(
              children: [
                _headerRow(theme, subclass),
                for (var level = 1; level <= 20; level++)
                  _levelRow(theme, level, subclass, subFeatures),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(ThemeData theme, AdminSubclassDoc? subclass) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text('NIV.', style: style)),
          SizedBox(width: 90, child: Text('BONUS MAÎTRISE', style: style)),
          Expanded(child: Text('APTITUDES DE CLASSE', style: style)),
          if (subclass != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'APTITUDES — ${subclass.name.toUpperCase()}',
                style: style,
              ),
            ),
          ],
          SizedBox(
            width: 70,
            child: Text('ASI / DON', style: style, textAlign: TextAlign.center),
          ),
          for (var i = 0; i < _columnIds.length; i++)
            SizedBox(
              width: 150,
              child: Row(
                children: [
                  Expanded(
                    child: _Cell(
                      key: Key('resource-name-$i'),
                      cellKey: 'name-${_columnIds[i]}',
                      initialValue: _columnNames[i],
                      hint: 'Ressource',
                      onChanged: (v) => _columnNames[i] = v,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirer la colonne',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 14),
                    onPressed:
                        () => setState(() {
                          _columnIds.removeAt(i);
                          _columnNames.removeAt(i);
                          _columnValues.removeAt(i);
                        }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelRow(
    ThemeData theme,
    int level,
    AdminSubclassDoc? subclass,
    List<String>? subFeatures,
  ) {
    final i = level - 1;
    final milestone = subFeatures != null && subFeatures[i].trim().isNotEmpty;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: milestone ? AppTheme.surface : null,
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '$level',
              style:
                  milestone
                      ? theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                      : muted,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text('+${proficiencyBonus(level)}', style: muted),
          ),
          Expanded(
            child: _Cell(
              key: Key('class-feature-$level'),
              cellKey: 'class-$level',
              initialValue: _classFeatures[i],
              onChanged: (v) => _classFeatures[i] = v,
            ),
          ),
          if (subclass != null && subFeatures != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _Cell(
                key: Key('subclass-feature-$level'),
                cellKey: 'sub-${subclass.id}-$level',
                initialValue: subFeatures[i],
                // Rafraîchit la mise en avant de la ligne quand elle passe
                // de vide à remplie (ou l'inverse).
                onChanged: (v) {
                  final wasEmpty = subFeatures[i].trim().isEmpty;
                  subFeatures[i] = v;
                  if (wasEmpty != v.trim().isEmpty) setState(() {});
                },
              ),
            ),
          ],
          SizedBox(
            width: 70,
            child: Checkbox(
              key: Key('asi-$level'),
              value: _asi.contains(level),
              onChanged:
                  (checked) => setState(
                    () =>
                        checked == true ? _asi.add(level) : _asi.remove(level),
                  ),
            ),
          ),
          for (var c = 0; c < _columnIds.length; c++)
            SizedBox(
              width: 150,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _Cell(
                  key: Key('resource-$c-$level'),
                  cellKey: 'col-${_columnIds[c]}-$level',
                  initialValue: _columnValues[c][i],
                  onChanged: (v) => _columnValues[c][i] = v,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cellule éditable de la table. `cellKey` identifie la donnée (colonne,
/// sous-classe, niveau) : le champ est recréé — et relit `initialValue` —
/// quand la donnée affichée à cette place change.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.cellKey,
    required this.initialValue,
    required this.onChanged,
    this.hint = '—',
  });

  final String cellKey;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey(cellKey),
    initialValue: initialValue,
    onChanged: onChanged,
    style: Theme.of(context).textTheme.bodySmall,
    decoration: InputDecoration(isDense: true, hintText: hint),
  );
}
