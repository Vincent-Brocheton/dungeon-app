import 'ability.dart';

/// Une règle non respectée.
///
/// [code] est stable et destiné à la traduction côté UI (`point_buy.over_budget`) ;
/// [message] est un texte de débogage, pas un texte utilisateur.
class RuleViolation {
  /// Crée une violation.
  const RuleViolation(this.code, this.message, {this.ability});

  /// Identifiant stable de la règle violée.
  final String code;

  /// Explication lisible, pour les logs et les tests.
  final String message;

  /// Caractéristique concernée, s'il y en a une.
  final Ability? ability;

  @override
  String toString() =>
      'RuleViolation($code${ability == null ? '' : ', ${ability!.code}'}: $message)';
}
