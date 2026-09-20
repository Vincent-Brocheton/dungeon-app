import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/character_doc.dart';
import '../../data/character_repository.dart';
import '../../data/firestore_character_repository.dart';
import '../auth/auth_providers.dart';

/// Dépôt des personnages ; remplacé par `InMemoryCharacterRepository` dans les tests.
final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => FirestoreCharacterRepository(FirebaseFirestore.instance),
);

/// Les personnages de l'utilisateur courant, en temps réel (cache hors-ligne compris).
final myCharactersProvider = StreamProvider<List<CharacterDoc>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(characterRepositoryProvider).watchAll(uid);
});

/// Actions sur les personnages, à appeler depuis l'UI.
final charactersControllerProvider = Provider<CharactersController>(
  (ref) => CharactersController(ref),
);

class CharactersController {
  CharactersController(this._ref);

  final Ref _ref;

  CharacterRepository get _repo => _ref.read(characterRepositoryProvider);

  String _uid() {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) throw StateError('Aucun utilisateur connecté');
    return uid;
  }

  Future<CharacterDoc> create({
    required String name,
    required AbilityScores scores,
  }) async {
    final now = DateTime.now();
    final doc = CharacterDoc(
      id: _repo.newId(),
      name: name.trim(),
      scores: scores,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.upsert(_uid(), doc);
    return doc;
  }

  Future<void> delete(String id) => _repo.softDelete(_uid(), id);

  /// Efface toutes les données puis le compte. L'écran Bienvenue reprend
  /// la main : aucune session n'est recréée automatiquement.
  Future<void> deleteAccount() async {
    final auth = _ref.read(authServiceProvider);
    await _repo.deleteAll(_uid());
    await auth.deleteAccount();
  }
}
