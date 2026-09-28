import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_background_doc.dart';
import '../../data/admin_class_doc.dart';
import '../../data/admin_monster_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../data/admin_subspecies_doc.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../characters/characters_providers.dart';
import 'wizard_rules.dart';

const _steps = [
  'Classe',
  'Espèce',
  'Historique',
  'Langues',
  'Caractéristiques',
  'Alignement',
  'Finalisation',
];

enum _Method {
  standard('Valeurs standard'),
  random('Génération aléatoire'),
  pointBuy('Acquisition par points');

  const _Method(this.label);

  final String label;
}

const _alignmentDescriptions = {
  'Loyal Bon': "S'efforce de faire le bien selon les attentes de la société.",
  'Neutre Bon': 'Fait de son mieux pour aider les autres, selon leurs besoins.',
  'Chaotique Bon': 'Agit selon sa conscience, sans se soucier des attentes.',
  'Loyal Neutre': 'Agit selon la loi, la tradition ou un code personnel.',
  'Neutre': 'Préfère éviter les partis pris et fait ce qui semble le mieux.',
  'Chaotique Neutre': 'Suit ses caprices, attaché avant tout à sa liberté.',
  'Loyal Mauvais':
      "Prend méthodiquement ce qu'il veut, dans les limites d'un code.",
  'Neutre Mauvais': "Fait ce qu'il veut tant qu'il n'a pas à en répondre.",
  'Chaotique Mauvais':
      'Agit avec une violence arbitraire, poussé par sa cupidité.',
};

String _signed(int value) => value >= 0 ? '+$value' : '$value';

String _initial(String name) => name.isEmpty ? '?' : name[0].toUpperCase();

/// Caractéristiques d'un historique (libellés français), dans l'ordre.
List<Ability> _abilitiesOf(AdminBackgroundDoc? doc) => [
  for (final label in doc?.abilities ?? const <String>[])
    if (abilityFromLabel(label) case final a?) a,
];

/// Assistant de création de personnage (niveau 1) : classe, espèce et
/// sous-espèce, historique et répartition de son bonus, langues,
/// caractéristiques (valeurs standard, 4d6 ou achat de points), alignement,
/// puis finalisation avec les statistiques calculées. Reprend les maquettes
/// `Wizard*.dc.html` — sans les deux étapes d'équipement (à venir), ni
/// brouillon : le personnage n'est enregistré qu'à la dernière étape.
class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({super.key});

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  final _rng = Random();
  final _name = TextEditingController();
  var _step = 0;
  var _saving = false;

  String? _classId;
  String? _speciesId;
  String? _subspeciesId;
  String? _backgroundId;
  var _evenSpread = false;
  Ability? _plusTwo;
  Ability? _plusOne;
  final _languages = <String>{};
  var _method = _Method.standard;
  AbilityScores? _assigned;
  List<int>? _rolled;
  var _pointBuy = PointBuy.standardStart;
  String? _alignment;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<AdminClassDoc> get _classes =>
      ref.watch(allClassesProvider).value ?? const [];
  List<AdminSpeciesDoc> get _species =>
      ref.watch(allSpeciesProvider).value ?? const [];
  List<AdminSubspeciesDoc> get _subspecies =>
      ref.watch(allSubspeciesProvider).value ?? const [];
  List<AdminBackgroundDoc> get _backgrounds =>
      ref.watch(allBackgroundsProvider).value ?? const [];

  AdminClassDoc? get _class =>
      _classes.where((c) => c.id == _classId).firstOrNull;
  AdminSpeciesDoc? get _speciesDoc =>
      _species.where((s) => s.id == _speciesId).firstOrNull;
  AdminSubspeciesDoc? get _subspeciesDoc =>
      _subspecies.where((s) => s.id == _subspeciesId).firstOrNull;
  AdminBackgroundDoc? get _background =>
      _backgrounds.where((b) => b.id == _backgroundId).firstOrNull;

  Ability? get _primary => abilityFromLabel(_class?.primaryAbility ?? '');

  BackgroundBonus? get _bonus {
    final abilities = _abilitiesOf(_background);
    if (abilities.length != 3) return null;
    if (_evenSpread) return PlusOneEach(abilities.toSet());
    final plusTwo = _plusTwo, plusOne = _plusOne;
    if (plusTwo == null || plusOne == null) return null;
    return PlusTwoPlusOne(plusTwo: plusTwo, plusOne: plusOne);
  }

  /// Valeurs à répartir (standard ou tirées), `null` si pas encore tirées.
  List<int>? get _pool =>
      _method == _Method.standard ? standardArrayValues : _rolled;

  AbilityScores? get _baseScores {
    if (_method == _Method.pointBuy) return _pointBuy;
    final pool = _pool;
    if (pool == null) return null;
    return _assigned ??= assignValues(pool, defaultAssignmentOrder(_primary));
  }

  AbilityScores? get _finalScores {
    final base = _baseScores;
    if (base == null) return null;
    return _bonus?.applyTo(base) ?? base;
  }

  bool get _stepValid => switch (_step) {
    0 => _class != null,
    1 => _speciesDoc != null,
    2 => _background != null && _bonus != null,
    3 => _languages.length == languagesToChoose,
    4 =>
      _baseScores != null &&
          (_method != _Method.pointBuy ||
              PointBuy.validate(_pointBuy).isEmpty) &&
          (_bonus?.validateCap(_baseScores!).isEmpty ?? true),
    5 => _alignment != null,
    _ => _name.text.trim().isNotEmpty,
  };

  void _selectBackground(AdminBackgroundDoc doc) => setState(() {
    _backgroundId = doc.id;
    final abilities = _abilitiesOf(doc);
    if (abilities.length == 3) {
      final bonus = defaultBonus(abilities, _primary) as PlusTwoPlusOne;
      _plusTwo = bonus.plusTwo;
      _plusOne = bonus.plusOne;
    }
    _evenSpread = false;
  });

  Future<void> _next() async {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(charactersControllerProvider)
          .create(
            name: _name.text,
            scores: _finalScores!,
            classId: _classId,
            speciesId: _speciesId,
            subspeciesId: _subspeciesId,
            backgroundId: _backgroundId,
            alignment: _alignment,
            languages: ['Commun', ..._languages],
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _step == _steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.chevron_left),
          onPressed: _back,
        ),
        title: const Text('Nouveau personnage'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Étape ${_step + 1}/${_steps.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  children: switch (_step) {
                    0 => _classStep(),
                    1 => _speciesStep(),
                    2 => _backgroundStep(),
                    3 => _languagesStep(),
                    4 => _abilitiesStep(),
                    5 => _alignmentStep(),
                    _ => _summaryStep(),
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _stepValid && !_saving ? _next : null,
                    child: Text(
                      last
                          ? 'Créer le personnage'
                          : 'Continuer · ${_steps[_step + 1]}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? get _muted => Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(subtitle, style: _muted),
      ],
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(text, style: _muted),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
    ),
  );

  List<Widget> _classStep() => [
    _heading(
      'Choisis une classe',
      'Elle englobe sa vocation, ses talents particuliers et ses tactiques '
          'de prédilection.',
    ),
    if (_classes.isEmpty)
      _empty('Aucune classe dans le compendium : demande à ton MJ.'),
    for (final c in [..._classes]..sort((a, b) => a.name.compareTo(b.name)))
      _Option(
        title: c.name,
        subtitle: 'Dé de vie ${c.hitDie} · ${c.primaryAbility}',
        selected: c.id == _classId,
        onTap:
            () => setState(() {
              _classId = c.id;
              // La répartition par défaut dépend de la classe.
              _assigned = null;
            }),
      ),
  ];

  List<Widget> _speciesStep() {
    final species = _speciesDoc;
    final sub = _subspeciesDoc;
    final subspecies = [
      for (final s in _subspecies)
        if (s.parentSpeciesId == _speciesId) s,
    ];
    final speed = (sub?.speed ?? '').isNotEmpty ? sub!.speed : species?.speed;
    final vision =
        (sub?.vision ?? '').isNotEmpty ? sub!.vision : species?.vision;
    return [
      _heading(
        'Choisis une espèce',
        'Elle détermine la taille, la Vitesse et les traits de ton personnage.',
      ),
      if (_species.isEmpty)
        _empty('Aucune espèce dans le compendium : demande à ton MJ.'),
      for (final s in _species)
        _Option(
          title: s.name,
          subtitle: [
            'Taille ${s.size}',
            if (s.speed.isNotEmpty) 'Vitesse ${s.speed}',
            if (s.vision.isNotEmpty) s.vision,
          ].join(' · '),
          selected: s.id == _speciesId,
          onTap:
              () => setState(() {
                _speciesId = s.id;
                _subspeciesId = null;
              }),
        ),
      if (subspecies.isNotEmpty) ...[
        const SizedBox(height: 8),
        _label('Sous-espèce (optionnelle)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in subspecies)
              ChoiceChip(
                label: Text(s.name),
                selected: s.id == _subspeciesId,
                onSelected:
                    (on) => setState(() => _subspeciesId = on ? s.id : null),
              ),
          ],
        ),
      ],
      if (species != null)
        _Panel(
          title: "Traits d'espèce",
          lines: [
            [
              if (speed != null && speed.isNotEmpty) 'Vitesse $speed',
              'Taille ${species.size}',
            ].join(' · '),
            if (vision != null && vision.isNotEmpty) vision,
            if (species.traits.isNotEmpty) species.traits,
            if (sub != null && sub.traits.isNotEmpty) sub.traits,
          ],
        ),
    ];
  }

  List<Widget> _backgroundStep() {
    final abilities = _abilitiesOf(_background);
    return [
      _heading(
        'Choisis un historique',
        "Il fixe tes caractéristiques bonifiables et ton Don d'Origine.",
      ),
      if (_backgrounds.isEmpty)
        _empty('Aucun historique dans le compendium : demande à ton MJ.'),
      for (final b in _backgrounds)
        _Option(
          title: b.name,
          subtitle: [
            b.abilities.join(', '),
            if (b.originFeat.isNotEmpty) 'Don : ${b.originFeat}',
          ].join(' · '),
          selected: b.id == _backgroundId,
          onTap: () => _selectBackground(b),
        ),
      if (abilities.length == 3) ...[
        const SizedBox(height: 8),
        _label('Répartition des bonus'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('+2 / +1')),
            ButtonSegment(value: true, label: Text('+1 / +1 / +1')),
          ],
          selected: {_evenSpread},
          onSelectionChanged: (s) => setState(() => _evenSpread = s.single),
        ),
        if (!_evenSpread) ...[
          const SizedBox(height: 10),
          Row(
            key: ValueKey('$_plusTwo/$_plusOne'),
            children: [
              Expanded(
                child: _AbilityPicker(
                  label: '+2',
                  value: _plusTwo,
                  options: abilities,
                  onChanged:
                      (a) => setState(() {
                        if (a == _plusOne) _plusOne = _plusTwo;
                        _plusTwo = a;
                      }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AbilityPicker(
                  label: '+1',
                  value: _plusOne,
                  options: abilities,
                  onChanged:
                      (a) => setState(() {
                        if (a == _plusTwo) _plusTwo = _plusOne;
                        _plusOne = a;
                      }),
                ),
              ),
            ],
          ),
        ],
      ],
    ];
  }

  List<Widget> _languagesStep() {
    final suggested = suggestedLanguages(_speciesDoc?.languages ?? '');
    return [
      _heading(
        'Choisis tes langues',
        'Le Commun est acquis automatiquement. Choisis $languagesToChoose '
            'langues supplémentaires.',
      ),
      const _Option(
        title: 'Commun',
        subtitle: 'Acquise automatiquement',
        selected: true,
      ),
      if (suggested.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Suggestion liée à ton espèce (${_speciesDoc!.name}) : '
            '${suggested.join(', ')}',
            style: _muted?.copyWith(color: AppTheme.accent),
          ),
        ),
      const SizedBox(height: 8),
      _label('Langues courantes — choisis-en $languagesToChoose'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in commonLanguages)
            FilterChip(
              label: Text(l),
              selected: _languages.contains(l),
              onSelected:
                  _languages.contains(l) ||
                          _languages.length < languagesToChoose
                      ? (on) => setState(
                        () => on ? _languages.add(l) : _languages.remove(l),
                      )
                      : null,
            ),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Langues rares',
        lines: const [
          'Abyssal, Argot des voleurs, Céleste, Commun des profondeurs, '
              'Druidique, Infernal, Primordial, Profond, Sylvestre — '
              "certaines capacités permettent d'en apprendre une plus tard.",
        ],
        muted: true,
      ),
    ];
  }

  List<Widget> _abilitiesStep() {
    final theme = Theme.of(context);
    final base = _baseScores;
    final bonus = _bonus;
    final pool = _pool;
    final remaining = PointBuy.remaining(_pointBuy);
    final finalScores = _finalScores;
    return [
      _heading(
        'Détermine tes caractéristiques',
        'Choisis une méthode de génération, puis répartis les valeurs.',
      ),
      SegmentedButton<_Method>(
        segments: [
          for (final m in _Method.values)
            ButtonSegment(value: m, label: Text(m.label)),
        ],
        selected: {_method},
        onSelectionChanged:
            (s) => setState(() {
              _method = s.single;
              _assigned = null;
            }),
      ),
      const SizedBox(height: 10),
      Text(switch (_method) {
        _Method.standard =>
          'Valeurs standard : ${standardArrayValues.join(', ')} — réparties '
              'selon ta classe (${_class?.name ?? '—'}). Échange-les à ta '
              'guise.',
        _Method.random => 'Quatre d6 par valeur, on garde les trois meilleurs.',
        _Method.pointBuy =>
          'Points restants : $remaining / ${PointBuy.budget} (scores 8 à 15).',
      }, style: _muted),
      if (_method == _Method.random)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed:
                () => setState(() {
                  _rolled = roll4d6DropLowest(_rng);
                  _assigned = null;
                }),
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: Text(
              _rolled == null
                  ? 'Lancer les dés'
                  : 'Relancer (${_rolled!.join(', ')})',
            ),
          ),
        ),
      const SizedBox(height: 10),
      if (base != null && finalScores != null)
        for (final a in Ability.values)
          _AbilityRow(
            label: abilityLabel(a),
            detail: _detail(base[a], bonus?.bonuses[a]),
            modifier: _signed(abilityModifier(finalScores[a])),
            highlight: (bonus?.bonuses[a] ?? 0) > 0,
            control:
                _method == _Method.pointBuy
                    ? _pointBuyControl(a, remaining)
                    : DropdownButton<int>(
                      value: base[a],
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final v in {...pool!})
                          DropdownMenuItem(value: v, child: Text('$v')),
                      ],
                      onChanged:
                          (v) => setState(() {
                            // Échange avec la caractéristique qui avait v.
                            final other = Ability.values.firstWhere(
                              (o) => base[o] == v,
                            );
                            _assigned = base
                                .withScore(other, base[a])
                                .withScore(a, v!);
                          }),
                    ),
          ),
      if (bonus != null && base != null)
        for (final v in bonus.validateCap(base))
          Text(
            v.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      const SizedBox(height: 8),
      _Panel(
        title: 'Calcul automatique',
        lines: [
          'Les ajustements de ton historique (${_background?.name ?? '—'}) et '
              'les modificateurs sont calculés automatiquement.',
        ],
        muted: true,
      ),
    ];
  }

  String _detail(int base, int? bonus) {
    if (bonus == null || bonus == 0) return '$base = $base';
    return '$base +$bonus (${_background!.name}) = ${base + bonus}';
  }

  Widget _pointBuyControl(Ability a, int remaining) {
    final score = _pointBuy[a];
    final canUp =
        score < PointBuy.maxScore &&
        PointBuy.deltaCost(score, score + 1) <= remaining;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Diminuer ${abilityLabel(a)}',
          icon: const Icon(Icons.remove, size: 18),
          onPressed:
              score > PointBuy.minScore
                  ? () => setState(
                    () => _pointBuy = _pointBuy.withScore(a, score - 1),
                  )
                  : null,
        ),
        IconButton(
          tooltip: 'Augmenter ${abilityLabel(a)}',
          icon: const Icon(Icons.add, size: 18),
          onPressed:
              canUp
                  ? () => setState(
                    () => _pointBuy = _pointBuy.withScore(a, score + 1),
                  )
                  : null,
        ),
      ],
    );
  }

  List<Widget> _alignmentStep() {
    final alignments = [
      for (final a in AdminMonsterDoc.alignments)
        if (a != 'Non aligné') a,
    ];
    final selected = _alignment;
    return [
      _heading(
        'Choisis un alignement',
        'Il résume le point de vue moral de ton personnage.',
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: [
          for (final a in alignments)
            _AlignmentCell(
              name: a,
              selected: a == selected,
              onTap: () => setState(() => _alignment = a),
            ),
        ],
      ),
      if (selected != null) ...[
        const SizedBox(height: 12),
        _Panel(
          title: '$selected — sélectionné',
          lines: [_alignmentDescriptions[selected] ?? ''],
        ),
      ],
      const SizedBox(height: 12),
      Text(
        "Le jeu part du principe que les PJ ne sont pas d'alignement mauvais. "
        'Vérifie avec ton MJ si tu choisis un alignement mauvais.',
        style: _muted,
      ),
    ];
  }

  List<Widget> _summaryStep() {
    final theme = Theme.of(context);
    final scores = _finalScores!;
    final cls = _class!;
    final stats = deriveStats(
      scores: scores,
      hitDie: cls.hitDie,
      savingThrows: cls.savingThrows,
    );
    final speciesName = _subspeciesDoc?.name ?? _speciesDoc!.name;
    return [
      _heading(
        'Finalise ta fiche',
        'Vérifie les informations calculées automatiquement, puis valide.',
      ),
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _initial(_name.text.trim()),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.background,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('wizard-name-field'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Nom du personnage',
                  ),
                ),
                const SizedBox(height: 4),
                Text('${cls.name} 1 · $speciesName', style: _muted),
                Text(
                  'Historique ${_background!.name} · $_alignment',
                  style: _muted,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (final a in Ability.values) ...[
            if (a != Ability.strength) const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: abilityLabel(a).substring(0, 3),
                value: '${scores[a]}',
                sub: _signed(abilityModifier(scores[a])),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _label('Calculé automatiquement'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Stat(label: 'PV max', value: '${stats.hitPoints}'),
          _Stat(label: "Classe d'armure", value: '${stats.armorClass}'),
          _Stat(
            label: 'Bonus maîtrise',
            value: _signed(stats.proficiencyBonus),
          ),
          _Stat(label: 'Initiative', value: _signed(stats.initiative)),
          _Stat(
            label: 'Perception passive',
            value: '${stats.passivePerception}',
          ),
          _Stat(label: 'Dé de vie', value: '1${cls.hitDie}'),
        ],
      ),
      const SizedBox(height: 12),
      _Panel(
        title: 'Jets de sauvegarde (★ maîtrisé)',
        lines: [
          [
            for (final a in Ability.values)
              '${abilityLabel(a).substring(0, 3)} '
                  '${_signed(stats.saves[a]!.$1)}'
                  '${stats.saves[a]!.$2 ? '★' : ''}',
          ].join(' · '),
        ],
      ),
      const SizedBox(height: 8),
      _Panel(
        title: 'Langues',
        lines: [
          ['Commun', ..._languages].join(', '),
        ],
      ),
    ];
  }
}

/// Choix sélectionnable (classe, espèce, historique…).
class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
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
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppTheme.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.lines, this.muted = false});

  final String title;
  final List<String> lines;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        muted
            ? theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)
            : theme.textTheme.bodyMedium;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines) Text(line, style: style),
        ],
      ),
    );
  }
}

class _AbilityPicker extends StatelessWidget {
  const _AbilityPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Ability? value;
  final List<Ability> options;
  final ValueChanged<Ability> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<Ability>(
    initialValue: value,
    decoration: InputDecoration(isDense: true, labelText: label),
    items: [
      for (final a in options)
        DropdownMenuItem(value: a, child: Text(abilityLabel(a))),
    ],
    onChanged: (a) {
      if (a != null) onChanged(a);
    },
  );
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    required this.label,
    required this.detail,
    required this.modifier,
    required this.highlight,
    required this.control,
  });

  final String label;
  final String detail;
  final String modifier;
  final bool highlight;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: highlight ? AppTheme.accent : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          control,
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(modifier, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _AlignmentCell extends StatelessWidget {
  const _AlignmentCell({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abbreviation =
        name == 'Neutre'
            ? 'N'
            : name.split(' ').map((w) => w[0].toUpperCase()).join();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              abbreviation,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
            Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
          if (sub != null)
            Text(
              sub!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.accent,
              ),
            ),
        ],
      ),
    );
  }
}
