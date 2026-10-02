import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/character_doc.dart';
import '../../data/character_repository.dart';
import '../../data/firestore_character_repository.dart';
import '../auth/auth_providers.dart';
import '../table/table_providers.dart';

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

/// Un personnage de l'utilisateur courant, `null` s'il n'existe pas (ou plus).
final characterProvider = Provider.family<AsyncValue<CharacterDoc?>, String>(
  (ref, id) => ref
      .watch(myCharactersProvider)
      .whenData((list) => list.where((c) => c.id == id).firstOrNull),
);

/// Historique des jets d'un personnage de l'utilisateur courant.
final characterRollsProvider = StreamProvider.family<List<RollRecord>, String>((
  ref,
  characterId,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(characterRepositoryProvider).watchRolls(uid, characterId);
});

/// Notes privées d'un personnage de l'utilisateur courant.
final characterNotesProvider =
    StreamProvider.family<List<CharacterNote>, String>((ref, characterId) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const Stream.empty();
      return ref
          .watch(characterRepositoryProvider)
          .watchNotes(uid, characterId);
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

  /// Crée un personnage niveau 1 à partir des choix de l'assistant.
  Future<CharacterDoc> create({
    required String name,
    required AbilityScores scores,
    String? classId,
    String? speciesId,
    String? subspeciesId,
    String? backgroundId,
    String? alignment,
    List<String> languages = const [],
    List<String> equipment = const [],
    int gold = 0,
  }) async {
    final now = DateTime.now();
    final doc = CharacterDoc(
      id: _repo.newId(),
      name: name.trim(),
      scores: scores,
      classId: classId,
      speciesId: speciesId,
      subspeciesId: subspeciesId,
      backgroundId: backgroundId,
      alignment: alignment,
      languages: languages,
      inventory: [for (final e in equipment) InventoryItem(name: e)],
      gold: gold,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.upsert(_uid(), doc);
    return doc;
  }

  /// Enregistre une modification de la fiche.
  Future<void> save(CharacterDoc doc) =>
      _repo.upsert(_uid(), doc.copyWith(updatedAt: DateTime.now()));

  Future<void> addNote(String characterId, String text) => _repo.addNote(
    _uid(),
    CharacterNote(
      id: _repo.newId(),
      characterId: characterId,
      text: text.trim(),
      createdAt: DateTime.now(),
    ),
  );

  Future<void> deleteNote(String noteId) => _repo.deleteNote(_uid(), noteId);

  /// Ajoute un jet à l'historique du personnage.
  Future<void> addRoll({
    required String characterId,
    required String characterName,
    required String label,
    required String detail,
    required int total,
    bool inspired = false,
  }) => _repo.addRoll(
    _uid(),
    RollRecord(
      id: _repo.newId(),
      characterId: characterId,
      characterName: characterName,
      label: label,
      detail: detail,
      total: total,
      inspired: inspired,
      createdAt: DateTime.now(),
    ),
  );

  Future<void> delete(String id) => _repo.softDelete(_uid(), id);

  /// Copie lisible de toutes les données du compte (`AccountExportData`) :
  /// personnages et leurs notes privées, en JSON indenté.
  Future<String> exportData() async {
    final uid = _uid();
    final characters = await _repo.watchAll(uid).first;
    return const JsonEncoder.withIndent('  ', _encodeDate).convert({
      'exportedAt': DateTime.now(),
      'characters': [
        for (final c in characters)
          {
            'id': c.id,
            ...c.toMap(),
            'notes': [
              for (final n in await _repo.watchNotes(uid, c.id).first)
                n.toMap(),
            ],
            'rolls': [
              for (final r in await _repo.watchRolls(uid, c.id).first)
                r.toMap(),
            ],
          },
      ],
    });
  }

  static Object? _encodeDate(Object? value) =>
      value is DateTime ? value.toIso8601String() : value.toString();

  /// Quitte la table, efface toutes les données puis le compte. L'écran Bienvenue reprend
  /// la main : aucune session n'est recréée automatiquement.
  Future<void> deleteAccount() async {
    final auth = _ref.read(authServiceProvider);
    await _ref.read(tableMembershipRepositoryProvider).leave(_uid());
    await _repo.deleteAll(_uid());
    await auth.deleteAccount();
  }
}
