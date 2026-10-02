import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/character_doc.dart';
import '../../data/table_membership.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../auth/auth_providers.dart';
import '../characters/characters_providers.dart';
import 'table_providers.dart';

/// « Clerc 5 » d'un personnage, d'après la liste des classes.
String _summary(WidgetRef ref, CharacterDoc c) {
  final cls =
      ref
          .watch(allClassesProvider)
          .value
          ?.where((k) => k.id == c.classId)
          .firstOrNull;
  return cls == null ? 'Niveau ${c.level}' : '${cls.name} ${c.level}';
}

/// Adhésion de l'utilisateur courant avec ce personnage (ou sans).
TableMember _membership(
  WidgetRef ref,
  String code,
  CharacterDoc? character, {
  DateTime? joinedAt,
}) => TableMember(
  uid: ref.read(currentUidProvider)!,
  inviteCode: code,
  joinedAt: joinedAt ?? DateTime.now(),
  characterId: character?.id,
  characterName: character?.name ?? '',
  characterSummary: character == null ? '' : _summary(ref, character),
);

/// Rejoindre la table par une invitation (`TableInvite`,
/// `TableJoinCharacter`, `TableJoinWelcome`) : aperçu de la table, choix du
/// personnage (ou aucun pour l'instant), puis bienvenue.
class JoinTableScreen extends ConsumerStatefulWidget {
  const JoinTableScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinTableScreen> createState() => _JoinTableScreenState();
}

class _JoinTableScreenState extends ConsumerState<JoinTableScreen> {
  late final _code = TableInvite.normalize(widget.code);
  late final _invite = ref
      .read(tableMembershipRepositoryProvider)
      .getInvite(_code);
  var _choosing = false;
  var _joined = false;
  String? _error;

  Future<void> _join(CharacterDoc? character) async {
    try {
      await ref
          .read(tableMembershipRepositoryProvider)
          .join(_membership(ref, _code, character));
      if (mounted) setState(() => _joined = true);
    } on Object {
      // Code révoqué entre l'aperçu et l'entrée (refus des règles).
      if (mounted) {
        setState(() => _error = 'Invitation invalide ou révoquée.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre une table')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<TableInvite?>(
            future: _invite,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final invite = snapshot.data;
              if (invite == null) {
                return _Message(
                  icon: Icons.link_off,
                  title: 'Invitation introuvable',
                  text:
                      'Ce code n’existe pas ou a été révoqué. Demande un '
                      'nouveau lien à ton MJ.',
                  action: 'Retour à mes personnages',
                  onAction: () => context.go(AppRoutes.home),
                );
              }
              if (_joined) {
                return _Message(
                  icon: Icons.check_circle_outline,
                  title: 'Bienvenue à la table !',
                  text: 'Tu as rejoint ${invite.tableName}.',
                  action: 'Voir la table',
                  onAction: () => context.go(AppRoutes.table),
                );
              }
              if (_choosing) {
                return _CharacterPicker(
                  title: 'Choisis ton personnage',
                  subtitle: 'Table : ${invite.tableName}',
                  error: _error,
                  onPick: _join,
                );
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Tu es invité·e à rejoindre une table',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.tableName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (invite.tableWorld.isNotEmpty)
                          Text(invite.tableWorld, style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(() => _choosing = true),
                    child: const Text('Rejoindre la table'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Liste des personnages vivants pour la table, ou « sans personnage ».
class _CharacterPicker extends ConsumerWidget {
  const _CharacterPicker({
    required this.title,
    required this.subtitle,
    required this.onPick,
    this.error,
  });

  final String title;
  final String subtitle;
  final String? error;
  final void Function(CharacterDoc?) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = [
      for (final c in ref.watch(myCharactersProvider).value ?? <CharacterDoc>[])
        if (!c.isDead) c,
    ];
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle, style: muted),
        if (error case final e?) ...[
          const SizedBox(height: 12),
          Text(e, style: const TextStyle(color: Color(0xFFE0806A))),
        ],
        const SizedBox(height: 16),
        if (characters.isEmpty)
          Text('Tu n’as pas encore de personnage sur ce compte.', style: muted),
        for (final c in characters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppTheme.border),
                borderRadius: BorderRadius.circular(10),
              ),
              title: Text(c.name),
              subtitle: Text(_summary(ref, c), style: muted),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPick(c),
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => onPick(null),
          child: const Text('Rejoindre sans personnage pour l’instant'),
        ),
        Text(
          'Tu pourras en créer un et le choisir depuis la page de la table.',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }
}

/// La table côté joueur (`TablePlayerHome`) : infos et prochaine séance, ton
/// personnage (à changer), les autres joueurs, quitter
/// (`TableLeaveConfirm`). Sans table : saisir un code d'invitation.
class TableHomeScreen extends ConsumerWidget {
  const TableHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);
    return membership.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (me) => me == null ? const _NoTable() : _TableHome(me: me),
    );
  }
}

class _NoTable extends StatefulWidget {
  const _NoTable();

  @override
  State<_NoTable> createState() => _NoTableState();
}

class _NoTableState extends State<_NoTable> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _go() {
    final code = TableInvite.normalize(_code.text);
    if (code.isNotEmpty) context.push(AppRoutes.join(code));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ma table')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Tu n’es à aucune table. Saisis le code d’invitation que ton '
              'MJ t’a envoyé, ou ouvre son lien.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('join-code-field'),
              controller: _code,
              maxLength: 16,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code d’invitation',
                hintText: 'K7QX2M9P',
              ),
              onSubmitted: (_) => _go(),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _go, child: const Text('Continuer')),
          ],
        ),
      ),
    ),
  );
}

class _TableHome extends ConsumerWidget {
  const _TableHome({required this.me});

  final TableMember me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(tablePublicProvider).value;
    final others = [
      for (final m in ref.watch(tableMembersProvider).value ?? <TableMember>[])
        if (m.uid != me.uid) m,
    ];
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final repo = ref.read(tableMembershipRepositoryProvider);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text.toUpperCase(), style: muted),
    );
    final next = [
      info?.nextSessionWhen ?? '',
      info?.nextSessionWhere ?? '',
    ].where((t) => t.isNotEmpty).join(' · ');
    final note = info?.nextSessionNote ?? '';

    Future<void> leave() async {
      final who =
          me.characterName.isEmpty ? 'Ton personnage' : me.characterName;
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Quitter cette table'),
              content: Text(
                'Tu ne pourras plus y accéder sans nouvelle invitation. $who '
                'n’est pas supprimé : il reste dans tes personnages.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Quitter la table'),
                ),
              ],
            ),
      );
      if (ok ?? false) await repo.leave(me.uid);
    }

    void changeCharacter() => showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
              child: _CharacterPicker(
                title: 'Changer de personnage',
                subtitle: info?.name ?? '',
                onPick: (c) {
                  repo.join(
                    _membership(ref, me.inviteCode, c, joinedAt: me.joinedAt),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(info?.name ?? 'Ma table')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info?.name ?? 'Table',
                      style: theme.textTheme.titleMedium,
                    ),
                    if ((info?.world ?? '').isNotEmpty)
                      Text(info!.world, style: muted),
                    if ((info?.cadence ?? '').isNotEmpty)
                      Text(info!.cadence, style: muted),
                  ],
                ),
              ),
              if (next.isNotEmpty || note.isNotEmpty) ...[
                title('Prochaine séance'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (next.isNotEmpty) Text(next),
                      if (note.isNotEmpty) Text(note, style: muted),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('Chronique de la table'),
                subtitle: Text('Quêtes, rencontres et notes', style: muted),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.chronicle),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Réserve du groupe'),
                subtitle: Text('Or commun et objets partagés', style: muted),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.treasury),
              ),
              title('Ton personnage à cette table'),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                title: Text(
                  me.characterName.isEmpty
                      ? 'Aucun personnage choisi'
                      : me.characterName,
                ),
                subtitle: Text(me.characterSummary, style: muted),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    me.characterId == null
                        ? null
                        : () =>
                            context.push(AppRoutes.character(me.characterId!)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: changeCharacter,
                  child: const Text('Changer de personnage'),
                ),
              ),
              title('Autres joueurs (${others.length})'),
              if (others.isEmpty)
                Text('Personne d’autre pour l’instant.', style: muted),
              for (final m in others)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.border,
                    child: Text(
                      m.characterName.isEmpty
                          ? '?'
                          : m.characterName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    m.characterName.isEmpty
                        ? 'Sans personnage'
                        : m.characterName,
                  ),
                  subtitle: Text(m.characterSummary, style: muted),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE0806A),
                ),
                onPressed: leave,
                child: const Text('Quitter cette table'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      Icon(icon, size: 56, color: AppTheme.accent),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: onAction, child: Text(action)),
    ],
  );
}
