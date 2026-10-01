part of 'character_sheet_screen.dart';

/// Incantation : caractéristique, bonus d'attaque et DD de sauvegarde des
/// sorts, partagée par les onglets Actions et Sorts ; [footer] en dessous.
class _SpellcastingBlock extends StatelessWidget {
  const _SpellcastingBlock({
    required this.cls,
    required this.ability,
    required this.scores,
    required this.proficiency,
    this.footer,
  });

  final AdminClassDoc cls;
  final Ability ability;
  final AbilityScores scores;
  final int proficiency;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mod = abilityModifier(scores[ability]);
    Widget value(String label, String v) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          Text(
            v,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return _Section(
      title: 'Incantation (calculée automatiquement)',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                value('Caract.', cls.spellcastingAbility),
                value('Attaque', _signed(mod + proficiency)),
                value('DD sauv.', '${8 + mod + proficiency}'),
              ],
            ),
            if (footer case final f?) ...[const Divider(height: 20), f],
          ],
        ),
      ),
    );
  }
}

int _bySpellLevel(AdminSpellDoc a, AdminSpellDoc b) =>
    a.level != b.level ? a.level - b.level : a.name.compareTo(b.name);

/// Sorts de la classe du personnage ; tous les sorts si la classe est
/// inconnue.
List<AdminSpellDoc> _classSpells(List<AdminSpellDoc> all, AdminClassDoc? cls) {
  final name = cls?.name.toLowerCase();
  return [
    for (final s in all)
      if (name == null || s.classes.toLowerCase().contains(name)) s,
  ]..sort(_bySpellLevel);
}

String _spellSubtitle(AdminSpellDoc s) => [
  s.school,
  if (s.duration.toLowerCase().contains('concentration')) 'concentration',
].join(' · ');

/// [doc] avec [spellId] ajouté à ses sorts, ou retiré s'il y était.
CharacterDoc _togglePrepared(CharacterDoc doc, String spellId) => doc.copyWith(
  spellIds:
      doc.spellIds.contains(spellId)
          ? [
            for (final id in doc.spellIds)
              if (id != spellId) id,
          ]
          : [...doc.spellIds, spellId],
);

/// Emplacements dépensés, un par niveau de [slots], [index] mis à [value].
List<int> _withUsed(CharacterDoc doc, List<int> slots, int index, int value) =>
    [
      for (var i = 0; i < slots.length; i++)
        i == index
            ? value.clamp(0, slots[i])
            : (i < doc.slotsUsed.length ? doc.slotsUsed[i] : 0),
    ];

/// Onglet Sorts (`CharSheetSpells.dc.html`) : incantation, emplacements à
/// dépenser ou récupérer d'un toucher, sorts choisis par niveau. Les sorts
/// de domaine et la limite de sorts préparés viendront avec leurs données.
class _SpellsTab extends ConsumerWidget {
  const _SpellsTab({
    required this.doc,
    required this.cls,
    required this.proficiency,
  });

  final CharacterDoc doc;
  final AdminClassDoc? cls;
  final int proficiency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final cls = this.cls;
    final ability =
        cls != null && cls.spellcaster
            ? abilityFromLabel(cls.spellcastingAbility)
            : null;
    if (cls == null || ability == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _card,
        child: Text('Ta classe ne lance pas de sorts.', style: muted),
      );
    }
    final slots = fullCasterSlots(doc.level);
    final byId = {
      for (final s in ref.watch(allSpellsProvider).value ?? <AdminSpellDoc>[])
        s.id: s,
    };
    final chosen = [
      for (final id in doc.spellIds)
        if (byId[id] case final s?) s,
    ]..sort(_bySpellLevel);
    final levels = {for (final s in chosen) s.level}.toList()..sort();
    final controller = ref.read(charactersControllerProvider);
    int usedAt(int i) => i < doc.slotsUsed.length ? doc.slotsUsed[i] : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpellcastingBlock(
          cls: cls,
          ability: ability,
          scores: doc.scores,
          proficiency: proficiency,
          footer: Row(
            children: [
              Expanded(
                child: Text(
                  '${chosen.length} sort${chosen.length > 1 ? 's' : ''} '
                  'préparé${chosen.length > 1 ? 's' : ''}',
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.spellbook(doc.id)),
                child: const Text('Voir le grimoire →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Emplacements de sorts',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: _card,
            child: Column(
              children: [
                for (final (i, total) in slots.indexed)
                  Row(
                    children: [
                      Expanded(child: Text('Niveau ${i + 1}')),
                      for (var k = 0; k < total; k++)
                        if (k < total - usedAt(i))
                          IconButton(
                            tooltip:
                                'Dépenser un emplacement de niveau ${i + 1}',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.circle,
                              size: 16,
                              color: AppTheme.accent,
                            ),
                            onPressed:
                                () => controller.save(
                                  doc.copyWith(
                                    slotsUsed: _withUsed(
                                      doc,
                                      slots,
                                      i,
                                      usedAt(i) + 1,
                                    ),
                                  ),
                                ),
                          )
                        else
                          IconButton(
                            tooltip:
                                'Récupérer un emplacement de niveau ${i + 1}',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.circle_outlined,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            onPressed:
                                () => controller.save(
                                  doc.copyWith(
                                    slotsUsed: _withUsed(
                                      doc,
                                      slots,
                                      i,
                                      usedAt(i) - 1,
                                    ),
                                  ),
                                ),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (chosen.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _card,
            child: Text(
              'Aucun sort préparé : choisis-les dans le grimoire.',
              style: muted,
            ),
          ),
        ],
        for (final level in levels) ...[
          const SizedBox(height: 16),
          _Section(
            title: level == 0 ? 'Sorts mineurs (à volonté)' : 'Niveau $level',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in chosen.where((s) => s.level == level))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap:
                          () => _showSpellDetail(
                            context,
                            spell: s,
                            doc: doc,
                            slots: slots,
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: _card,
                        child: Row(
                          children: [
                            Expanded(child: Text(s.name)),
                            Text(s.school, style: muted),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Détail d'un sort (`CharSheetSpellDetail.dc.html`) : caractéristiques,
/// description, préparation, et lancement qui dépense le plus bas
/// emplacement disponible.
Future<void> _showSpellDetail(
  BuildContext context, {
  required AdminSpellDoc spell,
  required CharacterDoc doc,
  required List<int> slots,
}) => showDialog<void>(
  context: context,
  builder:
      (context) => Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final muted = theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          );
          final controller = ref.read(charactersControllerProvider);
          final prepared = doc.spellIds.contains(spell.id);
          final slot =
              spell.level == 0
                  ? null
                  : slotToSpend(slots, doc.slotsUsed, spell.level);
          final details = [
            ("Temps d'incantation", spell.castingTime),
            ('Portée', spell.range),
            ('Composantes', spell.components),
            ('Durée', spell.duration),
          ].where((d) => d.$2.trim().isNotEmpty);
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(spell.name, style: theme.textTheme.titleLarge),
                    Text(
                      [
                        spell.level == 0
                            ? 'Sort mineur'
                            : 'Niveau ${spell.level}',
                        _spellSubtitle(spell),
                      ].join(' · '),
                      style: muted,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(prepared ? 'Préparé' : 'Non préparé'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            controller.save(_togglePrepared(doc, spell.id));
                            Navigator.pop(context);
                          },
                          child: Text(prepared ? 'Dépréparer' : 'Préparer'),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Caractéristiques',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _card,
                          child: Column(
                            children: [
                              for (final (label, v) in details)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Text(label)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          v,
                                          textAlign: TextAlign.end,
                                          style: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (spell.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Description',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _card,
                          child: Text(spell.description.trim(), style: muted),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (spell.level > 0)
                      FilledButton(
                        onPressed:
                            slot == null
                                ? null
                                : () {
                                  final used =
                                      slot - 1 < doc.slotsUsed.length
                                          ? doc.slotsUsed[slot - 1]
                                          : 0;
                                  controller.save(
                                    doc.copyWith(
                                      slotsUsed: _withUsed(
                                        doc,
                                        slots,
                                        slot - 1,
                                        used + 1,
                                      ),
                                    ),
                                  );
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  Navigator.pop(context);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${spell.name} lancé · emplacement '
                                        'de niveau $slot dépensé',
                                      ),
                                    ),
                                  );
                                },
                        child: Text(
                          slot == null
                              ? "Plus d'emplacement disponible"
                              : 'Lancer ce sort (niveau $slot)',
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
);

/// Grimoire (`CharSheetSpellbook.dc.html`) : la liste de sorts de la classe,
/// recherche, filtre par niveau, et préparation d'un toucher.
class SpellbookScreen extends ConsumerStatefulWidget {
  const SpellbookScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<SpellbookScreen> createState() => _SpellbookScreenState();
}

class _SpellbookScreenState extends ConsumerState<SpellbookScreen> {
  var _query = '';
  int? _level;

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(characterProvider(widget.characterId)).value;
    final cls =
        ref
            .watch(allClassesProvider)
            .value
            ?.where((c) => c.id == doc?.classId)
            .firstOrNull;
    final spells = _classSpells(
      ref.watch(allSpellsProvider).value ?? const [],
      cls,
    );
    final levels = {for (final s in spells) s.level}.toList()..sort();
    final shown = [
      for (final s in spells)
        if ((_level == null || s.level == _level) &&
            s.name.toLowerCase().contains(_query.toLowerCase()))
          s,
    ];
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grimoire'),
            Text(
              cls == null ? 'Tous les sorts' : 'Liste de sorts de ${cls.name}',
              style: muted,
            ),
          ],
        ),
      ),
      body:
          doc == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Chercher un sort',
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final level in [null, ...levels])
                            ChoiceChip(
                              label: Text(switch (level) {
                                null => 'Tous',
                                0 => 'Mineurs',
                                _ => 'Niv. $level',
                              }),
                              selected: _level == level,
                              onSelected: (_) => setState(() => _level = level),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${doc.spellIds.length} sort'
                        '${doc.spellIds.length > 1 ? 's' : ''} préparé'
                        '${doc.spellIds.length > 1 ? 's' : ''}',
                      ),
                      const SizedBox(height: 12),
                      if (shown.isEmpty)
                        Text('Aucun sort ne correspond.', style: muted),
                      for (final s in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: _card,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name),
                                      Text(
                                        [
                                          s.level == 0
                                              ? 'Mineur'
                                              : 'Niv. ${s.level}',
                                          _spellSubtitle(s),
                                        ].join(' · '),
                                        style: muted,
                                      ),
                                    ],
                                  ),
                                ),
                                Tooltip(
                                  message:
                                      doc.spellIds.contains(s.id)
                                          ? 'Retirer ${s.name}'
                                          : 'Préparer ${s.name}',
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          doc.spellIds.contains(s.id)
                                              ? AppTheme.accent
                                              : AppTheme.textMuted,
                                      side: BorderSide(
                                        color:
                                            doc.spellIds.contains(s.id)
                                                ? AppTheme.accent
                                                : AppTheme.border,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed:
                                        () => ref
                                            .read(charactersControllerProvider)
                                            .save(_togglePrepared(doc, s.id)),
                                    child: Text(
                                      doc.spellIds.contains(s.id)
                                          ? 'Préparé'
                                          : 'Préparer',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }
}
