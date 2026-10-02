part of 'character_sheet_screen.dart';

/// Onglet Notes (`CharSheetNotes.dc.html`) : personnalité, historique et
/// alliés, enregistrés peu après la frappe ; notes de session privées
/// (`users/{uid}/notes`, que le MJ ne lit pas). La chronique partagée est
/// sur la page de la table.
class _Notes extends ConsumerStatefulWidget {
  const _Notes({super.key, required this.doc});

  final CharacterDoc doc;

  @override
  ConsumerState<_Notes> createState() => _NotesState();
}

class _NotesState extends ConsumerState<_Notes> {
  late final _fields = {
    'Trait de personnalité': TextEditingController(
      text: widget.doc.personalityTrait,
    ),
    'Idéal': TextEditingController(text: widget.doc.ideal),
    'Lien': TextEditingController(text: widget.doc.bond),
    'Défaut': TextEditingController(text: widget.doc.flaw),
    'Historique': TextEditingController(text: widget.doc.backstory),
    'Alliés & organisations': TextEditingController(text: widget.doc.allies),
  };
  late final _controller = ref.read(charactersControllerProvider);
  Timer? _pending;

  String _text(String label) => _fields[label]!.text.trim();

  void _save() {
    _pending = null;
    _controller.save(
      widget.doc.copyWith(
        personalityTrait: _text('Trait de personnalité'),
        ideal: _text('Idéal'),
        bond: _text('Lien'),
        flaw: _text('Défaut'),
        backstory: _text('Historique'),
        allies: _text('Alliés & organisations'),
      ),
    );
  }

  void _changed(String _) {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 800), _save);
  }

  @override
  void dispose() {
    // Changer d'onglet ou quitter la fiche n'efface pas la dernière frappe.
    if (_pending != null) {
      _pending!.cancel();
      _save();
    }
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String label, {int lines = 2, int max = 500}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: Key('note-field-$label'),
      controller: _fields[label],
      minLines: lines,
      maxLines: null,
      maxLength: max,
      onChanged: _changed,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    final notes = ref.watch(characterNotesProvider(widget.doc.id)).value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Personnalité',
          child: Column(
            children: [
              _field('Trait de personnalité'),
              _field('Idéal'),
              _field('Lien'),
              _field('Défaut'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Historique',
          child: _field('Historique', lines: 4, max: 4000),
        ),
        _Section(
          title: 'Alliés & organisations',
          child: _field('Alliés & organisations', lines: 3, max: 2000),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'NOTES DE SESSION (PRIVÉES, VISIBLES PAR TOI SEUL·E)',
                style: muted,
              ),
            ),
            TextButton(
              onPressed: () => _showAddNote(context, widget.doc.id),
              child: const Text('+ Nouvelle note'),
            ),
          ],
        ),
        if (notes.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _card,
            child: Text('Aucune note pour le moment.', style: muted),
          ),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: _card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_noteDate(n.createdAt), style: muted),
                        const SizedBox(height: 4),
                        Text(n.text),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer la note',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _controller.deleteNote(n.id),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _noteDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Nouvelle note (`CharSheetAddNote.dc.html`).
Future<void> _showAddNote(BuildContext context, String characterId) =>
    showDialog<void>(
      context: context,
      builder: (context) => _AddNoteDialog(characterId: characterId),
    );

class _AddNoteDialog extends ConsumerStatefulWidget {
  const _AddNoteDialog({required this.characterId});

  final String characterId;

  @override
  ConsumerState<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends ConsumerState<_AddNoteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle note'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes privées — visibles par toi seul·e, jamais par ton MJ ni '
              'les autres joueurs.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('new-note-field'),
              controller: _text,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
              decoration: const InputDecoration(
                hintText: 'Un indice, une intention, une question pour le MJ…',
              ),
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
        onPressed: () {
          if (_text.text.trim().isEmpty) return;
          ref
              .read(charactersControllerProvider)
              .addNote(widget.characterId, _text.text);
          Navigator.pop(context);
        },
        child: const Text('Ajouter'),
      ),
    ],
  );
}
