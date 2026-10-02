import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_doc.dart';
import '../../data/table_membership.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_providers.dart';
import '../auth/auth_providers.dart';
import '../characters/characters_providers.dart';
import 'table_providers.dart';

/// « + 5 po », « − 20 pa ».
String _signed(int amount, Coin coin) =>
    '${amount < 0 ? '−' : '+'} ${amount.abs()} ${coin.abbreviation}';

/// Réserve du groupe (`PartyTreasury` côté joueur, `TableTreasury` côté MJ) :
/// solde, objets communs et historique. Le joueur verse de l'or depuis sa
/// bourse ; le MJ ajuste, distribue et gère les objets.
class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myMembershipProvider).value;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    if (me == null && !isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Réserve du groupe')),
        body: Center(
          child: Text('Rejoins une table pour voir sa réserve.', style: muted),
        ),
      );
    }
    final movements = ref.watch(treasuryProvider).value ?? <TreasuryMovement>[];
    final items = ref.watch(treasuryItemsProvider).value ?? <TreasuryItem>[];
    final balance = {
      for (final c in Coin.values)
        c: movements
            .where((m) => m.coin == c)
            .fold(0, (sum, m) => sum + m.amount),
    };
    final copper = movements.fold(
      0,
      (sum, m) => sum + m.amount * m.coin.copperValue,
    );
    final total = (copper / 100)
        .toStringAsFixed(copper % 100 == 0 ? 0 : (copper % 10 == 0 ? 1 : 2))
        .replaceAll('.', ',');
    final repo = ref.read(tableMembershipRepositoryProvider);
    final players = ref.watch(tableMembersProvider).value?.length ?? 0;

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text.toUpperCase(), style: muted),
    );
    final card = BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(10),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Réserve du groupe')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                isAdmin
                    ? 'Les joueurs consultent la réserve et peuvent y verser '
                        'de l’argent. Toi seul la distribues et gères les '
                        'objets communs.'
                    : 'Tu peux consulter la réserve et y verser de l’argent. '
                        'Seul le MJ la distribue ou gère les objets communs.',
                style: muted,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: card.copyWith(
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Column(
                  children: [
                    Text('VALEUR TOTALE (ÉQUIVALENT OR)', style: muted),
                    Text(
                      '≈ $total po',
                      key: const Key('treasury-total'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.accent,
                      ),
                    ),
                    Text(
                      [
                        for (final c in Coin.values)
                          '${balance[c]} ${c.abbreviation}',
                      ].join(' + '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (me != null) ...[
                title('Verser à la réserve'),
                _Deposit(me: me),
              ],
              if (isAdmin) ...[
                title('Gestion (MJ)'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder: (_) => const _MovementDialog(),
                          ),
                      child: const Text('Mouvement manuel'),
                    ),
                    OutlinedButton(
                      onPressed:
                          balance[Coin.gold]! <= 0
                              ? null
                              : () => _distribute(
                                context,
                                ref,
                                balance[Coin.gold]!,
                                players,
                              ),
                      child: const Text('Distribuer l’or'),
                    ),
                  ],
                ),
              ],
              title('Objets communs'),
              if (items.isEmpty) Text('Aucun objet commun.', style: muted),
              for (final i in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: card,
                  child: ListTile(
                    title: Text(i.name),
                    subtitle:
                        i.note.isEmpty ? null : Text(i.note, style: muted),
                    trailing:
                        isAdmin
                            ? IconButton(
                              tooltip: 'Retirer ${i.name}',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => repo.removeTreasuryItem(i.id),
                            )
                            : null,
                  ),
                ),
              if (isAdmin)
                TextButton(
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder: (_) => const _ItemDialog(),
                      ),
                  child: const Text('+ Ajouter un objet commun'),
                ),
              title('Historique des mouvements'),
              if (movements.isEmpty) Text('Aucun mouvement.', style: muted),
              for (final m in movements)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: card,
                  child: Row(
                    children: [
                      Expanded(child: Text(m.label)),
                      Text(
                        _signed(m.amount, m.coin),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              m.amount > 0
                                  ? const Color(0xFF7FA86A)
                                  : const Color(0xFFC97227),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Partage l'or à parts égales entre les joueurs de la table, arrondi à
  /// l'unité inférieure ; le reste demeure dans la réserve. Le MJ ne peut pas
  /// écrire dans les fiches : chacun ajoute sa part à sa bourse.
  Future<void> _distribute(
    BuildContext context,
    WidgetRef ref,
    int gold,
    int players,
  ) async {
    final share = players == 0 ? 0 : gold ~/ players;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Distribuer l’or'),
            content: Text(
              share == 0
                  ? 'Pas assez d’or pour $players joueur(s).'
                  : '$gold po ÷ $players joueur(s) : $share po chacun, '
                      '${gold - share * players} po restent dans la réserve. '
                      'Chaque joueur ajoute sa part à sa bourse.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              if (share > 0)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmer la distribution'),
                ),
            ],
          ),
    );
    if (ok != true) return;
    await ref
        .read(tableMembershipRepositoryProvider)
        .addTreasuryMovement(
          TreasuryMovement(
            label: 'Distribution — $share po chacun ($players joueurs)',
            coin: Coin.gold,
            amount: -share * players,
            authorUid: ref.read(currentUidProvider)!,
            createdAt: DateTime.now(),
          ),
        );
  }
}

/// Versement d'or depuis la bourse du personnage joué à la table.
class _Deposit extends ConsumerStatefulWidget {
  const _Deposit({required this.me});

  final TableMember me;

  @override
  ConsumerState<_Deposit> createState() => _DepositState();
}

class _DepositState extends ConsumerState<_Deposit> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _deposit(CharacterDoc doc) async {
    final n = int.tryParse(_amount.text.trim());
    if (n == null || n <= 0 || n > doc.gold) {
      setState(() => _error = 'Entre 1 et ${doc.gold} po.');
      return;
    }
    setState(() => _error = null);
    _amount.clear();
    final now = DateTime.now();
    await ref
        .read(charactersControllerProvider)
        .save(
          doc.copyWith(
            gold: doc.gold - n,
            moneyLog:
                [
                  MoneyMovement(
                    label: 'Versé à la réserve du groupe',
                    coin: Coin.gold,
                    amount: -n,
                    at: now,
                  ),
                  ...doc.moneyLog,
                ].take(50).toList(),
          ),
        );
    await ref
        .read(tableMembershipRepositoryProvider)
        .addTreasuryMovement(
          TreasuryMovement(
            label: 'Contribution — ${doc.name}',
            coin: Coin.gold,
            amount: n,
            authorUid: widget.me.uid,
            createdAt: now,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted);
    final doc =
        (ref.watch(myCharactersProvider).value ?? <CharacterDoc>[])
            .where((c) => c.id == widget.me.characterId)
            .firstOrNull;
    if (doc == null) {
      return Text(
        'Choisis un personnage à la table pour verser depuis sa bourse.',
        style: muted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Depuis la bourse de ${doc.name} (${doc.gold} po disponibles) :',
          style: muted,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                key: const Key('deposit-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'po',
                  errorText: _error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => _deposit(doc),
              child: const Text('Verser'),
            ),
          ],
        ),
      ],
    );
  }
}

/// MJ : mouvement manuel, positif ou négatif.
class _MovementDialog extends ConsumerStatefulWidget {
  const _MovementDialog();

  @override
  ConsumerState<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends ConsumerState<_MovementDialog> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  var _coin = Coin.gold;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final label = _label.text.trim();
    final amount = int.tryParse(
      _amount.text.trim().replaceAll('+', '').replaceAll('−', '-'),
    );
    if (label.isEmpty || amount == null || amount == 0) {
      setState(() => _error = 'Un libellé et un montant, par exemple -20.');
      return;
    }
    ref
        .read(tableMembershipRepositoryProvider)
        .addTreasuryMovement(
          TreasuryMovement(
            label: label,
            coin: _coin,
            amount: amount,
            authorUid: ref.read(currentUidProvider)!,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mouvement manuel'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('movement-label'),
              controller: _label,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Libellé'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('movement-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Montant (+ / −)',
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<Coin>(
                  value: _coin,
                  items: [
                    for (final c in Coin.values)
                      DropdownMenuItem(value: c, child: Text(c.abbreviation)),
                  ],
                  onChanged: (c) => setState(() => _coin = c ?? _coin),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _save, child: const Text('Enregistrer')),
    ],
  );
}

/// MJ : nouvel objet commun.
class _ItemDialog extends ConsumerStatefulWidget {
  const _ItemDialog();

  @override
  ConsumerState<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends ConsumerState<_ItemDialog> {
  final _name = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    ref
        .read(tableMembershipRepositoryProvider)
        .addTreasuryItem(
          TreasuryItem(
            name: name,
            note: _note.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Objet commun'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('item-name'),
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _save, child: const Text('Ajouter')),
    ],
  );
}
