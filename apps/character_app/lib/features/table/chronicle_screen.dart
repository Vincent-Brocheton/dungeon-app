import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/table_membership.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../auth/auth_providers.dart';
import 'table_providers.dart';

String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Chronique partagée (`TableChronicle`) : quêtes, rencontres et notes de la
/// table, filtrables et groupées par jour. Membres et MJ publient ; l'auteur
/// ou le MJ change l'état d'une quête et supprime.
class ChronicleScreen extends ConsumerStatefulWidget {
  const ChronicleScreen({super.key});

  @override
  ConsumerState<ChronicleScreen> createState() => _ChronicleScreenState();
}

class _ChronicleScreenState extends ConsumerState<ChronicleScreen> {
  ChronicleKind? _filter;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myMembershipProvider).value;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final uid = ref.watch(currentUidProvider);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    if (me == null && !isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chronique')),
        body: Center(
          child: Text(
            'Rejoins une table pour lire sa chronique.',
            style: muted,
          ),
        ),
      );
    }
    final author =
        me == null
            ? 'MJ'
            : (me.characterName.isEmpty ? 'Joueur' : me.characterName);
    final repo = ref.read(tableMembershipRepositoryProvider);
    final entries = [
      for (final e
          in ref.watch(tableChronicleProvider).value ?? <ChronicleEntry>[])
        if (_filter == null || e.kind == _filter) e,
    ];

    final children = <Widget>[];
    String? lastDay;
    for (final e in entries) {
      final day = _day(e.createdAt);
      if (day != lastDay) {
        lastDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(day, style: muted),
          ),
        );
      }
      children.add(
        _EntryCard(
          entry: e,
          canEdit: isAdmin || e.authorUid == uid,
          onStatus: (s) => repo.saveChronicle(e.withStatus(s)),
          onDelete: () => repo.deleteChronicle(e.id),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chronique')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => showDialog<void>(
              context: context,
              builder: (context) => _AddEntryDialog(author: author),
            ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, kind) in [
                    ('Tout', null),
                    ('Quêtes', ChronicleKind.quest),
                    ('Rencontres', ChronicleKind.encounter),
                    ('Notes', ChronicleKind.note),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                    ),
                ],
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Rien dans la chronique pour l’instant.',
                    style: muted,
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.canEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final ChronicleEntry entry;
  final bool canEdit;
  final ValueChanged<QuestStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final status = entry.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    entry.kind.label.toUpperCase(),
                    if (status != null) status.label,
                  ].join(' · '),
                  style: muted,
                ),
                const SizedBox(height: 2),
                Text(entry.title, style: theme.textTheme.titleSmall),
                if (entry.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.text),
                ],
                const SizedBox(height: 6),
                Text('Ajouté par ${entry.authorName}', style: muted),
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<Object>(
              tooltip: 'Actions sur ${entry.title}',
              onSelected: (v) => v is QuestStatus ? onStatus(v) : onDelete(),
              itemBuilder:
                  (context) => [
                    if (entry.kind == ChronicleKind.quest)
                      for (final s in QuestStatus.values)
                        if (s != status)
                          PopupMenuItem(value: s, child: Text(s.label)),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

/// Ajouter à la chronique (`TableChronicleAdd`).
class _AddEntryDialog extends ConsumerStatefulWidget {
  const _AddEntryDialog({required this.author});

  final String author;

  @override
  ConsumerState<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends ConsumerState<_AddEntryDialog> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  var _kind = ChronicleKind.quest;
  var _status = QuestStatus.ongoing;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _publish() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    ref
        .read(tableMembershipRepositoryProvider)
        .saveChronicle(
          ChronicleEntry(
            id: '',
            kind: _kind,
            status: _kind == ChronicleKind.quest ? _status : null,
            title: title,
            text: _text.text.trim(),
            authorUid: ref.read(currentUidProvider)!,
            authorName: widget.author,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter à la chronique'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final k in ChronicleKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            if (_kind == ChronicleKind.quest) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in QuestStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('chronicle-title'),
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            TextField(
              key: const Key('chronicle-text'),
              controller: _text,
              minLines: 3,
              maxLines: 8,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            Text(
              'Visible par tous les joueurs de la table et par le MJ, avec '
              '« ${widget.author} » comme auteur.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _publish,
        child: const Text('Publier à la table'),
      ),
    ],
  );
}
