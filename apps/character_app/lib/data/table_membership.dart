import 'dart:math';

import 'character_doc.dart';

/// Ce que les joueurs voient de la table : `tablePublic/main`, copie par le
/// MJ des champs non confidentiels de `table/main` (dont le journal reste
/// privé).
class TablePublicInfo {
  const TablePublicInfo({
    required this.name,
    this.world = '',
    this.cadence = '',
    this.nextSessionWhen = '',
    this.nextSessionWhere = '',
    this.nextSessionNote = '',
  });

  final String name;
  final String world;
  final String cadence;
  final String nextSessionWhen;
  final String nextSessionWhere;
  final String nextSessionNote;

  Map<String, Object?> toMap() => {
    'name': name,
    'world': world,
    'cadence': cadence,
    'nextSessionWhen': nextSessionWhen,
    'nextSessionWhere': nextSessionWhere,
    'nextSessionNote': nextSessionNote,
  };

  factory TablePublicInfo.fromMap(Map<String, Object?> map) => TablePublicInfo(
    name: map['name'] as String? ?? '',
    world: map['world'] as String? ?? '',
    cadence: map['cadence'] as String? ?? '',
    nextSessionWhen: map['nextSessionWhen'] as String? ?? '',
    nextSessionWhere: map['nextSessionWhere'] as String? ?? '',
    nextSessionNote: map['nextSessionNote'] as String? ?? '',
  );
}

/// Invitation à la table : `invites/{code}`. Le code fait office de secret
/// (lecture par code seulement, jamais de liste hors MJ) ; le nom et
/// l'univers de la table y sont recopiés pour l'aperçu avant de rejoindre.
class TableInvite {
  const TableInvite({
    required this.code,
    required this.tableName,
    required this.createdAt,
    this.tableWorld = '',
  });

  final String code;
  final String tableName;
  final String tableWorld;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'tableName': tableName,
    'tableWorld': tableWorld,
    'createdAt': createdAt,
  };

  factory TableInvite.fromMap(String code, Map<String, Object?> map) =>
      TableInvite(
        code: code,
        tableName: map['tableName'] as String? ?? '',
        tableWorld: map['tableWorld'] as String? ?? '',
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      );

  /// Alphabet sans caractères ambigus (0/O, 1/I/L).
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Code aléatoire « K7QX2M9P » (31⁸ ≈ 8,5 × 10¹¹ possibilités).
  static String newCode([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 8; i++)
        _alphabet.codeUnitAt(rng.nextInt(_alphabet.length)),
    ]);
  }

  /// Code tel que saisi : majuscules, sans espaces ni tirets.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
}

/// Joueur de la table : `tableMembers/{uid}`, créé par le joueur lui-même
/// avec un code d'invitation valide.
class TableMember {
  const TableMember({
    required this.uid,
    required this.inviteCode,
    required this.joinedAt,
    this.characterId,
    this.characterName = '',
    this.characterSummary = '',
  });

  final String uid;
  final String inviteCode;
  final DateTime joinedAt;

  /// Personnage joué à la table, s'il est choisi.
  final String? characterId;
  final String characterName;

  /// « Clerc 5 · Humain ».
  final String characterSummary;

  Map<String, Object?> toMap() => {
    'inviteCode': inviteCode,
    'joinedAt': joinedAt,
    'characterId': characterId,
    'characterName': characterName,
    'characterSummary': characterSummary,
  };

  factory TableMember.fromMap(String uid, Map<String, Object?> map) =>
      TableMember(
        uid: uid,
        inviteCode: map['inviteCode'] as String? ?? '',
        joinedAt: map['joinedAt'] as DateTime? ?? DateTime.now(),
        characterId: map['characterId'] as String?,
        characterName: map['characterName'] as String? ?? '',
        characterSummary: map['characterSummary'] as String? ?? '',
      );
}

/// Type d'entrée de la chronique partagée.
enum ChronicleKind {
  quest('Quête'),
  encounter('Rencontre'),
  note('Note');

  const ChronicleKind(this.label);
  final String label;
}

/// État d'une quête.
enum QuestStatus {
  ongoing('En cours'),
  done('Terminée'),
  failed('Échouée');

  const QuestStatus(this.label);
  final String label;
}

/// Entrée de la chronique partagée : `tableChronicle/{id}`, visible des
/// membres et du MJ, signée du nom de personnage de son auteur.
class ChronicleEntry {
  const ChronicleEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.text = '',
    this.status,
  });

  final String id;
  final ChronicleKind kind;
  final String title;
  final String text;

  /// État, pour une quête seulement.
  final QuestStatus? status;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  ChronicleEntry withStatus(QuestStatus status) => ChronicleEntry(
    id: id,
    kind: kind,
    title: title,
    text: text,
    status: status,
    authorUid: authorUid,
    authorName: authorName,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'kind': kind.name,
    'status': status?.name ?? '',
    'title': title,
    'text': text,
    'authorUid': authorUid,
    'authorName': authorName,
    'createdAt': createdAt,
  };

  factory ChronicleEntry.fromMap(String id, Map<String, Object?> map) =>
      ChronicleEntry(
        id: id,
        kind:
            ChronicleKind.values.asNameMap()[map['kind']] ?? ChronicleKind.note,
        status: QuestStatus.values.asNameMap()[map['status']],
        title: map['title'] as String? ?? '',
        text: map['text'] as String? ?? '',
        authorUid: map['authorUid'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      );
}

/// Mouvement de la réserve du groupe : `treasuryMovements/{id}`. La réserve
/// est la somme des mouvements ; un joueur ne peut que verser (montant
/// positif), le MJ ajuste librement. Jamais modifié ni supprimé.
class TreasuryMovement {
  const TreasuryMovement({
    required this.label,
    required this.coin,
    required this.amount,
    required this.authorUid,
    required this.createdAt,
    this.id = '',
  });

  final String id;
  final String label;
  final Coin coin;

  /// Positif pour un versement, négatif pour une sortie.
  final int amount;
  final String authorUid;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'label': label,
    'coin': coin.name,
    'amount': amount,
    'authorUid': authorUid,
    'createdAt': createdAt,
  };

  factory TreasuryMovement.fromMap(String id, Map<String, Object?> map) =>
      TreasuryMovement(
        id: id,
        label: map['label'] as String? ?? '',
        coin: Coin.values.asNameMap()[map['coin']] ?? Coin.gold,
        amount: map['amount'] as int? ?? 0,
        authorUid: map['authorUid'] as String? ?? '',
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      );
}

/// Objet commun du groupe (`treasuryItems/{id}`), géré par le MJ.
class TreasuryItem {
  const TreasuryItem({
    required this.name,
    required this.createdAt,
    this.note = '',
    this.id = '',
  });

  final String id;
  final String name;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'name': name,
    'note': note,
    'createdAt': createdAt,
  };

  factory TreasuryItem.fromMap(String id, Map<String, Object?> map) =>
      TreasuryItem(
        id: id,
        name: map['name'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      );
}

/// Accès à l'adhésion à la table. Implémenté par Firestore, et en mémoire
/// pour les tests.
abstract class TableMembershipRepository {
  /// Infos publiques de la table (membres et MJ).
  Stream<TablePublicInfo?> watchPublic();

  /// MJ : publie les infos publiques.
  Future<void> publish(TablePublicInfo info);

  /// L'invitation de ce code, ou `null` si elle n'existe pas (ou plus).
  Future<TableInvite?> getInvite(String code);

  /// MJ : invitations actives, des plus récentes aux plus anciennes.
  Stream<List<TableInvite>> watchInvites();

  /// MJ : crée une invitation.
  Future<void> createInvite(TableInvite invite);

  /// MJ : révoque une invitation (les joueurs déjà entrés restent).
  Future<void> revokeInvite(String code);

  /// Adhésion de ce joueur, `null` s'il n'est pas à la table.
  Stream<TableMember?> watchMember(String uid);

  /// Joueurs de la table (MJ et membres).
  Stream<List<TableMember>> watchMembers();

  /// Le joueur rejoint la table (ou change de personnage).
  Future<void> join(TableMember member);

  /// Le joueur quitte la table, ou le MJ le retire.
  Future<void> leave(String uid);

  /// Chronique partagée, des plus récentes aux plus anciennes.
  Stream<List<ChronicleEntry>> watchChronicle();

  /// Ajoute (id vide) ou met à jour une entrée (auteur ou MJ).
  Future<void> saveChronicle(ChronicleEntry entry);

  /// Supprime une entrée (auteur ou MJ).
  Future<void> deleteChronicle(String id);

  /// Mouvements de la réserve, des plus récents aux plus anciens.
  Stream<List<TreasuryMovement>> watchTreasury();

  /// Ajoute un mouvement à la réserve.
  Future<void> addTreasuryMovement(TreasuryMovement movement);

  /// Objets communs, des plus anciens aux plus récents.
  Stream<List<TreasuryItem>> watchTreasuryItems();

  /// MJ : ajoute un objet commun.
  Future<void> addTreasuryItem(TreasuryItem item);

  /// MJ : retire un objet commun.
  Future<void> removeTreasuryItem(String id);
}
