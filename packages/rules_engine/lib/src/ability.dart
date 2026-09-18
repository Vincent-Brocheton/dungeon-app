/// Les six caractéristiques.
enum Ability {
  /// Force.
  strength('STR'),

  /// Dextérité.
  dexterity('DEX'),

  /// Constitution.
  constitution('CON'),

  /// Intelligence.
  intelligence('INT'),

  /// Sagesse.
  wisdom('WIS'),

  /// Charisme.
  charisma('CHA');

  const Ability(this.code);

  /// Code à trois lettres, utilisé dans les packs de contenu JSON.
  final String code;

  /// Retrouve une caractéristique depuis son [code] (`"STR"`) ou son nom (`"strength"`).
  static Ability parse(String value) {
    final needle = value.trim().toUpperCase();
    for (final ability in values) {
      if (ability.code == needle || ability.name.toUpperCase() == needle) {
        return ability;
      }
    }
    throw ArgumentError.value(value, 'value', 'Caractéristique inconnue');
  }
}

/// Modificateur d'une caractéristique : (score − 10) / 2, arrondi à l'inférieur.
///
/// `abilityModifier(8) == -1`, `abilityModifier(15) == 2`, `abilityModifier(20) == 5`.
int abilityModifier(int score) => ((score - 10) / 2).floor();

/// Plafond général d'un score de caractéristique (PHB 2024).
const int abilityScoreCap = 20;
