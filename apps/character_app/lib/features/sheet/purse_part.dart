part of 'character_sheet_screen.dart';

/// Mouvements gardés dans l'historique : le document du personnage reste
/// petit.
const _maxMoneyLog = 50;

int _coins(CharacterDoc doc, Coin coin) => switch (coin) {
  Coin.gold => doc.gold,
  Coin.silver => doc.silver,
  Coin.copper => doc.copper,
};

CharacterDoc _withCoins(CharacterDoc doc, Coin coin, int value) =>
    switch (coin) {
      Coin.gold => doc.copyWith(gold: value),
      Coin.silver => doc.copyWith(silver: value),
      Coin.copper => doc.copyWith(copper: value),
    };

const _coinLabels = {
  Coin.gold: 'Or (po)',
  Coin.silver: 'Argent (pa)',
  Coin.copper: 'Cuivre (pc)',
};

/// Bourse (`CharSheetCurrency.dc.html`) : valeur totale, pièces ±,
/// conversions et historique des mouvements manuels. La réserve du groupe
/// viendra avec la table côté joueur.
class PurseScreen extends ConsumerWidget {
  const PurseScreen({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(characterProvider(characterId)).value;
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final controller = ref.read(charactersControllerProvider);

    Widget convert(String rate, String help, Coin from) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(rate), Text(help, style: muted)],
            ),
          ),
          OutlinedButton(
            key: Key('convert-${from.name}'),
            onPressed:
                _coins(doc, from) < 10
                    ? null
                    : () {
                      final (g, s, c) = convertCoins(
                        doc.gold,
                        doc.silver,
                        doc.copper,
                        from,
                      );
                      controller.save(
                        doc.copyWith(gold: g, silver: s, copper: c),
                      );
                    },
            child: const Text('Convertir'),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bourse'),
            Text(
              '${doc.name} · pièces, conversions et historique',
              style: muted,
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2114),
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('VALEUR TOTALE (ÉQUIVALENT OR)', style: muted),
                    Text(
                      '≈ ${goldValue(doc.gold, doc.silver, doc.copper)} po',
                      key: const Key('purse-total'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Pièces',
                child: Row(
                  children: [
                    for (final (i, coin) in Coin.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: _card,
                          child: Column(
                            children: [
                              Text(
                                _coinLabels[coin]!.toUpperCase(),
                                style: muted,
                              ),
                              Text(
                                '${_coins(doc, coin)}',
                                key: Key('coin-${coin.name}'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color:
                                      coin == Coin.gold
                                          ? AppTheme.accent
                                          : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip:
                                        'Une ${coin.abbreviation} de moins',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed:
                                        _coins(doc, coin) == 0
                                            ? null
                                            : () => controller.save(
                                              _withCoins(
                                                doc,
                                                coin,
                                                _coins(doc, coin) - 1,
                                              ),
                                            ),
                                  ),
                                  IconButton(
                                    tooltip: 'Une ${coin.abbreviation} de plus',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed:
                                        () => controller.save(
                                          _withCoins(
                                            doc,
                                            coin,
                                            _coins(doc, coin) + 1,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Convertir des pièces',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: _card,
                  child: Column(
                    children: [
                      convert(
                        '10 pa → 1 po',
                        "Échanger toutes les pièces d'argent possibles",
                        Coin.silver,
                      ),
                      const Divider(height: 1),
                      convert(
                        '10 pc → 1 pa',
                        'Échanger toutes les pièces de cuivre possibles',
                        Coin.copper,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Historique des mouvements',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: _card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (doc.moneyLog.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('Aucun mouvement.', style: muted),
                        ),
                      for (final m in doc.moneyLog)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.label),
                                    Text(_noteDate(m.at), style: muted),
                                  ],
                                ),
                              ),
                              Text(
                                '${m.amount >= 0 ? '+' : '−'} '
                                '${m.amount.abs()} ${m.coin.abbreviation}',
                                style: TextStyle(
                                  color:
                                      m.amount >= 0
                                          ? const Color(0xFF7FA86A)
                                          : const Color(0xFFC97227),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder: (context) => _MovementDialog(doc: doc),
                    ),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un mouvement manuel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mouvement manuel (`CurrencyAddMovement.dc.html`) : description, pièce et
/// montant signé ; refusé s'il rendrait la bourse négative.
class _MovementDialog extends ConsumerStatefulWidget {
  const _MovementDialog({required this.doc});

  final CharacterDoc doc;

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

  void _add() {
    final doc = widget.doc;
    final amount = int.tryParse(
      _amount.text.trim().replaceAll(' ', '').replaceFirst('+', ''),
    );
    final label = _label.text.trim();
    final next = amount == null ? null : _coins(doc, _coin) + amount;
    final error = switch ((label.isEmpty, amount, next)) {
      (true, _, _) => 'Décris le mouvement.',
      (_, null || 0, _) => 'Indique un montant, par exemple +15 ou -3.',
      (_, _, final n?) when n < 0 =>
        'Pas assez de pièces : ${_coins(doc, _coin)} ${_coin.abbreviation}.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ref
        .read(charactersControllerProvider)
        .save(
          _withCoins(doc, _coin, next!).copyWith(
            moneyLog:
                [
                  MoneyMovement(
                    label: label,
                    coin: _coin,
                    amount: amount!,
                    at: DateTime.now(),
                  ),
                  ...doc.moneyLog,
                ].take(_maxMoneyLog).toList(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mouvement manuel'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Un gain ou une dépense hors du sac : vente à un marchand, '
              'pot-de-vin, amende…',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('movement-label'),
              controller: _label,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Description',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Coin>(
                    initialValue: _coin,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Monnaie'),
                    items: [
                      for (final c in Coin.values)
                        DropdownMenuItem(
                          value: c,
                          child: Text(_coinLabels[c]!),
                        ),
                    ],
                    onChanged: (c) => setState(() => _coin = c ?? _coin),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('movement-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[-+0-9]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Montant (+ ou −)',
                      hintText: '+15 ou -3',
                    ),
                  ),
                ),
              ],
            ),
            if (_error case final e?) ...[
              const SizedBox(height: 10),
              Text(e, style: const TextStyle(color: Color(0xFFE0806A))),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _add, child: const Text('Ajouter')),
    ],
  );
}
