import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/admin_character_entry.dart';
import '../../data/admin_table_doc.dart';
import '../../data/table_membership.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../table/table_providers.dart';
import 'admin_form_fields.dart';
import 'admin_providers.dart';

/// Brouillon éditable d'une règle maison ou d'une entrée (séance, journal) ;
/// `uid` identifie ses champs même quand une ligne précédente est retirée.
class _Draft {
  _Draft({this.title = '', this.text = '', this.enabled = true})
    : uid = _nextUid++;

  static var _nextUid = 0;

  final int uid;
  String title;
  String text;
  bool enabled;
}

/// « Ma table » : paramètres de la campagne, règles maison et de repos,
/// joueurs (déduits des personnages existants), planning des séances et
/// journal privé du MJ. Reprend `TableManagementNoModal.dc.html` — sans
/// sidebar, sans les invitations (bouton présent, annonce juste qu'elles
/// arrivent : il faut d'abord un parcours pour rejoindre une table) ni la
/// chronique partagée écrite par les joueurs.
class AdminTableScreen extends ConsumerStatefulWidget {
  const AdminTableScreen({super.key});

  @override
  ConsumerState<AdminTableScreen> createState() => _AdminTableScreenState();
}

class _AdminTableScreenState extends ConsumerState<AdminTableScreen> {
  var _loaded = false;
  var _saving = false;

  final _texts = {
    for (final key in AdminTableDoc.textFields) key: TextEditingController(),
  };
  final _maxShortRests = TextEditingController();
  var _houseRules = <_Draft>[];
  var _restVariant = 'Standard';
  var _hitDiceRecovery = AdminTableDoc.hitDiceRecoveries.first;
  var _interruptedLongRest = AdminTableDoc.interruptedLongRests.first;
  var _diceRollsInApp = true;
  var _sessions = <_Draft>[];
  var _journal = <_Draft>[];

  @override
  void dispose() {
    for (final controller in [..._texts.values, _maxShortRests]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(AdminTableDoc doc) {
    final map = doc.toMap();
    for (final key in AdminTableDoc.textFields) {
      _texts[key]!.text = map[key]! as String;
    }
    _maxShortRests.text = '${doc.maxShortRests}';
    _houseRules = [
      for (final r in doc.houseRules) _Draft(title: r.name, enabled: r.enabled),
    ];
    _restVariant = doc.restVariant;
    _hitDiceRecovery = doc.hitDiceRecovery;
    _interruptedLongRest = doc.interruptedLongRest;
    _diceRollsInApp = doc.diceRollsInApp;
    _sessions = [
      for (final s in doc.sessions) _Draft(title: s.title, text: s.text),
    ];
    _journal = [
      for (final j in doc.journal) _Draft(title: j.title, text: j.text),
    ];
    _loaded = true;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_texts['name']!.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Donne un nom à la campagne')),
      );
      return;
    }
    List<TableEntry> entries(List<_Draft> drafts) => [
      for (final d in drafts)
        TableEntry(title: d.title.trim(), text: d.text.trim()),
    ];
    setState(() => _saving = true);
    try {
      await ref
          .read(adminTableRepositoryProvider)
          .save(
            AdminTableDoc.fromMap({
              for (final key in AdminTableDoc.textFields)
                key: _texts[key]!.text.trim(),
              'maxShortRests': int.tryParse(_maxShortRests.text.trim()) ?? 2,
              'houseRules': [
                for (final r in _houseRules)
                  if (r.title.trim().isNotEmpty)
                    HouseRule(name: r.title.trim(), enabled: r.enabled).toMap(),
              ],
              'restVariant': _restVariant,
              'hitDiceRecovery': _hitDiceRecovery,
              'interruptedLongRest': _interruptedLongRest,
              'diceRollsInApp': _diceRollsInApp,
              'sessions': [for (final e in entries(_sessions)) e.toMap()],
              'journal': [for (final e in entries(_journal)) e.toMap()],
              'updatedAt': DateTime.now(),
            }),
          );
      // Copie pour les joueurs, sans le journal ni les règles internes.
      await ref
          .read(tableMembershipRepositoryProvider)
          .publish(
            TablePublicInfo(
              name: _texts['name']!.text.trim(),
              world: _texts['world']!.text.trim(),
              cadence: _texts['cadence']!.text.trim(),
              nextSessionWhen: _texts['nextSessionWhen']!.text.trim(),
              nextSessionWhere: _texts['nextSessionWhere']!.text.trim(),
              nextSessionNote: _texts['nextSessionNote']!.text.trim(),
            ),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(adminTableProvider);
    final characters = ref.watch(allCharactersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma table'),
        actions: [
          IconButton(
            tooltip: 'Chronique de la table',
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () => context.push(AppRoutes.chronicle),
          ),
          IconButton(
            tooltip: 'Réserve du groupe',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => context.push(AppRoutes.treasury),
          ),
          IconButton(
            tooltip: 'Historique des jets',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.adminRolls),
          ),
        ],
      ),
      body: table.when(
        data: (doc) {
          // Premier affichage : la table enregistrée, sinon une table vide.
          if (!_loaded) _load(doc ?? AdminTableDoc(updatedAt: DateTime.now()));
          return _buildBody(characters);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(child: Text('Chargement impossible : $error')),
      ),
    );
  }

  Widget _buildBody(List<AdminCharacterEntry> characters) {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 14);
    const vgap = SizedBox(height: 16);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );

    Widget text(String key, String label, {String? hint}) => AdminLabeledField(
      key: Key('table-$key-field'),
      label: label,
      controller: _texts[key]!,
      hint: hint,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Stat(
                      label: 'Joueurs actifs',
                      value:
                          '${characters.map((c) => c.ownerUid).toSet().length}',
                    ),
                    _Stat(
                      label: 'Séances jouées',
                      value: '${_sessions.length}',
                    ),
                    _Stat(
                      label: 'Prochaine séance',
                      value:
                          _texts['nextSessionWhen']!.text.trim().isEmpty
                              ? '—'
                              : _texts['nextSessionWhen']!.text.trim(),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
          vgap,
          _Section(
            title: 'Paramètres de la table',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: text('name', 'Nom de la campagne')),
                    gap,
                    Expanded(child: text('world', 'Monde / cadre')),
                    gap,
                    Expanded(
                      child: text(
                        'cadence',
                        'Rythme des séances',
                        hint: 'ex. Toutes les 2 semaines, dimanche 19h',
                      ),
                    ),
                  ],
                ),
                vgap,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('RÈGLES MAISON ACTIVES', style: muted),
                ),
                for (var i = 0; i < _houseRules.length; i++)
                  KeyedSubtree(
                    key: ValueKey('rule-${_houseRules[i].uid}'),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _houseRules[i].enabled,
                          onChanged:
                              (v) => setState(
                                () => _houseRules[i].enabled = v ?? false,
                              ),
                        ),
                        Expanded(
                          child: TextFormField(
                            key: Key('house-rule-$i'),
                            initialValue: _houseRules[i].title,
                            onChanged: (v) => _houseRules[i].title = v,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'ex. Points de destin',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed:
                              () => setState(() => _houseRules.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _houseRules.add(_Draft())),
                    child: const Text('+ Ajouter une règle'),
                  ),
                ),
              ],
            ),
          ),
          vgap,
          _Section(
            title: 'Règles de repos',
            subtitle: "s'appliquent à tous les joueurs de la table",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final (variant, detail) in AdminTableDoc.restVariants)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _Choice(
                            label: variant,
                            detail: detail,
                            selected: variant == _restVariant,
                            onTap: () => setState(() => _restVariant = variant),
                          ),
                        ),
                      ),
                  ],
                ),
                vgap,
                Row(
                  children: [
                    Expanded(
                      child: AdminLabeledField(
                        label: 'Repos courts max. par repos long',
                        controller: _maxShortRests,
                      ),
                    ),
                    gap,
                    Expanded(
                      child: AdminLabeledDropdown<String>(
                        label: 'Dés de vie récupérés en repos long',
                        value: _hitDiceRecovery,
                        items: AdminTableDoc.hitDiceRecoveries,
                        labelOf: (s) => s,
                        onChanged: (s) => setState(() => _hitDiceRecovery = s),
                      ),
                    ),
                    gap,
                    Expanded(
                      child: AdminLabeledDropdown<String>(
                        label: 'Si le repos long est interrompu',
                        value: _interruptedLongRest,
                        items: AdminTableDoc.interruptedLongRests,
                        labelOf: (s) => s,
                        onChanged:
                            (s) => setState(() => _interruptedLongRest = s),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          vgap,
          _Section(
            title: 'Jets de dés',
            child: Row(
              children: [
                Switch(
                  key: const Key('table-dice-switch'),
                  value: _diceRollsInApp,
                  onChanged: (v) => setState(() => _diceRollsInApp = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Autoriser les jets de dés dans l'application",
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Sinon, les joueurs lancent leurs dés physiques et '
                        'renseignent eux-mêmes le résultat sur leur fiche.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          vgap,
          _Section(
            title: 'Joueurs',
            subtitle: 'déduits des personnages créés',
            child: Column(
              children: [
                if (characters.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Aucun personnage pour l\'instant',
                      style: muted,
                    ),
                  ),
                for (final c in characters)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            c.doc.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: Text('Niv. ${c.doc.level}', style: muted),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Joueur ${c.ownerUid}',
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          vgap,
          _Section(
            title: 'Invitations & joueurs',
            subtitle: 'un code par invitation, révocable',
            child: _Invitations(
              tableName: _texts['name']!.text.trim(),
              tableWorld: _texts['world']!.text.trim(),
            ),
          ),
          vgap,
          _Section(
            title: 'Planning des séances',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: text(
                        'nextSessionWhen',
                        'Prochaine séance',
                        hint: 'ex. Dimanche 12 octobre, 19h00',
                      ),
                    ),
                    gap,
                    Expanded(
                      child: text(
                        'nextSessionWhere',
                        'Lieu',
                        hint: 'ex. Discord',
                      ),
                    ),
                    gap,
                    Expanded(child: text('nextSessionNote', 'Note')),
                  ],
                ),
                vgap,
                _EntriesPanel(
                  section: 'session',
                  title: 'Historique',
                  addLabel: '+ Ajouter une séance',
                  titleHint: 'ex. Séance 12 — 28 sept.',
                  entries: _sessions,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          vgap,
          _Section(
            title: 'Journal de session',
            subtitle: 'notes MJ, visibles de toi seul',
            child: _EntriesPanel(
              section: 'journal',
              title: 'Entrées',
              addLabel: '+ Nouvelle entrée',
              titleHint: 'ex. Séance 12 · 28 sept.',
              entries: _journal,
              onChanged: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: title,
              style: theme.textTheme.titleSmall,
              children: [
                if (subtitle != null)
                  TextSpan(
                    text: '  ($subtitle)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              detail,
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

/// Entrées titrées ajoutables/retirables, la plus récente en haut. Champs
/// clés `<section>-title-<i>` et `<section>-text-<i>`.
class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel({
    required this.section,
    required this.title,
    required this.addLabel,
    required this.titleHint,
    required this.entries,
    required this.onChanged,
  });

  final String section;
  final String title;
  final String addLabel;
  final String titleHint;
  final List<_Draft> entries;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
              onPressed: () {
                entries.insert(0, _Draft());
                onChanged();
              },
              child: Text(addLabel),
            ),
          ],
        ),
        for (var i = 0; i < entries.length; i++)
          Container(
            key: ValueKey('$section-${entries[i].uid}'),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: Key('$section-title-$i'),
                        initialValue: entries[i].title,
                        onChanged: (v) => entries[i].title = v,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: titleHint,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        entries.removeAt(i);
                        onChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: Key('$section-text-$i'),
                  initialValue: entries[i].text,
                  onChanged: (v) => entries[i].text = v,
                  maxLines: 3,
                  decoration: const InputDecoration(isDense: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lien d'invitation : sur le web, l'adresse de l'app suivie de
/// `/join/CODE` ; ailleurs, le code seul, à saisir dans Réglages.
String inviteLink(String code) =>
    kIsWeb ? '${Uri.base.origin}/join/$code' : code;

/// Invitations (`TableInvite`) et joueurs entrés à la table : générer un
/// code, le copier, le révoquer ; retirer un joueur.
class _Invitations extends ConsumerWidget {
  const _Invitations({required this.tableName, required this.tableWorld});

  final String tableName;
  final String tableWorld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(tableMembershipRepositoryProvider);
    final invites = ref.watch(tableInvitesProvider).value ?? const [];
    final members = ref.watch(tableMembersProvider).value ?? const [];
    const muted = TextStyle(color: AppTheme.textMuted);

    Future<void> copy(String code) async {
      await Clipboard.setData(ClipboardData(text: inviteLink(code)));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Copié : ${inviteLink(code)}')));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed:
                tableName.isEmpty
                    ? null
                    : () => repo.createInvite(
                      TableInvite(
                        code: TableInvite.newCode(),
                        tableName: tableName,
                        tableWorld: tableWorld,
                        createdAt: DateTime.now(),
                      ),
                    ),
            icon: const Icon(Icons.add_link),
            label: const Text('Générer une invitation'),
          ),
        ),
        if (tableName.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Donne un nom à la campagne d’abord.', style: muted),
          ),
        const SizedBox(height: 8),
        if (invites.isEmpty)
          const Text('Aucune invitation active.', style: muted),
        for (final i in invites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: SelectableText(i.code, key: Key('invite-${i.code}')),
            subtitle: Text(
              kIsWeb ? inviteLink(i.code) : 'Code à saisir dans Réglages',
              style: muted,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copier le lien',
                  icon: const Icon(Icons.copy),
                  onPressed: () => copy(i.code),
                ),
                IconButton(
                  tooltip: 'Révoquer ${i.code}',
                  icon: const Icon(Icons.link_off),
                  onPressed: () => repo.revokeInvite(i.code),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Text(
          'Joueurs à la table (${members.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Personne n’a encore rejoint la table.', style: muted),
          ),
        for (final m in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              m.characterName.isEmpty ? 'Sans personnage' : m.characterName,
            ),
            subtitle: Text(
              m.characterSummary.isEmpty
                  ? 'Joueur ${m.uid}'
                  : m.characterSummary,
              style: muted,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Retirer de la table',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () => repo.leave(m.uid),
            ),
          ),
      ],
    );
  }
}
