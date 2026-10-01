/// Emplacements de sorts par niveau de sort (index 0 = niveau 1), pour un
/// lanceur complet (Barde, Clerc, Druide, Ensorceleur, Magicien) au [level]
/// de classe donné (PHB 2024).
// ponytail: table des lanceurs complets pour toute classe qui lance des
// sorts ; demi-lanceurs et Occultiste quand la classe portera son type de
// progression.
List<int> fullCasterSlots(int level) {
  if (level < 1 || level > 20) {
    throw RangeError.range(level, 1, 20, 'level');
  }
  return _fullCaster[level - 1];
}

const _fullCaster = [
  [2],
  [3],
  [4, 2],
  [4, 3],
  [4, 3, 2],
  [4, 3, 3],
  [4, 3, 3, 1],
  [4, 3, 3, 2],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

/// Niveau d'emplacement (1–9) dépensé pour lancer un sort de [spellLevel] :
/// le plus bas encore disponible à partir du niveau du sort, ou `null`.
/// [slots] et [used] sont indexés comme [fullCasterSlots].
int? slotToSpend(List<int> slots, List<int> used, int spellLevel) {
  for (var i = spellLevel - 1; i < slots.length; i++) {
    if ((i < used.length ? used[i] : 0) < slots[i]) return i + 1;
  }
  return null;
}
