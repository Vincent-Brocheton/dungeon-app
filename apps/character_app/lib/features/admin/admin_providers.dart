import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_background_doc.dart';
import '../../data/admin_character_entry.dart';
import '../../data/admin_character_repository.dart';
import '../../data/admin_invocation_doc.dart';
import '../../data/admin_monster_doc.dart';
import '../../data/admin_npc_doc.dart';
import '../../data/admin_repository.dart';
import '../../data/admin_class_doc.dart';
import '../../data/admin_feat_doc.dart';
import '../../data/admin_species_doc.dart';
import '../../data/admin_spell_doc.dart';
import '../../data/admin_subclass_doc.dart';
import '../../data/admin_subspecies_doc.dart';
import '../../data/admin_table_doc.dart';
import '../../data/content_repository.dart';
import '../../data/admin_table_repository.dart';
import '../../data/firestore_admin_character_repository.dart';
import '../../data/firestore_admin_repository.dart';
import '../../data/firestore_admin_table_repository.dart';
import '../../data/firestore_content_repository.dart';
import '../../providers/content_providers.dart';
import '../auth/auth_providers.dart';
import 'background_merge.dart';
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
/// `InMemoryContentRepository` dans les tests.
final adminSpeciesRepositoryProvider =
    Provider<ContentRepository<AdminSpeciesDoc>>(
      (ref) => FirestoreContentRepository(
        _content('species'),
        AdminSpeciesDoc.fromMap,
      ),
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

/// Dépôt des sous-espèces éditées par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminSubspeciesRepositoryProvider =
    Provider<ContentRepository<AdminSubspeciesDoc>>(
      (ref) => FirestoreContentRepository(
        _content('subspecies'),
        AdminSubspeciesDoc.fromMap,
      ),
    );

/// Aucune sous-espèce dans le pack SRD statique : pas de fusion nécessaire,
/// contrairement aux espèces.
final allSubspeciesProvider = StreamProvider<List<AdminSubspeciesDoc>>(
  (ref) => ref.watch(adminSubspeciesRepositoryProvider).watchAll(),
);

/// Dépôt des sorts édités par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminSpellRepositoryProvider = Provider<ContentRepository<AdminSpellDoc>>(
  (ref) =>
      FirestoreContentRepository(_content('spells'), AdminSpellDoc.fromMap),
);

/// Aucun sort dans le pack SRD statique : pas de fusion nécessaire.
final allSpellsProvider = StreamProvider<List<AdminSpellDoc>>(
  (ref) => ref.watch(adminSpellRepositoryProvider).watchAll(),
);

/// Dépôt des dons édités par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminFeatRepositoryProvider = Provider<ContentRepository<AdminFeatDoc>>(
  (ref) => FirestoreContentRepository(_content('feats'), AdminFeatDoc.fromMap),
);

/// Aucun don dans le pack SRD statique : pas de fusion nécessaire.
final allFeatsProvider = StreamProvider<List<AdminFeatDoc>>(
  (ref) => ref.watch(adminFeatRepositoryProvider).watchAll(),
);

/// Dépôt des classes éditées par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminClassRepositoryProvider = Provider<ContentRepository<AdminClassDoc>>(
  (ref) =>
      FirestoreContentRepository(_content('classes'), AdminClassDoc.fromMap),
);

/// Aucune classe dans le pack SRD statique : pas de fusion nécessaire.
final allClassesProvider = StreamProvider<List<AdminClassDoc>>(
  (ref) => ref.watch(adminClassRepositoryProvider).watchAll(),
);

/// Dépôt des sous-classes éditées par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminSubclassRepositoryProvider =
    Provider<ContentRepository<AdminSubclassDoc>>(
      (ref) => FirestoreContentRepository(
        _content('subclasses'),
        AdminSubclassDoc.fromMap,
      ),
    );

/// Aucune sous-classe dans le pack SRD statique : pas de fusion nécessaire.
final allSubclassesProvider = StreamProvider<List<AdminSubclassDoc>>(
  (ref) => ref.watch(adminSubclassRepositoryProvider).watchAll(),
);

/// Dépôt des historiques édités par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminBackgroundRepositoryProvider =
    Provider<ContentRepository<AdminBackgroundDoc>>(
      (ref) => FirestoreContentRepository(
        _content('backgrounds'),
        AdminBackgroundDoc.fromMap,
      ),
    );

final _backgroundOverridesProvider = StreamProvider<List<AdminBackgroundDoc>>(
  (ref) => ref.watch(adminBackgroundRepositoryProvider).watchAll(),
);

/// Pack SRD statique fusionné aux surcharges admin (`content/backgrounds`) :
/// voir `mergeBackgrounds`. Même états de chargement/erreur que
/// [allSpeciesProvider].
final allBackgroundsProvider = Provider<AsyncValue<List<AdminBackgroundDoc>>>((
  ref,
) {
  final pack = ref.watch(srdPackProvider);
  final overrides = ref.watch(_backgroundOverridesProvider);
  return pack.when(
    data:
        (pack) => overrides.when(
          data:
              (overrides) => AsyncValue.data(mergeBackgrounds(pack, overrides)),
          loading: () => const AsyncValue.loading(),
          error: AsyncValue.error,
        ),
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});

/// Dépôt des manifestations occultes éditées par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminInvocationRepositoryProvider =
    Provider<ContentRepository<AdminInvocationDoc>>(
      (ref) => FirestoreContentRepository(
        _content('invocations'),
        AdminInvocationDoc.fromMap,
      ),
    );

/// Aucune manifestation dans le pack SRD statique : pas de fusion nécessaire.
final allInvocationsProvider = StreamProvider<List<AdminInvocationDoc>>(
  (ref) => ref.watch(adminInvocationRepositoryProvider).watchAll(),
);

/// Dépôt des monstres édités par un admin ; remplacé par
/// `InMemoryContentRepository` dans les tests.
final adminMonsterRepositoryProvider =
    Provider<ContentRepository<AdminMonsterDoc>>(
      (ref) => FirestoreContentRepository(
        _content('monsters'),
        AdminMonsterDoc.fromMap,
      ),
    );

/// Aucun monstre dans le pack SRD statique : pas de fusion nécessaire.
final allMonstersProvider = StreamProvider<List<AdminMonsterDoc>>(
  (ref) => ref.watch(adminMonsterRepositoryProvider).watchAll(),
);

/// Dépôt des PNJ ; remplacé par `InMemoryContentRepository` dans les tests.
final adminNpcRepositoryProvider = Provider<ContentRepository<AdminNpcDoc>>(
  (ref) =>
      FirestoreContentRepository(_db.collection('npcs'), AdminNpcDoc.fromMap),
);

/// Tous les PNJ, en temps réel (lisibles par les seuls admins).
final allNpcsProvider = StreamProvider<List<AdminNpcDoc>>(
  (ref) => ref.watch(adminNpcRepositoryProvider).watchAll(),
);

/// Dépôt de la table du MJ ; remplacé par `InMemoryAdminTableRepository`
/// dans les tests.
final adminTableRepositoryProvider = Provider<AdminTableRepository>(
  (ref) => FirestoreAdminTableRepository(FirebaseFirestore.instance),
);

/// La table du MJ, `null` tant qu'elle n'a jamais été enregistrée.
final adminTableProvider = StreamProvider<AdminTableDoc?>(
  (ref) => ref.watch(adminTableRepositoryProvider).watch(),
);

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// `content/<kind>/items` : collection d'un type de contenu de règles.
CollectionReference<Map<String, dynamic>> _content(String kind) =>
    _db.collection('content').doc(kind).collection('items');
