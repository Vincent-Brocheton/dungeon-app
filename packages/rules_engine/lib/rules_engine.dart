/// Moteur de règles D&D 2024 (SRD 5.2).
///
/// Principe : ce paquet ne connaît ni Flutter ni la persistance.
/// Il reçoit des choix (scores, background, classe...) et un [ContentPack],
/// et renvoie des valeurs dérivées ou des [RuleViolation].
library;

export 'src/ability.dart';
export 'src/ability_scores.dart';
export 'src/background_bonus.dart';
export 'src/content_pack.dart';
export 'src/point_buy.dart';
export 'src/proficiency.dart';
export 'src/rule_violation.dart';
