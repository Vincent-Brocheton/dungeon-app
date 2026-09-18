/// Utilisateur connecté, découplé de Firebase pour rester testable.
class AppUser {
  const AppUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });

  final String uid;
  final bool isAnonymous;
  final String? email;
  final String? displayName;

  /// Libellé court pour l'UI.
  String get label =>
      isAnonymous ? 'Compte anonyme' : (displayName ?? email ?? uid);

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      uid == other.uid &&
      isAnonymous == other.isAnonymous &&
      email == other.email &&
      displayName == other.displayName;

  @override
  int get hashCode => Object.hash(uid, isAnonymous, email, displayName);
}
