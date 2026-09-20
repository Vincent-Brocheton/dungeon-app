import 'dart:async';

import 'admin_subspecies_doc.dart';
import 'admin_subspecies_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminSubspeciesRepository implements AdminSubspeciesRepository {
  InMemoryAdminSubspeciesRepository({
    Iterable<AdminSubspeciesDoc> seed = const [],
  }) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, AdminSubspeciesDoc>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<AdminSubspeciesDoc>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(AdminSubspeciesDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-subspecies-${++_counter}';
}
