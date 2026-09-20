import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_character_entry.dart';
import '../../data/admin_character_repository.dart';
import '../../data/admin_repository.dart';
import '../../data/admin_species_doc.dart';
import '../../data/admin_species_repository.dart';
import '../../data/firestore_admin_character_repository.dart';
import '../../data/firestore_admin_repository.dart';
import '../../data/firestore_admin_species_repository.dart';
import '../../providers/content_providers.dart';
import '../auth/auth_providers.dart';
import 'species_merge.dart';

/// Dépôt du rôle admin ; remplacé par `InMemoryAdminRepository` dans les tests.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => FirestoreAdminRepository(FirebaseFirestore.instance),
);

/// `true` si l'utilisateur courant est admin (document `admins/{uid}` dans Firestore).
final isAdminProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(adminRepositoryProvider).watchIsAdmin(uid);
});

/// Dépôt cross-utilisateurs des personnages ; remplacé par
/// `InMemoryAdminCharacterRepository` dans les tests.
final adminCharacterRepositoryProvider = Provider<AdminCharacterRepository>(
  (ref) => FirestoreAdminCharacterRepository(FirebaseFirestore.instance),
);

/// Tous les personnages de tous les utilisateurs, en temps réel (vue admin).
final allCharactersProvider = StreamProvider<List<AdminCharacterEntry>>(
  (ref) => ref.watch(adminCharacterRepositoryProvider).watchAllCharacters(),
);

/// Dépôt des espèces éditées par un admin ; remplacé par
/// `InMemoryAdminSpeciesRepository` dans les tests.
final adminSpeciesRepositoryProvider = Provider<AdminSpeciesRepository>(
  (ref) => FirestoreAdminSpeciesRepository(FirebaseFirestore.instance),
);

final _speciesOverridesProvider = StreamProvider<List<AdminSpeciesDoc>>(
  (ref) => ref.watch(adminSpeciesRepositoryProvider).watchAll(),
);

/// Pack SRD statique fusionné aux surcharges admin (`content/species`) :
/// voir `mergeSpecies`. `AsyncLoading` tant que l'un des deux n'a pas encore
/// de valeur, `AsyncError` si l'un des deux échoue.
final allSpeciesProvider = Provider<AsyncValue<List<AdminSpeciesDoc>>>((ref) {
  final pack = ref.watch(srdPackProvider);
  final overrides = ref.watch(_speciesOverridesProvider);
  return pack.when(
    data:
        (pack) => overrides.when(
          data: (overrides) => AsyncValue.data(mergeSpecies(pack, overrides)),
          loading: () => const AsyncValue.loading(),
          error: AsyncValue.error,
        ),
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});
