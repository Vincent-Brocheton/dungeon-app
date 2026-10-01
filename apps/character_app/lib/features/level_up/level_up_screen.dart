import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_subclass_doc.dart';
import '../../data/character_doc.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../characters/characters_providers.dart';
import '../sheet/roll_dialog.dart';
import '../wizard/wizard_rules.dart';

String _signed(int value) => value >= 0 ? '+$value' : '$value';

enum _Hp { average, roll }

enum _Asi { plusTwo, plusOneOne, feat }

/// Montée de niveau d'une classe (`LevelUpHP`, `LevelUpFeatures`,
/// `LevelUpFeaturesSubclass`, `LevelUpASI`, `LevelUpSummary`) : PV (moyenne
/// ou dé), aptitudes du niveau et choix de sous-classe quand il est dû,
/// amélioration de caractéristique aux niveaux prévus par la classe, puis
/// récapitulatif. Multiclassage et choix de sorts viendront avec leurs
/// maquettes ; un don pris à la place d'une amélioration se note à la main.
class LevelUpScreen extends ConsumerStatefulWidget {
  const LevelUpScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends ConsumerState<LevelUpScreen> {
  var _step = 0;
  var _hp = _Hp.average;
  int? _rolled;
  String? _subclassId;
  var _asi = _Asi.plusTwo;
  final _asiPicks = <Ability>[];

  /// Montée confirmée : le personnage a déjà changé de niveau, l'écran ne
  /// doit plus se recalculer pendant le retour à la fiche.
  var _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return const Scaffold();
    final doc = ref.watch(characterProvider(widget.characterId)).value;
    final cls =
        ref
            .watch(allClassesProvider)
            .value
            ?.where((c) => c.id == doc?.classId)
            .firstOrNull;
    if (doc == null || cls == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final subclasses = [
      for (final s
          in ref.watch(allSubclassesProvider).value ??
              const <AdminSubclassDoc>[])
        if (s.parentClassId == cls.id) s,
    ];
    final level = doc.level + 1;
    final needsSubclass =
        doc.subclassId == null &&
        subclasses.isNotEmpty &&
        level >= subclasses.map((s) => s.level).reduce(min);
    final asiLevel = cls.asiLevels.contains(level);
    final steps = [
      'Points de vie',
      'Aptitudes',
      if (asiLevel) 'Amélioration',
      'Récapitulatif',
    ];
    final die = int.tryParse(cls.hitDie.substring(1)) ?? 8;
    final con = abilityModifier(doc.scores.constitution);
    final gain = _hp == _Hp.average ? die ~/ 2 + 1 : _rolled;
    final subclass =
        subclasses
            .where((s) => s.id == (_subclassId ?? doc.subclassId))
            .firstOrNull;

    final canContinue = switch (steps[_step]) {
      'Points de vie' => gain != null,
      'Aptitudes' => !needsSubclass || _subclassId != null,
      'Amélioration' =>
        _asi == _Asi.feat || _asiPicks.length == (_asi == _Asi.plusTwo ? 1 : 2),
      _ => true,
    };
    final last = _step == steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _step == 0 ? 'Annuler' : 'Retour',
          icon: Icon(_step == 0 ? Icons.close : Icons.chevron_left),
          onPressed: () => _step == 0 ? context.pop() : setState(() => _step--),
        ),
        title: Text('Niveau ${doc.level} → $level'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Étape ${_step + 1}/${steps.length}',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppTheme.accent : AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: switch (steps[_step]) {
              'Points de vie' => _hpStep(doc, cls, die, con),
              'Aptitudes' => _featuresStep(
                doc,
                cls,
                level,
                needsSubclass,
                subclasses,
                subclass,
              ),
              'Amélioration' => _asiStep(doc, level),
              _ => _summary(doc, cls, level, die, con, gain!, subclass),
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed:
                !canContinue
                    ? null
                    : last
                    ? () => _confirm(doc, die, gain!)
                    : () => setState(() => _step++),
            child: Text(
              last
                  ? 'Confirmer la montée de niveau'
                  : 'Continuer · ${steps[_step + 1]}',
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      ],
    ),
  );

  List<Widget> _hpStep(CharacterDoc doc, AdminClassDoc cls, int die, int con) {
    final average = die ~/ 2 + 1;
    return [
      _heading(
        'Points de vie supplémentaires',
        '${cls.name}, dé de vie d$die · modificateur de Constitution '
            '${_signed(con)}',
      ),
      _Choice(
        selected: _hp == _Hp.average,
        title: 'Prendre la moyenne',
        subtitle:
            '$average (moyenne d’un d$die) ${_signed(con)} (Constitution) '
            '= ${average + con} PV',
        trailing: _signed(average + con),
        onTap: () => setState(() => _hp = _Hp.average),
      ),
      _Choice(
        selected: _hp == _Hp.roll,
        title: _rolled == null ? 'Lancer 1d$die' : 'Lancé : $_rolled',
        subtitle:
            _rolled == null
                ? 'Résultat du dé ${_signed(con)} (Constitution)'
                : '$_rolled ${_signed(con)} (Constitution) = '
                    '${_rolled! + con} PV',
        trailing:
            _rolled == null ? '1d$die${_signed(con)}' : _signed(_rolled! + con),
        onTap:
            () => setState(() {
              _hp = _Hp.roll;
              // Un seul lancer : pas de relance jusqu'au résultat voulu.
              _rolled ??= ref.read(diceRngProvider).nextInt(die) + 1;
            }),
      ),
    ];
  }

  List<Widget> _featuresStep(
    CharacterDoc doc,
    AdminClassDoc cls,
    int level,
    bool needsSubclass,
    List<AdminSubclassDoc> subclasses,
    AdminSubclassDoc? subclass,
  ) {
    String at(List<String> features) =>
        level <= features.length ? features[level - 1].trim() : '';
    final classFeature = at(cls.levelFeatures);
    final subclassFeature = subclass == null ? '' : at(subclass.levelFeatures);
    final resources = [
      for (final c in cls.resourceColumns)
        if (c.name.isNotEmpty &&
            level <= c.values.length &&
            c.values[level - 1] != c.values[level - 2])
          (c.name, c.values[level - 2], c.values[level - 1]),
    ];
    return [
      _heading('Aptitudes débloquées', 'Ajoutées à ta fiche (onglet Actions).'),
      if (needsSubclass) ...[
        Text(
          'CHOIX DE LA SOUS-CLASSE',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        for (final s in subclasses)
          _Choice(
            selected: _subclassId == s.id,
            title: s.name,
            subtitle: [
              s.description,
              s.features,
            ].where((t) => t.trim().isNotEmpty).join(' · '),
            onTap: () => setState(() => _subclassId = s.id),
          ),
        const SizedBox(height: 8),
      ],
      if (classFeature.isNotEmpty)
        _Feature(name: classFeature, source: cls.name),
      if (subclassFeature.isNotEmpty)
        _Feature(name: subclassFeature, source: subclass!.name),
      if (classFeature.isEmpty && subclassFeature.isEmpty)
        const _Info('Pas de nouvelle aptitude à ce niveau.'),
      for (final (name, before, after) in resources)
        _Info('$name : $before → $after'),
    ];
  }

  List<Widget> _asiStep(CharacterDoc doc, int level) {
    final count = _asi == _Asi.plusTwo ? 1 : 2;
    return [
      _heading(
        'Amélioration de caractéristique ou Don',
        'Au niveau $level : +2 à une caractéristique, +1 à deux, ou un don.',
      ),
      SegmentedButton<_Asi>(
        segments: const [
          ButtonSegment(value: _Asi.plusTwo, label: Text('+2')),
          ButtonSegment(value: _Asi.plusOneOne, label: Text('+1 / +1')),
          ButtonSegment(value: _Asi.feat, label: Text('Don')),
        ],
        selected: {_asi},
        showSelectedIcon: false,
        onSelectionChanged:
            (s) => setState(() {
              _asi = s.single;
              _asiPicks.clear();
            }),
      ),
      const SizedBox(height: 16),
      if (_asi == _Asi.feat)
        const _Info(
          'Choisis ton don avec ton MJ et note-le dans l’onglet Notes ; '
          'les dons arriveront sur la fiche plus tard.',
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in Ability.values)
              FilterChip(
                label: Text(
                  '${abilityLabel(a)} ${doc.scores[a]}'
                  '${_asiPicks.contains(a) ? ' → ${min(abilityScoreCap, doc.scores[a] + (count == 1 ? 2 : 1))}' : ''}',
                ),
                selected: _asiPicks.contains(a),
                onSelected:
                    doc.scores[a] >= abilityScoreCap
                        ? null
                        : (on) => setState(() {
                          if (!on) {
                            _asiPicks.remove(a);
                          } else if (_asiPicks.length < count) {
                            _asiPicks.add(a);
                          }
                        }),
              ),
          ],
        ),
    ];
  }

  Map<Ability, int> get _bonus => {
    if (_asi == _Asi.plusTwo && _asiPicks.length == 1) _asiPicks.single: 2,
    if (_asi == _Asi.plusOneOne)
      for (final a in _asiPicks) a: 1,
  };

  List<Widget> _summary(
    CharacterDoc doc,
    AdminClassDoc cls,
    int level,
    int die,
    int con,
    int gain,
    AdminSubclassDoc? subclass,
  ) {
    final before =
        die + con + levelUpHitPoints(die, con, doc.level, doc.hpGains);
    final scores = improveAbilities(doc.scores, _bonus);
    final newCon = abilityModifier(scores.constitution);
    // Un +1 en Constitution rétroagit sur tous les niveaux (PHB 2024).
    final after =
        die +
        newCon +
        levelUpHitPoints(die, newCon, level, _gains(doc, die, gain));
    final slotsBefore = cls.spellcaster ? fullCasterSlots(doc.level) : <int>[];
    final slotsAfter = cls.spellcaster ? fullCasterSlots(level) : <int>[];
    return [
      Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$level',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${doc.name} est prêt·e',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${cls.name}${subclass == null ? '' : ' (${subclass.name})'} '
              '$level',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Row('Points de vie maximum', '$before → $after'),
      _Row('Dés de vie', '${doc.level}d$die → ${level}d$die'),
      _Row(
        'Bonus de maîtrise',
        proficiencyBonus(doc.level) == proficiencyBonus(level)
            ? '${_signed(proficiencyBonus(level))} (inchangé)'
            : '${_signed(proficiencyBonus(doc.level))} → '
                '${_signed(proficiencyBonus(level))}',
      ),
      if (subclass != null && doc.subclassId == null)
        _Row('Sous-classe', subclass.name),
      for (final MapEntry(key: a, value: n) in _bonus.entries)
        if (n > 0) _Row(abilityLabel(a), '${doc.scores[a]} → ${scores[a]}'),
      if (_asi == _Asi.feat && cls.asiLevels.contains(level))
        const _Row('Don', 'à noter dans l’onglet Notes'),
      for (var i = 0; i < slotsAfter.length; i++)
        if ((i < slotsBefore.length ? slotsBefore[i] : 0) != slotsAfter[i])
          _Row(
            'Emplacements niveau ${i + 1}',
            '${i < slotsBefore.length ? slotsBefore[i] : 0} → '
                '${slotsAfter[i]}',
          ),
    ];
  }

  /// Gains de PV jusqu'au nouveau niveau : les niveaux passés sans gain
  /// enregistré prennent la moyenne, le nouveau niveau [gain].
  List<int> _gains(CharacterDoc doc, int die, int gain) => [
    for (var l = 2; l <= doc.level; l++)
      l - 2 < doc.hpGains.length ? doc.hpGains[l - 2] : die ~/ 2 + 1,
    gain,
  ];

  void _confirm(CharacterDoc doc, int die, int gain) {
    setState(() => _done = true);
    ref
        .read(charactersControllerProvider)
        .save(
          doc.copyWith(
            level: doc.level + 1,
            hpGains: _gains(doc, die, gain),
            scores: improveAbilities(doc.scores, _bonus),
            subclassId: _subclassId,
          ),
        );
    context.go(AppRoutes.character(doc.id));
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2114) : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing case final t?)
              Text(
                t,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.name, required this.source});

  final String name;
  final String source;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2114),
      border: Border.all(color: AppTheme.accent),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'NOUVEAU',
            style: TextStyle(
              color: AppTheme.background,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name)),
        Text(source, style: const TextStyle(color: AppTheme.textMuted)),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF7FA86A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
