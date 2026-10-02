import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firestore_table_membership_repository.dart';
import '../../data/table_membership.dart';
import '../auth/auth_providers.dart';

/// Dépôt de l'adhésion à la table ; remplacé par
/// `InMemoryTableMembershipRepository` dans les tests.
final tableMembershipRepositoryProvider = Provider<TableMembershipRepository>(
  (ref) => FirestoreTableMembershipRepository(FirebaseFirestore.instance),
);

/// Infos publiques de la table, pour ses membres et le MJ.
final tablePublicProvider = StreamProvider<TablePublicInfo?>(
  (ref) => ref.watch(tableMembershipRepositoryProvider).watchPublic(),
);

/// Adhésion de l'utilisateur courant, `null` s'il n'est pas à la table.
final myMembershipProvider = StreamProvider<TableMember?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(tableMembershipRepositoryProvider).watchMember(uid);
});

/// Joueurs de la table.
final tableMembersProvider = StreamProvider<List<TableMember>>(
  (ref) => ref.watch(tableMembershipRepositoryProvider).watchMembers(),
);

/// MJ : invitations actives.
final tableInvitesProvider = StreamProvider<List<TableInvite>>(
  (ref) => ref.watch(tableMembershipRepositoryProvider).watchInvites(),
);
