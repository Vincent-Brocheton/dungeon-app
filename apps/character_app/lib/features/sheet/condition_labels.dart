import 'package:rules_engine/rules_engine.dart';

/// Nom et effet en français de chaque condition (`CharSheetConditions`).
const conditionLabels = <Condition, (String, String)>{
  Condition.blinded: (
    'Aveuglé',
    'Rate automatiquement les tests basés sur la vue ; désavantage aux jets '
        "d'attaque ; les attaques contre lui ont l'avantage.",
  ),
  Condition.charmed: (
    'Charmé',
    "Ne peut pas attaquer son charmeur ; celui-ci a l'avantage aux tests "
        "d'interaction sociale contre lui.",
  ),
  Condition.deafened: (
    'Assourdi',
    "Rate automatiquement les tests basés sur l'audition.",
  ),
  Condition.frightened: (
    'Effrayé',
    "Désavantage aux tests de caractéristique et jets d'attaque tant que la "
        "source de peur est en vue ; ne peut s'en approcher.",
  ),
  Condition.grappled: (
    'Agrippé',
    'Vitesse réduite à 0 ; ne bénéficie d’aucun bonus de Vitesse.',
  ),
  Condition.incapacitated: (
    "Incapable d'agir",
    'Ne peut effectuer aucune action, action bonus ou réaction ; perd sa '
        'concentration.',
  ),
  Condition.invisible: (
    'Invisible',
    "Avantage à ses jets d'attaque ; les attaques contre lui ont le "
        'désavantage.',
  ),
  Condition.paralyzed: (
    'Paralysé',
    "Incapable d'agir, Vitesse 0 ; rate automatiquement les sauvegardes de "
        'Force et Dextérité ; touché au contact = coup critique.',
  ),
  Condition.petrified: (
    'Pétrifié',
    "Incapable d'agir, Vitesse 0 ; rate automatiquement les sauvegardes de "
        'Force et Dextérité ; résistance à tous les dégâts.',
  ),
  Condition.poisoned: (
    'Empoisonné',
    "Désavantage aux jets d'attaque et aux tests de caractéristique.",
  ),
  Condition.prone: (
    'À terre',
    "Seul déplacement possible : ramper ; désavantage aux jets d'attaque ; "
        "les attaques au contact contre lui ont l'avantage.",
  ),
  Condition.restrained: (
    'Entravé',
    "Vitesse 0 ; désavantage aux jets d'attaque et aux sauvegardes de "
        "Dextérité ; les attaques contre lui ont l'avantage.",
  ),
  Condition.stunned: (
    'Étourdi',
    "Incapable d'agir ; rate automatiquement les sauvegardes de Force et "
        "Dextérité ; les attaques contre lui ont l'avantage.",
  ),
  Condition.unconscious: (
    'Inconscient',
    "Incapable d'agir, à terre ; rate automatiquement les sauvegardes de "
        'Force et Dextérité ; touché au contact = coup critique.',
  ),
};

/// Nom français d'une condition.
String conditionLabel(Condition c) => conditionLabels[c]!.$1;

/// « Empoisonné, À terre ».
String conditionList(List<Condition> conditions) =>
    conditions.map(conditionLabel).join(', ');
