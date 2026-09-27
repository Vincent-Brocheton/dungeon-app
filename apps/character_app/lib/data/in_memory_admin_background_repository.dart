import 'dart:async';

import 'admin_background_doc.dart';
import 'admin_background_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminBackgroundRepository implements AdminBackgroundRepository {
  InMemoryAdminBackgroundRepository({
    Iterable<AdminBackgroundDoc> seed = const [],
  }) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, AdminBackgroundDoc>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<AdminBackgroundDoc>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(AdminBackgroundDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-background-${++_counter}';
}
