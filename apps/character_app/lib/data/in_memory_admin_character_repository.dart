import 'dart:async';

import 'admin_character_entry.dart';
import 'admin_character_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminCharacterRepository implements AdminCharacterRepository {
  InMemoryAdminCharacterRepository({
    Iterable<AdminCharacterEntry> seed = const [],
  }) : _entries = [...seed];

  final List<AdminCharacterEntry> _entries;
  final _controller = StreamController<void>.broadcast();

  List<AdminCharacterEntry> _visible() =>
      (_entries.where((e) => !e.doc.isDeleted).toList()
        ..sort((a, b) => b.doc.updatedAt.compareTo(a.doc.updatedAt)));

  @override
  Stream<List<AdminCharacterEntry>> watchAllCharacters() async* {
    yield _visible();
    yield* _controller.stream.map((_) => _visible());
  }
}
