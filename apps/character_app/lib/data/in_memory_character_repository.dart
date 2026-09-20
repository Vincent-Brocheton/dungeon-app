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
  Future<void> deleteAll(String uid) async {
    _docs.clear();
    _controller.add(null);
  }

  @override
  String newId() => 'local-${++_counter}';
}
