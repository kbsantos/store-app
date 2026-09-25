import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';

class ProductRecipesPage extends StatefulWidget {
  const ProductRecipesPage({super.key, this.loadOnInit = true});

  /// Allows widget tests to validate the static UI without requiring a live
  /// Supabase session/network call. Production keeps the default behavior.
  final bool loadOnInit;

  @override
  State<ProductRecipesPage> createState() => _ProductRecipesPageState();
}

class _ProductRecipesPageState extends State<ProductRecipesPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  final _catalogRepository = const ProductCatalogRepository();

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _inventory = [];
  List<CatalogProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.loadOnInit) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _auth.client.rpc('get_store_product_recipes'),
        _auth.client.rpc('get_store_inventory_items'),
        _catalogRepository.load(),
      ]);

      final recipes = ((results[0] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final inventory = ((results[1] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['is_active'] != false)
          .toList();
      final catalog = results[2] as ProductCatalog;

      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _inventory = inventory;
        _products = catalog.products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final recipeProductIds = _recipeProducts.map((p) => p.productId).toSet();
    final recipeRows = _recipes
        .where((r) => recipeProductIds.contains(r['product_id']?.toString()))
        .toList(growable: false);
    if (q.isEmpty) return recipeRows;
    return recipeRows.where((r) {
      return (r['product_name']?.toString().toLowerCase() ?? '').contains(q) ||
          (r['product_id']?.toString().toLowerCase() ?? '').contains(q) ||
          (r['size_name']?.toString().toLowerCase() ?? '').contains(q) ||
          (r['size_id']?.toString().toLowerCase() ?? '').contains(q);
    }).toList();
  }

  bool get _canEdit => widget.loadOnInit && _auth.canManageInventory;

  /// Only catalog products with a recipeRef participate in the Store recipe
  /// workflow. recipeRef is the neutral cross-app recipe identity; the Store
  /// remains authoritative for inventory quantities.
  List<CatalogProduct> get _recipeProducts => _products
      .where((product) => product.recipeRef?.trim().isNotEmpty == true)
      .toList(growable: false);

  CatalogProduct? _product(String id) {
    for (final product in _products) {
      if (product.productId == id) return product;
    }
    return null;
  }

  String _sizeLabel(Map<String, dynamic> row, CatalogProduct? product) {
    final id = row['size_id']?.toString().trim() ?? '';
    if (id.isNotEmpty && product != null) {
      for (final size in product.sizes) {
        if (size.sizeId == id) {
          return size.name.isEmpty ? id : size.name;
        }
      }
    }
    final name = row['size_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    if (id.isNotEmpty) return id;
    return 'Base recipe';
  }

  List<Map<String, dynamic>> _itemsFor(Map<String, dynamic> row) {
    final raw = row['items'];
    if (raw is! List) return const [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> _openRecipe({
    required CatalogProduct product,
    String? sizeId,
    List<Map<String, dynamic>> existing = const [],
  }) async {
    final size = product.sizes.where((s) => s.sizeId == sizeId).firstOrNull;
    final selected = await showDialog<_RecipeInput>(
      context: context,
      builder: (_) => _RecipeDialog(
        product: product,
        selectedSizeId: size?.sizeId,
        inventory: _inventory,
        existing: existing,
      ),
    );
    if (selected == null) return;

    try {
      await _auth.client.rpc('save_store_product_recipe', params: {
        'p_product_id': selected.productId,
        'p_size_id': selected.sizeId,
        'p_items': selected.items,
      });
      if (mounted) _snack('Recipe saved.');
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  Future<void> _add() async {
    final products = _recipeProducts;
    if (products.isEmpty) {
      _snack('No catalog products with recipe references are available.', error: true);
      return;
    }

    final product = await showDialog<CatalogProduct>(
      context: context,
      builder: (_) => _ProductPickerDialog(products: products),
    );
    if (product == null || !mounted) return;

    String? sizeId;
    if (product.sizes.isNotEmpty) {
      sizeId = await showDialog<String>(
        context: context,
        builder: (_) => _SizePickerDialog(product: product),
      );
      if (!mounted || sizeId == null) return;
    }

    final existing = _recipesFor(product.productId).where((row) {
      final rowSize = row['size_id']?.toString();
      return rowSize == sizeId;
    }).toList();

    await _openRecipe(
      product: product,
      sizeId: sizeId,
      existing: existing.isNotEmpty ? _itemsFor(existing.first) : const [],
    );
  }

  List<Map<String, dynamic>> _recipesFor(String productId) {
    return _recipes.where((r) => r['product_id']?.toString() == productId).toList();
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade800 : null,
      ),
    );
  }

  List<String> _recipeIntegrityIssues() {
    final issues = <String>[];
    final activeInventoryIds = _inventory
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();

    for (final product in _recipeProducts) {
      final productRows = _recipesFor(product.productId);
      final expectedSizes = product.sizes
          .where((size) => size.sizeId.trim().isNotEmpty)
          .map((size) => size.sizeId)
          .toList(growable: false);

      if (expectedSizes.isEmpty) {
        final row = productRows.where((r) => r['size_id'] == null).firstOrNull;
        if (row == null || _itemsFor(row).isEmpty) {
          issues.add('${product.name} (${product.productId}): base recipe is missing or empty.');
        }
      } else {
        for (final sizeId in expectedSizes) {
          final row = productRows
              .where((r) => r['size_id']?.toString() == sizeId)
              .firstOrNull;
          if (row == null || _itemsFor(row).isEmpty) {
            issues.add('${product.name} (${sizeId}): recipe is missing or empty.');
          }
        }
      }

      for (final row in productRows) {
        final sizeLabel = _sizeLabel(row, product);
        final seen = <String>{};
        for (final item in _itemsFor(row)) {
          final inventoryId = item['inventory_item_id']?.toString() ?? '';
          if (inventoryId.isEmpty) {
            issues.add('${product.name} / $sizeLabel: ingredient has no inventory item.');
            continue;
          }
          if (!activeInventoryIds.contains(inventoryId)) {
            final name = item['inventory_item_name']?.toString() ?? inventoryId;
            issues.add('${product.name} / $sizeLabel: inventory item "$name" is missing or inactive.');
          }
          if (!seen.add(inventoryId)) {
            final name = item['inventory_item_name']?.toString() ?? inventoryId;
            issues.add('${product.name} / $sizeLabel: duplicate ingredient "$name".');
          }

          final quantity = item['quantity'];
          final quantityText = item['quantity_text']?.toString().trim() ?? '';
          final numeric = quantity is num
              ? quantity.toDouble()
              : double.tryParse(quantity?.toString() ?? '');
          if (numeric == null && quantityText.isEmpty) {
            final name = item['inventory_item_name']?.toString() ?? inventoryId;
            issues.add('${product.name} / $sizeLabel: "$name" has no quantity.');
          } else if (numeric != null && numeric <= 0) {
            final name = item['inventory_item_name']?.toString() ?? inventoryId;
            issues.add('${product.name} / $sizeLabel: "$name" has an invalid quantity.');
          }
        }
      }
    }

    return issues;
  }

  Future<void> _checkIntegrity() async {
    if (_loading) return;
    final issues = _recipeIntegrityIssues();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              issues.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              color: issues.isEmpty ? Colors.green.shade700 : Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            const Text('RECIPE INTEGRITY'),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: issues.isEmpty
              ? const Text(
                  'All catalog products with recipe references have valid recipe rows for their active sizes, with active inventory items and valid quantities.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: issues.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, index) => Text(
                    issues[index],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'PRODUCT RECIPES',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _checkIntegrity,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('CHECK INTEGRITY'),
          ),
          const SizedBox(width: 8),
          if (_canEdit)
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('ADD / EDIT RECIPE'),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRODUCT RECIPES',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Define the inventory ingredients and quantities used by each recipe product and size. ${_recipeProducts.length} catalog products have recipe references.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search product or size',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : rows.isEmpty
                          ? const Center(
                              child: Text('No product recipes found.'),
                            )
                          : ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final productId =
                                    row['product_id']?.toString() ?? '';
                                final product = _product(productId);
                                final items = _itemsFor(row);
                                final count =
                                    (row['ingredient_count'] as num?)?.toInt() ??
                                        items.length;
                                final preview = items.take(3).map((item) {
                                  final name =
                                      item['inventory_item_name']?.toString() ??
                                          'Ingredient';
                                  final quantity =
                                      item['quantity']?.toString().trim() ?? '';
                                  final quantityText =
                                      item['quantity_text']?.toString().trim() ??
                                          '';
                                  final unit =
                                      item['unit']?.toString().trim() ?? '';
                                  final amount = quantity.isNotEmpty
                                      ? '$quantity${unit.isEmpty ? '' : ' $unit'}'
                                      : quantityText;
                                  return '$name${amount.isEmpty ? '' : ' $amount'}';
                                }).join(' • ');
                                final more = items.length > 3
                                    ? ' • +${items.length - 3} more'
                                    : '';

                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        count == 0
                                            ? Icons.warning_amber_outlined
                                            : Icons.menu_book_outlined,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row['product_name']?.toString() ??
                                                product?.name ??
                                                productId,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Chip(label: Text(_sizeLabel(row, product))),
                                      ],
                                    ),
                                    subtitle: Text(
                                      count == 0
                                          ? 'NO RECIPE • $productId'
                                          : '$count ingredient${count == 1 ? '' : 's'} • $preview$more',
                                    ),
                                    trailing: _canEdit
                                        ? const Icon(Icons.chevron_right)
                                        : null,
                                    onTap: _canEdit && product != null
                                        ? () => _openRecipe(
                                              product: product,
                                              sizeId: row['size_id']?.toString(),
                                              existing: items,
                                            )
                                        : null,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeInput {
  final String productId;
  final String? sizeId;
  final List<Map<String, dynamic>> items;

  const _RecipeInput(this.productId, this.sizeId, this.items);
}

class _ProductPickerDialog extends StatelessWidget {
  final List<CatalogProduct> products;

  const _ProductPickerDialog({required this.products});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SELECT PRODUCT'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final product = products[index];
            return ListTile(
              title: Text(product.name),
              subtitle: Text(
                '${product.productId} • ${product.productType}'
                '${product.sizes.isEmpty ? '' : ' • ${product.sizes.length} sizes'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(product),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

class _SizePickerDialog extends StatelessWidget {
  final CatalogProduct product;

  const _SizePickerDialog({required this.product});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('SELECT SIZE — ${product.name}'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: product.sizes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final size = product.sizes[index];
            return ListTile(
              title: Text(size.name.isEmpty ? size.sizeId : size.name),
              subtitle: Text(size.sizeId),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(size.sizeId),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

class _RecipeDialog extends StatefulWidget {
  final CatalogProduct product;
  final String? selectedSizeId;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> existing;

  const _RecipeDialog({
    required this.product,
    required this.selectedSizeId,
    required this.inventory,
    this.existing = const [],
  });

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  late String? _sizeId;
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _sizeId = widget.selectedSizeId ??
        (widget.product.sizes.isNotEmpty
            ? widget.product.sizes.first.sizeId
            : null);
    _items = widget.existing
        .map(
          (e) => {
            'inventory_item_id': e['inventory_item_id'],
            'quantity': e['quantity'],
            'quantity_text': e['quantity_text'],
          },
        )
        .toList();
  }

  void _addLine() {
    setState(
      () => _items.add({
        'inventory_item_id': null,
        'quantity': null,
        'quantity_text': '',
      }),
    );
  }

  String _initialAmount(Map<String, dynamic> line) {
    final quantity = line['quantity'];
    if (quantity != null && quantity.toString().trim().isNotEmpty) {
      return quantity.toString();
    }
    return line['quantity_text']?.toString() ?? '';
  }

  String _quantityLabel(Map<String, dynamic> line) {
    final id = line['inventory_item_id']?.toString();
    if (id == null || id.isEmpty) return 'Quantity';
    for (final item in widget.inventory) {
      if (item['id']?.toString() == id) {
        final unit = item['unit']?.toString().trim() ?? '';
        return unit.isEmpty ? 'Quantity' : 'Quantity ($unit)';
      }
    }
    return 'Quantity';
  }

  @override
  Widget build(BuildContext context) {
    final hasSizes = widget.product.sizes.isNotEmpty;
    final selectedSize = widget.product.sizes
        .where((size) => size.sizeId == _sizeId)
        .firstOrNull;

    return AlertDialog(
      title: Text(
        'Recipe — ${widget.product.name}'
        '${selectedSize == null ? '' : ' • ${selectedSize.name}'}',
      ),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          children: [
            if (hasSizes)
              Align(
                alignment: Alignment.centerLeft,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Product size',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedSize == null
                        ? (_sizeId ?? 'Unknown')
                        : '${selectedSize.name} (${selectedSize.sizeId})',
                  ),
                ),
              ),
            if (hasSizes) const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No ingredients yet. Add the inventory items used for this recipe.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final line = _items[i];
                        final selected =
                            line['inventory_item_id']?.toString();
                        final valid = widget.inventory.any(
                          (x) => x['id']?.toString() == selected,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  initialValue: valid ? selected : null,
                                  items: widget.inventory
                                      .map(
                                        (x) => DropdownMenuItem(
                                          value: x['id']?.toString(),
                                          child: Text(
                                            '${x['name'] ?? ''} (${x['unit'] ?? ''})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => line['inventory_item_id'] =
                                          value),
                                  decoration: const InputDecoration(
                                    labelText: 'Inventory item',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  key: ValueKey(
                                    '${selected}_${line['quantity']}_${line['quantity_text']}',
                                  ),
                                  initialValue: _initialAmount(line),
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: _quantityLabel(line),
                                    hintText: 'e.g. 15 or Full',
                                  ),
                                  onChanged: (value) {
                                    final parsed =
                                        double.tryParse(value.trim());
                                    line['quantity'] = parsed;
                                    line['quantity_text'] =
                                        parsed == null ? value.trim() : '';
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove ingredient',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('ADD INGREDIENT'),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'For qualitative recipe values such as "Full", enter the value as text. Numeric quantities use the inventory item unit.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        if (_items.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _items.clear()),
            child: const Text('CLEAR RECIPE'),
          ),
        FilledButton(
          onPressed: () {
            final cleaned = <Map<String, dynamic>>[];
            final seen = <String>{};

            for (final line in _items) {
              final id = line['inventory_item_id']?.toString() ?? '';
              final quantityText =
                  line['quantity_text']?.toString().trim() ?? '';
              final quantity = line['quantity'];
              final numeric = quantity is num
                  ? quantity.toDouble()
                  : double.tryParse(quantity?.toString() ?? '');

              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Each ingredient needs an inventory item.'),
                  ),
                );
                return;
              }

              if (!seen.add(id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'An inventory item can only appear once in a recipe size.',
                    ),
                  ),
                );
                return;
              }

              if (numeric != null && numeric > 0) {
                cleaned.add({
                  'inventory_item_id': id,
                  'quantity': numeric,
                  'quantity_text': null,
                });
              } else if (quantityText.isNotEmpty) {
                cleaned.add({
                  'inventory_item_id': id,
                  'quantity': null,
                  'quantity_text': quantityText,
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Each ingredient needs a quantity or quantity text.',
                    ),
                  ),
                );
                return;
              }
            }

            Navigator.pop(
              context,
              _RecipeInput(widget.product.productId, _sizeId, cleaned),
            );
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
