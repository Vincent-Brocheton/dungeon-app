import 'dart:async';

import 'admin_character_entry.dart';
import 'admin_character_repository.dart';
import 'character_doc.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminCharacterRepository implements AdminCharacterRepository {
  InMemoryAdminCharacterRepository({
    Iterable<AdminCharacterEntry> seed = const [],
    Iterable<RollRecord> rolls = const [],
  }) : _entries = [...seed],
       _rolls = [...rolls];

  final List<RollRecord> _rolls;

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

  @override
  Stream<List<RollRecord>> watchAllRolls() => Stream.value(
    _rolls.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
}
