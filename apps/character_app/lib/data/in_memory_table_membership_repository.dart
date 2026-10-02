import 'dart:async';

import 'table_membership.dart';

/// Implémentation en mémoire : tests de widgets et développement sans
/// Firebase. Comme Firestore, `join` est refusé sans invitation valide.
class InMemoryTableMembershipRepository implements TableMembershipRepository {
  InMemoryTableMembershipRepository({
    TablePublicInfo? public,
    Iterable<TableInvite> invites = const [],
    Iterable<TableMember> members = const [],
    Iterable<ChronicleEntry> chronicle = const [],
  }) : _public = public {
    for (final e in chronicle) {
      _chronicle[e.id] = e;
    }
    for (final i in invites) {
      _invites[i.code] = i;
    }
    for (final m in members) {
      _members[m.uid] = m;
    }
  }

  TablePublicInfo? _public;
  final _invites = <String, TableInvite>{};
  final _members = <String, TableMember>{};
  final _chronicle = <String, ChronicleEntry>{};
  var _nextId = 0;
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Stream<TablePublicInfo?> watchPublic() => _watch(() => _public);

  @override
  Future<void> publish(TablePublicInfo info) async {
    _public = info;
    _changes.add(null);
  }

  @override
  Future<TableInvite?> getInvite(String code) async => _invites[code];

  @override
  Stream<List<TableInvite>> watchInvites() => _watch(
    () =>
        _invites.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> createInvite(TableInvite invite) async {
    _invites[invite.code] = invite;
    _changes.add(null);
  }

  @override
  Future<void> revokeInvite(String code) async {
    _invites.remove(code);
    _changes.add(null);
  }

  @override
  Stream<TableMember?> watchMember(String uid) => _watch(() => _members[uid]);

  @override
  Stream<List<TableMember>> watchMembers() => _watch(
    () =>
        _members.values.toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt)),
  );

  @override
  Future<void> join(TableMember member) async {
    final current = _members[member.uid];
    // Règle Firestore : invitation existante, sauf code inchangé d'un membre.
    if (!_invites.containsKey(member.inviteCode) &&
        current?.inviteCode != member.inviteCode) {
      throw StateError('Invitation invalide ou révoquée');
    }
    _members[member.uid] = member;
    _changes.add(null);
  }

  @override
  Future<void> leave(String uid) async {
    _members.remove(uid);
    _changes.add(null);
  }

  @override
  Stream<List<ChronicleEntry>> watchChronicle() => _watch(
    () =>
        _chronicle.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> saveChronicle(ChronicleEntry entry) async {
    final id = entry.id.isEmpty ? 'c${_nextId++}' : entry.id;
    _chronicle[id] = ChronicleEntry.fromMap(id, entry.toMap());
    _changes.add(null);
  }

  @override
  Future<void> deleteChronicle(String id) async {
    _chronicle.remove(id);
    _changes.add(null);
  }
}
