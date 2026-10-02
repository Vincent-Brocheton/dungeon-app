import 'package:cloud_firestore/cloud_firestore.dart';

import 'table_membership.dart';

/// `tablePublic/main`, `invites/{code}`, `tableMembers/{uid}` et
/// `tableChronicle/{id}`.
class FirestoreTableMembershipRepository implements TableMembershipRepository {
  FirestoreTableMembershipRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _public =>
      _db.collection('tablePublic').doc('main');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');
  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('tableMembers');
  CollectionReference<Map<String, dynamic>> get _chronicle =>
      _db.collection('tableChronicle');

  static Map<String, Object?> _fromFirestore(Map<String, dynamic> map) => {
    for (final e in map.entries)
      e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
  };

  static Map<String, Object?> _toFirestore(Map<String, Object?> map) => {
    for (final e in map.entries)
      e.key:
          e.value is DateTime
              ? Timestamp.fromDate(e.value! as DateTime)
              : e.value,
  };

  @override
  Stream<TablePublicInfo?> watchPublic() => _public.snapshots().map(
    (s) => s.data() == null ? null : TablePublicInfo.fromMap(s.data()!),
  );

  @override
  Future<void> publish(TablePublicInfo info) =>
      _public.set({...info.toMap(), 'updatedAt': Timestamp.now()});

  @override
  Future<TableInvite?> getInvite(String code) async {
    if (code.isEmpty) return null;
    final s = await _invites.doc(code).get();
    final data = s.data();
    return data == null
        ? null
        : TableInvite.fromMap(s.id, _fromFirestore(data));
  }

  @override
  Stream<List<TableInvite>> watchInvites() => _invites.snapshots().map(
    (q) => [
      for (final d in q.docs)
        TableInvite.fromMap(d.id, _fromFirestore(d.data())),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> createInvite(TableInvite invite) =>
      _invites.doc(invite.code).set(_toFirestore(invite.toMap()));

  @override
  Future<void> revokeInvite(String code) => _invites.doc(code).delete();

  @override
  Stream<TableMember?> watchMember(String uid) => _members
      .doc(uid)
      .snapshots()
      .map(
        (s) =>
            s.data() == null
                ? null
                : TableMember.fromMap(s.id, _fromFirestore(s.data()!)),
      );

  @override
  Stream<List<TableMember>> watchMembers() => _members.snapshots().map(
    (q) => [
      for (final d in q.docs)
        TableMember.fromMap(d.id, _fromFirestore(d.data())),
    ]..sort((a, b) => a.joinedAt.compareTo(b.joinedAt)),
  );

  @override
  Future<void> join(TableMember member) =>
      _members.doc(member.uid).set(_toFirestore(member.toMap()));

  @override
  Future<void> leave(String uid) => _members.doc(uid).delete();

  @override
  Stream<List<ChronicleEntry>> watchChronicle() => _chronicle
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            ChronicleEntry.fromMap(d.id, _fromFirestore(d.data())),
        ],
      );

  @override
  Future<void> saveChronicle(ChronicleEntry entry) {
    final data = _toFirestore(entry.toMap());
    return entry.id.isEmpty
        ? _chronicle.add(data)
        : _chronicle.doc(entry.id).set(data);
  }

  @override
  Future<void> deleteChronicle(String id) => _chronicle.doc(id).delete();
}
