import 'dart:async';

import 'admin_invocation_doc.dart';
import 'admin_invocation_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminInvocationRepository implements AdminInvocationRepository {
  InMemoryAdminInvocationRepository({
    Iterable<AdminInvocationDoc> seed = const [],
  }) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, AdminInvocationDoc>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<AdminInvocationDoc>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(AdminInvocationDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-invocation-${++_counter}';
}
