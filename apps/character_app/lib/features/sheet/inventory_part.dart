part of 'character_sheet_screen.dart';

/// Onglet Sac (`CharSheetInventory.dc.html`) : bourse, objets portés (une
/// armure et un bouclier portés donnent la CA), objets avec quantité, et
/// ajout depuis le catalogue (armes et armures du pack) ou un nom libre.
/// Bourse détaillée, charge, harmonisation et charges viendront avec leurs
/// maquettes.
class _Bag extends ConsumerWidget {
  const _Bag({required this.doc, required this.pack});

  final CharacterDoc doc;
  final ContentPack? pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.textMuted,
    );
    final controller = ref.read(charactersControllerProvider);
    final weapons = pack?.weapons ?? const <WeaponDef>[];
    final armors = pack?.armors ?? const <ArmorDef>[];

    String? kind(InventoryItem item) {
      if (armorForItem(item.name, armors) case final a?) {
        return a.category == ArmorCategory.shield
            ? '+${a.baseAc} CA'
            : 'Armure · CA ${a.baseAc}';
      }
      if (weaponForItem(item.name, weapons) case final w?) {
        return 'Arme · ${w.damage} ${w.damageType}';
      }
      return null;
    }

    void replace(int index, InventoryItem? item) => controller.save(
      doc.copyWith(
        inventory: [
          for (final (i, it) in doc.inventory.indexed)
            if (i != index) it else if (item != null) item,
        ],
      ),
    );

    Widget row(int index, InventoryItem item) {
      final description = kind(item);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: _card,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name),
                    if (description != null) Text(description, style: muted),
                  ],
                ),
              ),
              if (description != null)
                TextButton(
                  key: Key('equip-${item.name}'),
                  onPressed:
                      () => replace(
                        index,
                        item.copyWith(equipped: !item.equipped),
                      ),
                  child: Text(item.equipped ? 'Retirer' : 'Équiper'),
                ),
              IconButton(
                tooltip: 'Un ${item.name} de moins',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 16),
                onPressed:
                    () => replace(
                      index,
                      item.quantity > 1
                          ? item.copyWith(quantity: item.quantity - 1)
                          : null,
                    ),
              ),
              Text('${item.quantity}'),
              IconButton(
                tooltip: 'Un ${item.name} de plus',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 16),
                onPressed:
                    () => replace(
                      index,
                      item.copyWith(quantity: item.quantity + 1),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final equipped = [
      for (final (i, it) in doc.inventory.indexed)
        if (it.equipped) (i, it),
    ];
    final others = [
      for (final (i, it) in doc.inventory.indexed)
        if (!it.equipped) (i, it),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Bourse',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _card,
            child: Text(
              '${doc.gold} po',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Équipé',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (equipped.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _card,
                  child: Text(
                    'Rien de porté : équipe une armure, un bouclier ou une '
                    'arme ci-dessous.',
                    style: muted,
                  ),
                ),
              for (final (i, it) in equipped) row(i, it),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Objets',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (others.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _card,
                  child: Text('Aucun objet.', style: muted),
                ),
              for (final (i, it) in others) row(i, it),
              OutlinedButton.icon(
                onPressed:
                    () => _showAddItem(
                      context,
                      doc: doc,
                      catalog: [
                        for (final a in armors) a.name,
                        for (final w in weapons) w.name,
                      ],
                    ),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un objet'),
              ),
            ],
          ),
        ),
        if (doc.languages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Langues',
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _card,
              child: Text(doc.languages.join(', ')),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ajout d'un objet (`CharSheetAddItem.dc.html`) : recherche dans le
/// catalogue, ou nom libre (`CharSheetAddItemCustom`). Un objet déjà dans le
/// sac voit sa quantité augmenter.
Future<void> _showAddItem(
  BuildContext context, {
  required CharacterDoc doc,
  required List<String> catalog,
}) => showDialog<void>(
  context: context,
  builder: (context) => _AddItemDialog(doc: doc, catalog: catalog),
);

class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog({required this.doc, required this.catalog});

  final CharacterDoc doc;
  final List<String> catalog;

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _add(String name) {
    final doc = widget.doc;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = doc.inventory.indexWhere(
      (i) => i.name.toLowerCase() == trimmed.toLowerCase(),
    );
    ref
        .read(charactersControllerProvider)
        .save(
          doc.copyWith(
            inventory: [
              for (final (i, it) in doc.inventory.indexed)
                i == index ? it.copyWith(quantity: it.quantity + 1) : it,
              if (index < 0) InventoryItem(name: trimmed),
            ],
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final matches = [
      for (final name in widget.catalog)
        if (name.toLowerCase().contains(query)) name,
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajouter un objet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('add-item-field'),
                controller: _query,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Chercher, ou nommer un objet',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _add,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final name in matches)
                      ListTile(
                        dense: true,
                        title: Text(name),
                        trailing: const Icon(Icons.add, color: AppTheme.accent),
                        onTap: () => _add(name),
                      ),
                    if (query.isNotEmpty &&
                        !matches.any((m) => m.toLowerCase() == query))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(
                          'Objet personnalisé : ${_query.text.trim()}',
                        ),
                        onTap: () => _add(_query.text),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
