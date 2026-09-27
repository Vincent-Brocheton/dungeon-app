import 'dart:async';

import 'admin_subclass_doc.dart';
import 'admin_subclass_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminSubclassRepository implements AdminSubclassRepository {
  InMemoryAdminSubclassRepository({
    Iterable<AdminSubclassDoc> seed = const [],
  }) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, AdminSubclassDoc>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<AdminSubclassDoc>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(AdminSubclassDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-subclass-${++_counter}';
}
