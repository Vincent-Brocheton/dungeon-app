import 'dart:async';

import 'content_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryContentRepository<T extends ContentDoc>
    implements ContentRepository<T> {
  InMemoryContentRepository({Iterable<T> seed = const []}) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, T>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<T>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(T doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-${++_counter}';
}
