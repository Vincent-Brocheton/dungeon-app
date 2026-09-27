import 'package:flutter/material.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_monster_doc.dart';
import '../../theme/app_theme.dart';
import 'admin_form_fields.dart';

/// Champs de bloc de stats partagés par les éditeurs de monstres et de PNJ.

const _abilityShort = ['For', 'Dex', 'Con', 'Int', 'Sag', 'Cha'];

String _signed(int value) => value >= 0 ? '+$value' : '$value';

/// Les 6 caractéristiques (For → Cha), modificateur recalculé à la saisie.
/// Chaque colonne porte la clé `<keyPrefix>-ability-<Caractéristique>`.
class AdminAbilityScores extends StatefulWidget {
  const AdminAbilityScores({
    super.key,
    required this.controllers,
    required this.keyPrefix,
  });

  /// 6 contrôleurs, dans l'ordre For, Dex, Con, Int, Sag, Cha.
  final List<TextEditingController> controllers;
  final String keyPrefix;

  /// Valeur saisie, 10 si vide ou invalide.
  static int scoreOf(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 10;

  @override
  State<AdminAbilityScores> createState() => _AdminAbilityScoresState();
}

class _AdminAbilityScoresState extends State<AdminAbilityScores> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.textMuted,
    );
    return AdminPanel(
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
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    key: Key(
                      '${widget.keyPrefix}-ability-'
                      '${AdminClassDoc.abilities[i]}',
                    ),
                    children: [
                      Text(_abilityShort[i], style: label),
                      const SizedBox(height: 4),
                      TextField(
                        controller: widget.controllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _signed(
                          abilityModifier(
                            AdminAbilityScores.scoreOf(widget.controllers[i]),
                          ),
                        ),
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
    );
  }
}

/// Entrée en cours d'édition ; `uid` identifie ses champs même quand une
/// entrée précédente est retirée.
class EntryDraft {
  EntryDraft(MonsterEntry entry)
    : uid = _nextUid++,
      name = entry.name,
      text = entry.text,
      roll = entry.roll,
      saveAbility = entry.saveAbility,
      dc = entry.dc;

  static var _nextUid = 0;

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

/// Bloc d'entrées nommées ajoutables/retirables (aptitudes, actions…),
/// modifiant directement [entries]. Champs clés `<section>-name-<i>`,
/// `<section>-text-<i>` et, avec [withResolution], `<section>-roll-<i>`.
class AdminEntriesPanel extends StatefulWidget {
  const AdminEntriesPanel({
    super.key,
    required this.section,
    required this.title,
    required this.addLabel,
    required this.entries,
    this.withResolution = false,
  });

  final String section;
  final String title;
  final String addLabel;
  final List<EntryDraft> entries;

  /// Affiche la résolution automatique (jet imposé, caractéristique, DD).
  final bool withResolution;

  @override
  State<AdminEntriesPanel> createState() => _AdminEntriesPanelState();
}

class _AdminEntriesPanelState extends State<AdminEntriesPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    () => setState(
                      () => entries.add(
                        EntryDraft(const MonsterEntry(name: '', text: '')),
                      ),
                    ),
                child: Text(widget.addLabel),
              ),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            KeyedSubtree(
              key: ValueKey('entry-${entries[i].uid}'),
              child: _buildEntry(i),
            ),
        ],
      ),
    );
  }

  Widget _buildEntry(int i) {
    final entry = widget.entries[i];
    final section = widget.section;
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
                onPressed: () => setState(() => widget.entries.removeAt(i)),
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
          if (widget.withResolution) ...[
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
