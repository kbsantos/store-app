import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';

class ProductRecipesPage extends StatefulWidget {
  const ProductRecipesPage({super.key});

  @override
  State<ProductRecipesPage> createState() => _ProductRecipesPageState();
}

class _ProductRecipesPageState extends State<ProductRecipesPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _auth.client.rpc('get_store_product_recipes');
      final inventory = await _auth.client.rpc('get_store_inventory_items');
      final recipes = ((result as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final items = ((inventory as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['is_active'] != false)
          .toList();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _inventory = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _recipes;
    return _recipes.where((r) =>
      (r['product_name']?.toString().toLowerCase() ?? '').contains(q) ||
      (r['product_id']?.toString().toLowerCase() ?? '').contains(q)).toList();
  }

  bool get _canEdit => _auth.canManageInventory;

  Future<void> _add() async {
    final products = <String, String>{};
    for (final r in _recipes) {
      final id = r['product_id']?.toString() ?? '';
      final name = r['product_name']?.toString() ?? id;
      if (id.isNotEmpty) products[id] = name;
    }
    if (products.isEmpty) {
      _snack('No catalog products are available.', error: true);
      return;
    }
    final selected = await showDialog<_RecipeInput>(
      context: context,
      builder: (_) => _RecipeDialog(products: products, inventory: _inventory),
    );
    if (selected == null) return;
    try {
      await _auth.client.rpc('save_store_product_recipe', params: {
        'p_product_id': selected.productId,
        'p_items': selected.items,
      });
      if (mounted) _snack('Recipe saved.');
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('PRODUCT RECIPES', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_canEdit) FilledButton.icon(
            onPressed: _add, icon: const Icon(Icons.add), label: const Text('ADD / EDIT RECIPE'),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PRODUCT RECIPES', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Define the inventory ingredients and quantities used by each catalog product.'),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search product',
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
                    ? const Center(child: Text('No product recipes found.'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final count = (r['ingredient_count'] as num?)?.toInt() ?? 0;
                          final items = (r['items'] as List? ?? const [])
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .toList();
                          final preview = items.take(3).map((item) {
                            final name = item['inventory_item_name']?.toString() ?? 'Ingredient';
                            final qty = item['quantity']?.toString() ?? '';
                            final unit = item['unit']?.toString() ?? '';
                            return '$name $qty${unit.isEmpty ? '' : ' $unit'}';
                          }).join(' • ');
                          final more = items.length > 3 ? ' • +${items.length - 3} more' : '';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(count == 0 ? Icons.warning_amber_outlined : Icons.menu_book_outlined),
                              ),
                              title: Text(r['product_name']?.toString() ?? r['product_id']?.toString() ?? ''),
                              subtitle: Text(
                                count == 0
                                    ? 'NO RECIPE • ${r['product_id'] ?? ''}'
                                    : '$count ingredient${count == 1 ? '' : 's'} • $preview$more',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _canEdit ? () async {
                                final selected = await showDialog<_RecipeInput>(
                                  context: context,
                                  builder: (_) => _RecipeDialog(
                                    products: {r['product_id'].toString(): r['product_name']?.toString() ?? r['product_id'].toString()},
                                    inventory: _inventory,
                                    existing: (r['items'] as List? ?? const [])
                                      .map((e) => Map<String,dynamic>.from(e as Map)).toList(),
                                  ),
                                );
                                if (selected == null) return;
                                try {
                                  await _auth.client.rpc('save_store_product_recipe', params: {
                                    'p_product_id': selected.productId,
                                    'p_items': selected.items,
                                  });
                                  if (mounted) _snack('Recipe saved.');
                                  await _load();
                                } catch (e) {
                                  if (mounted) _snack(e.toString(), error: true);
                                }
                              } : null,
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
  final List<Map<String, dynamic>> items;
  _RecipeInput(this.productId, this.items);
}

class _RecipeDialog extends StatefulWidget {
  final Map<String, String> products;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> existing;
  const _RecipeDialog({required this.products, required this.inventory, this.existing = const []});
  @override State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  late String _productId;
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _productId = widget.products.keys.first;
    _items = widget.existing.map((e) => {
      'inventory_item_id': e['inventory_item_id'],
      'quantity': e['quantity'],
    }).toList();
  }

  void _addLine() {
    setState(() => _items.add({'inventory_item_id': null, 'quantity': 0}));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Recipe — ${widget.products[_productId]}'),
      content: SizedBox(
        width: 620,
        height: 430,
        child: Column(
          children: [
            if (widget.products.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _productId,
                items: widget.products.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _productId = v!),
                decoration: const InputDecoration(labelText: 'Product'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final line = _items[i];
                  final selected = line['inventory_item_id']?.toString();
                  final valid = widget.inventory.any((x) => x['id']?.toString() == selected);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(
                          initialValue: valid ? selected : null,
                          items: widget.inventory.map((x) => DropdownMenuItem(
                            value: x['id']?.toString(),
                            child: Text('${x['name'] ?? ''} (${x['unit'] ?? ''})'),
                          )).toList(),
                          onChanged: (v) => line['inventory_item_id'] = v,
                          decoration: const InputDecoration(labelText: 'Ingredient'),
                        )),
                        const SizedBox(width: 10),
                        SizedBox(width: 130, child: TextFormField(
                          initialValue: line['quantity']?.toString() ?? '',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onChanged: (v) => line['quantity'] = double.tryParse(v) ?? 0,
                        )),
                        IconButton(onPressed: () => setState(() => _items.removeAt(i)), icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: _addLine, icon: const Icon(Icons.add), label: const Text('ADD INGREDIENT'),
            )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        if (_items.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() => _items.clear());
            },
            child: const Text('CLEAR RECIPE'),
          ),
        FilledButton(onPressed: () {
          final cleaned = <Map<String,dynamic>>[];
          for (final line in _items) {
            final id = line['inventory_item_id']?.toString() ?? '';
            final qty = line['quantity'] is num ? (line['quantity'] as num).toDouble() : double.tryParse(line['quantity']?.toString() ?? '') ?? 0;
            if (id.isEmpty || qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Each ingredient needs an item and a quantity greater than zero.')));
              return;
            }
            cleaned.add({'inventory_item_id': id, 'quantity': qty});
          }
          Navigator.pop(context, _RecipeInput(_productId, cleaned));
        }, child: const Text('SAVE')),
      ],
    );
  }
}
