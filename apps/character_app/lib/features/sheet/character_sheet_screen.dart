import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/admin_spell_doc.dart';
import '../../data/character_doc.dart';
import '../../providers/content_providers.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../characters/characters_providers.dart';
import '../wizard/wizard_rules.dart';
import 'condition_labels.dart';
import 'rest_dialogs.dart';
import 'roll_dialog.dart';

part 'conditions_part.dart';
part 'dying_part.dart';
part 'inventory_part.dart';
part 'notes_part.dart';
part 'spells_tab.dart';

String _signed(int value) => value >= 0 ? '+$value' : '$value';

/// Fiche d'un personnage. Reprend `CharSheetSummary.dc.html` (onglets
/// Résumé et Sac sur mobile) et `CharSheetWeb.dc.html` (trois colonnes à
/// partir de 900px) ; onglet Actions : `CharSheetActions.dc.html`.
/// Initiative, sauvegardes et compétences se lancent au d20 (cf.
/// `roll_dialog.dart`), repos dans `rest_dialogs.dart`, sorts et grimoire
/// dans `spells_tab.dart`, conditions et inspiration dans
/// `conditions_part.dart`, sac dans `inventory_part.dart`, notes dans
/// `notes_part.dart`.
class CharacterSheetScreen extends ConsumerStatefulWidget {
  const CharacterSheetScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<CharacterSheetScreen> createState() =>
      _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends ConsumerState<CharacterSheetScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(characterProvider(widget.characterId));
    return character.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data:
          (doc) =>
              doc == null
                  ? Scaffold(
                    appBar: AppBar(),
                    body: const Center(child: Text('Personnage introuvable.')),
                  )
                  : _sheet(doc),
    );
  }

  Widget _sheet(CharacterDoc doc) {
    final cls =
        ref
            .watch(allClassesProvider)
            .value
            ?.where((c) => c.id == doc.classId)
            .firstOrNull;
    final species =
        ref
            .watch(allSpeciesProvider)
            .value
            ?.where((s) => s.id == doc.speciesId)
            .firstOrNull;
    final subspecies =
        ref
            .watch(allSubspeciesProvider)
            .value
            ?.where((s) => s.id == doc.subspeciesId)
            .firstOrNull;
    final background =
        ref
            .watch(allBackgroundsProvider)
            .value
            ?.where((b) => b.id == doc.backgroundId)
            .firstOrNull;
    final stats = deriveStats(
      scores: doc.scores,
      hitDie: cls?.hitDie ?? 'd8',
      savingThrows: cls?.savingThrows ?? '',
      skillProficiencies: background?.skills ?? '',
      level: doc.level,
    );
    final conditions = doc.activeConditions;
    final speed = effectiveSpeed(
      (subspecies?.speed.isNotEmpty ?? false)
          ? subspecies!.speed
          : species?.speed ?? '—',
      conditions,
      doc.exhaustion,
    );
    D20Effects effects(D20Test test, [Ability? ability]) =>
        d20Effects(conditions, doc.exhaustion, test, ability: ability);
    final controller = ref.read(charactersControllerProvider);
    final spendInspiration =
        doc.heroicInspiration
            ? () => controller.save(doc.copyWith(heroicInspiration: false))
            : null;
    final subtitle = [
      cls == null ? 'Niveau ${doc.level}' : '${cls.name} ${doc.level}',
      if (subspecies?.name ?? species?.name case final s?) s,
      if (background != null) background.name,
    ].join(' · ');

    final pack = ref.watch(srdPackProvider).value;
    final armors = pack?.armors ?? const <ArmorDef>[];
    final worn = [
      for (final item in doc.inventory)
        if (item.equipped)
          if (armorForItem(item.name, armors) case final a?) a,
    ];
    final armorClassValue = armorClass(
      abilityModifier(doc.scores.dexterity),
      armor: worn.where((a) => a.category != ArmorCategory.shield).firstOrNull,
      shield: worn.where((a) => a.category == ArmorCategory.shield).firstOrNull,
    );
    const dcHint = 'Compare ce total au DD demandé par le MJ.';
    final strip = _StatStrip(
      stats: [
        ('CA', '$armorClassValue', null),
        (
          'Init.',
          _signed(stats.initiative),
          () => showRollDialog(
            context,
            title: "Jet d'initiative",
            subtitle: '${doc.name} · Dextérité ${_signed(stats.initiative)}',
            modifierLabel: 'Dextérité',
            modifier: stats.initiative,
            hint:
                "Ce résultat détermine ta place dans l'ordre d'initiative — "
                'communique-le à ton MJ pour le suivi de combat.',
            effects: effects(D20Test.check),
            onSpendInspiration: spendInspiration,
          ),
        ),
        ('Vitesse', speed, null),
        ('Perc. pas.', '${stats.passivePerception}', null),
      ],
    );
    String mastery(bool proficient) => proficient ? ', maîtrisé' : '';
    final hp = _HitPoints(
      doc: doc,
      maxHp: stats.hitPoints,
      hitDieSides: int.tryParse((cls?.hitDie ?? 'd8').substring(1)) ?? 8,
    );
    final abilities = _Abilities(scores: doc.scores);
    final saves = _ModifierList(
      title: 'Jets de sauvegarde',
      rows: [
        for (final a in Ability.values)
          (abilityLabel(a), null, stats.saves[a]!.$1, stats.saves[a]!.$2),
      ],
      onRoll:
          (name, _, modifier, proficient) => showRollDialog(
            context,
            title: 'Jet de sauvegarde',
            subtitle: '${doc.name} · $name${mastery(proficient)}',
            modifierLabel: '$name${mastery(proficient)}',
            modifier: modifier,
            hint: dcHint,
            effects: effects(D20Test.save, abilityFromLabel(name)),
            onSpendInspiration: spendInspiration,
          ),
    );
    final skillList = _ModifierList(
      title: 'Compétences',
      rows: [
        for (final MapEntry(key: name, value: a) in skills.entries)
          (
            name,
            abilityLabel(a).substring(0, 3),
            stats.skills[name]!.$1,
            stats.skills[name]!.$2,
          ),
      ],
      onRoll:
          (name, ability, modifier, proficient) => showRollDialog(
            context,
            title: 'Test de compétence',
            subtitle: '${doc.name} · $name ($ability${mastery(proficient)})',
            modifierLabel: '$name ($ability${mastery(proficient)})',
            modifier: modifier,
            hint: dcHint,
            effects: effects(D20Test.check),
            onSpendInspiration: spendInspiration,
          ),
    );
    final bag = _Bag(doc: doc, pack: pack);
    final notes = _Notes(key: ValueKey(doc.id), doc: doc);
    final status = _Status(doc: doc);
    final spells = _SpellsTab(
      doc: doc,
      cls: cls,
      proficiency: stats.proficiencyBonus,
    );
    final weapons = pack?.weapons ?? const <WeaponDef>[];
    final actions = _Actions(
      cls: cls,
      scores: doc.scores,
      level: doc.level,
      proficiency: stats.proficiencyBonus,
      weapons: [
        for (final item in doc.inventory)
          if (weaponForItem(item.name, weapons) case final w?) w,
      ],
      onAttack:
          (weapon, attack, damage) => showRollDialog(
            context,
            title: "Jet d'attaque",
            subtitle:
                '${doc.name} · ${weapon.name} '
                '(${weapon.ranged ? 'distance' : 'CAC'})',
            modifierLabel: "Bonus d'attaque (${weapon.name})",
            modifier: attack,
            hint:
                'Compare ce total à la CA de la cible. Un 20 naturel est un '
                'coup critique.',
            damage: (
              count: weapon.diceCount,
              sides: weapon.diceSides,
              bonus: damage,
              type: weapon.damageType,
            ),
            effects: effects(D20Test.attack),
            onSpendInspiration: spendInspiration,
          ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        Widget column(List<Widget> children) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              c,
            ],
          ],
        );
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Retour à mes personnages',
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  () =>
                      context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.home),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                _Avatar(name: doc.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.name, overflow: TextOverflow.ellipsis),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body:
              wide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: column([abilities, saves, skillList])),
                      Expanded(child: column([strip, hp, status, actions])),
                      Expanded(child: column([spells, bag, notes])),
                    ],
                  )
                  : switch (_tab) {
                    0 => column([
                      strip,
                      hp,
                      status,
                      abilities,
                      saves,
                      skillList,
                    ]),
                    1 => column([actions]),
                    2 => column([spells]),
                    3 => column([bag]),
                    _ => column([notes]),
                  },
          bottomNavigationBar:
              wide
                  ? null
                  : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: 'Résumé',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bolt_outlined),
                        label: 'Actions',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: 'Sorts',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.backpack_outlined),
                        label: 'Sac',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.edit_note_outlined),
                        label: 'Notes',
                      ),
                    ],
                  ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.accent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.background,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

final _card = BoxDecoration(
  color: AppTheme.surface,
  border: Border.all(color: AppTheme.border),
  borderRadius: BorderRadius.circular(10),
);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// CA, initiative, vitesse, perception passive.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  /// Libellé, valeur, et jet à lancer au toucher (facultatif).
  final List<(String, String, VoidCallback?)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final (i, (label, value, onTap)) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: _card,
                child: Column(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.casino_outlined,
                        size: 12,
                        color: AppTheme.accent,
                        semanticLabel: 'Lancer : $label',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// PV actuels / max, avec dégâts, soins et PV temporaires enregistrés.
class _HitPoints extends ConsumerWidget {
  const _HitPoints({
    required this.doc,
    required this.maxHp,
    required this.hitDieSides,
  });

  final CharacterDoc doc;
  final int maxHp;
  final int hitDieSides;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = (maxHp - doc.hpLost).clamp(0, maxHp);
    final controller = ref.read(charactersControllerProvider);

    Future<void> ask(String title, void Function(int) apply) async {
      final amount = await _askAmount(context, title);
      if (amount != null) apply(amount);
    }

    return _Section(
      title: 'Points de vie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current == 0) ...[
            _Dying(doc: doc, maxHp: maxHp),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Subir des dégâts',
                      icon: const Icon(Icons.remove, color: Color(0xFFC97227)),
                      onPressed:
                          () => ask('Dégâts subis', (n) {
                            final (lost, temp) = takeDamage(
                              n,
                              hpLost: doc.hpLost,
                              tempHp: doc.tempHp,
                              maxHp: maxHp,
                            );
                            final remaining = n - (doc.tempHp - temp);
                            controller.save(
                              doc.copyWith(
                                hpLost: lost,
                                tempHp: temp,
                                deathSaves: switch ((current, lost >= maxHp)) {
                                  // Déjà à 0 PV : un échec de plus.
                                  (0, _) when remaining > 0 =>
                                    remaining >= maxHp
                                        ? const DeathSaves(failures: 3)
                                        : doc.deathSaves.damaged(),
                                  (_, true)
                                      when instantDeath(
                                        damage: remaining,
                                        currentHp: current,
                                        maxHp: maxHp,
                                      ) =>
                                    const DeathSaves(failures: 3),
                                  _ => null,
                                },
                              ),
                            );
                          }),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$current / $maxHp PV',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          InkWell(
                            onTap:
                                () => ask(
                                  'PV temporaires',
                                  (n) =>
                                      controller.save(doc.copyWith(tempHp: n)),
                                ),
                            child: Text(
                              'PV temporaires : +${doc.tempHp}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Récupérer des PV',
                      icon: const Icon(Icons.add, color: Color(0xFF7FA86A)),
                      onPressed:
                          () => ask(
                            'PV récupérés',
                            // Soigné : plus mourant, les jets repartent de zéro.
                            (n) => controller.save(
                              doc.copyWith(
                                hpLost: (doc.hpLost - n).clamp(0, maxHp),
                                deathSaves: n > 0 ? const DeathSaves() : null,
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxHp == 0 ? 0 : current / maxHp,
                    minHeight: 9,
                    color: AppTheme.accent,
                    backgroundColor: AppTheme.background,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Dés de vie ${doc.level}d$hitDieSides '
                  '(${doc.hitDiceUsed} utilisé${doc.hitDiceUsed > 1 ? 's' : ''})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            () => showShortRestDialog(
                              context,
                              doc: doc,
                              maxHp: maxHp,
                              hitDieSides: hitDieSides,
                            ),
                        child: const Text('Repos court'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            () => showLongRestDialog(
                              context,
                              doc: doc,
                              maxHp: maxHp,
                              hitDieSides: hitDieSides,
                            ),
                        child: const Text('Repos long'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> _askAmount(BuildContext context, String title) {
  final field = TextEditingController();
  int? parse() => int.tryParse(field.text.trim());
  return showDialog<int>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            key: const Key('hp-amount-field'),
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onSubmitted: (_) => Navigator.pop(context, parse()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, parse()),
              child: const Text('Valider'),
            ),
          ],
        ),
  );
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.scores});

  final AbilityScores scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: 'Caractéristiques',
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: [
          for (final a in Ability.values)
            Container(
              decoration: _card,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    abilityLabel(a).substring(0, 3).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    '${scores[a]}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _signed(abilityModifier(scores[a])),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste « nom (carac) … modificateur », maîtrises en or avec ★.
class _ModifierList extends StatelessWidget {
  const _ModifierList({
    required this.title,
    required this.rows,
    required this.onRoll,
  });

  final String title;

  /// Nom, caractéristique abrégée (facultative), modificateur, maîtrise.
  final List<(String, String?, int, bool)> rows;

  /// Lance le jet d'une ligne (mêmes champs que [rows]).
  final void Function(String, String?, int, bool) onRoll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: '$title (★ = maîtrisé)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: _card,
        child: Column(
          children: [
            for (final (i, (name, ability, modifier, proficient))
                in rows.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  border:
                      i == rows.length - 1
                          ? null
                          : const Border(
                            bottom: BorderSide(color: AppTheme.border),
                          ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: proficient ? '$name ★' : name,
                          children: [
                            if (ability != null)
                              TextSpan(
                                text: ' ($ability)',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              proficient
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      _signed(modifier),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            proficient ? AppTheme.accent : AppTheme.textMuted,
                        fontWeight: proficient ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Lancer : $name',
                      iconSize: 14,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.casino_outlined,
                        color:
                            proficient ? AppTheme.accent : AppTheme.textMuted,
                      ),
                      onPressed:
                          () => onRoll(name, ability, modifier, proficient),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Onglet Actions (`CharSheetActions.dc.html`) : incantation, attaques des
/// armes de l'équipement, aptitudes de classe jusqu'au niveau atteint.
/// Conditions, compagnons, actions bonus et réactions viendront avec leurs
/// maquettes.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.cls,
    required this.scores,
    required this.level,
    required this.proficiency,
    required this.weapons,
    required this.onAttack,
  });

  final AdminClassDoc? cls;
  final AbilityScores scores;
  final int level;
  final int proficiency;
  final List<WeaponDef> weapons;

  /// Arme, bonus d'attaque, bonus de dégâts.
  final void Function(WeaponDef, int, int) onAttack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final cls = this.cls;
    final spellAbility =
        cls != null && cls.spellcaster
            ? abilityFromLabel(cls.spellcastingAbility)
            : null;
    final features = [
      for (var i = 0; i < level && i < (cls?.levelFeatures.length ?? 0); i++)
        if (cls!.levelFeatures[i].trim().isNotEmpty)
          (i + 1, cls.levelFeatures[i].trim()),
    ];
    final resources = [
      for (final c in cls?.resourceColumns ?? const <ResourceColumn>[])
        if (c.name.isNotEmpty &&
            level <= c.values.length &&
            !const ['', '—', '-'].contains(c.values[level - 1].trim()))
          (c.name, c.values[level - 1].trim()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spellAbility != null) ...[
          _SpellcastingBlock(
            cls: cls!,
            ability: spellAbility,
            scores: scores,
            proficiency: proficiency,
          ),
          const SizedBox(height: 16),
        ],
        _Section(
          title: 'Attaques',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (weapons.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _card,
                  child: Text("Aucune arme dans l'équipement.", style: muted),
                ),
              for (final w in weapons)
                if (weaponAttack(w, scores, proficiency) case (
                  _,
                  final attack,
                  final damage,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: _card,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name, style: theme.textTheme.titleSmall),
                                Text(
                                  w.ranged ? 'DISTANCE' : 'CAC',
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _signed(attack),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${w.damage}'
                                '${damage == 0 ? '' : _signed(damage)} '
                                '${w.damageType}',
                                style: muted,
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          IconButton.outlined(
                            tooltip: 'Attaquer : ${w.name}',
                            icon: const Icon(
                              Icons.casino_outlined,
                              color: AppTheme.accent,
                            ),
                            onPressed: () => onAttack(w, attack, damage),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (resources.isNotEmpty || features.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Section(
            title: 'Aptitudes de classe',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (name, v) in resources)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name),
                                Text(cls!.recovery, style: muted),
                              ],
                            ),
                          ),
                          Text(
                            v,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final (lvl, text) in features)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text.rich(
                        TextSpan(
                          text: 'Niv. $lvl — ',
                          style: const TextStyle(color: AppTheme.textMuted),
                          children: [
                            TextSpan(
                              text: text,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
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
        ],
      ],
    );
  }
}
