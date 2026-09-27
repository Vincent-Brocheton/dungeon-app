import 'dart:async';

import 'admin_npc_doc.dart';
import 'admin_npc_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminNpcRepository implements AdminNpcRepository {
  InMemoryAdminNpcRepository({Iterable<AdminNpcDoc> seed = const []}) {
    for (final doc in seed) {
      _docs.putIfAbsent(doc.id, () => doc);
    }
  }

  final _docs = <String, AdminNpcDoc>{};
  final _controller = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Stream<List<AdminNpcDoc>> watchAll() async* {
    yield _docs.values.toList();
    yield* _controller.stream.map((_) => _docs.values.toList());
  }

  @override
  Future<void> upsert(AdminNpcDoc doc) async {
    _docs[doc.id] = doc;
    _controller.add(null);
  }

  @override
  String newId() => 'local-npc-${++_counter}';
}
