import 'dart:async';

import 'admin_table_doc.dart';
import 'admin_table_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminTableRepository implements AdminTableRepository {
  InMemoryAdminTableRepository({AdminTableDoc? seed}) : _doc = seed;

  AdminTableDoc? _doc;
  final _controller = StreamController<void>.broadcast();

  @override
  Stream<AdminTableDoc?> watch() async* {
    yield _doc;
    yield* _controller.stream.map((_) => _doc);
  }

  @override
  Future<void> save(AdminTableDoc doc) async {
    _doc = doc;
    _controller.add(null);
  }
}
