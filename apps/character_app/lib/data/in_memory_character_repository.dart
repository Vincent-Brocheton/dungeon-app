import 'dart:async';

import 'character_doc.dart';
import 'character_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryCharacterRepository implements CharacterRepository {
  InMemoryCharacterRepository({Iterable<CharacterDoc> seed = const []}) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, CharacterDoc>{};
  final _notes = <String, CharacterNote>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  List<CharacterDoc> _visible() =>
      (_docs.values.where((d) => !d.isDeleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  @override
  Stream<List<CharacterDoc>> watchAll(String uid) async* {
    yield _visible();
    yield* _controller.stream.map((_) => _visible());
  }

  @override
  Future<void> upsert(String uid, CharacterDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  Future<void> softDelete(String uid, String id) async {
    final doc = _docs[id];
    if (doc == null) return;
    final now = DateTime.now();
    _docs[id] = doc.copyWith(deletedAt: now, updatedAt: now);
    _controller.add(null);
  }

  @override
  Stream<List<CharacterNote>> watchNotes(
    String uid,
    String characterId,
  ) async* {
    List<CharacterNote> notes() => [
      for (final n in _notes.values)
        if (n.characterId == characterId) n,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield notes();
    yield* _controller.stream.map((_) => notes());
  }

  @override
  Future<void> addNote(String uid, CharacterNote note) async {
    _notes[note.id] = note;
    _controller.add(null);
  }

  @override
  Future<void> deleteNote(String uid, String noteId) async {
    _notes.remove(noteId);
    _controller.add(null);
  }

  /// Notes enregistrées, pour les tests.
  Iterable<CharacterNote> get notes => _notes.values;

  @override
  Future<void> deleteAll(String uid) async {
    _docs.clear();
    _notes.clear();
    _controller.add(null);
  }

  @override
  String newId() => 'local-${++_counter}';
}
