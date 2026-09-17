import 'package:flutter/material.dart';
import '../../core/currency/store_currency.dart';

import 'catalog_change_guard.dart';
import 'store_catalog_master_service.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';

class ProductSizeVariantManagerController extends ChangeNotifier {
  ProductSizeVariantManagerController({
    ProductCatalogRepository? repository,
    StoreCatalogMasterService? masterService,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _masterService = masterService ??
            StoreCatalogMasterService(
              repository: repository ?? const ProductCatalogRepository(),
            );

  final ProductCatalogRepository _repository;
  final StoreCatalogMasterService _masterService;
  List<CatalogProduct> _products = const [];
  bool _loading = false;

  List<CatalogProduct> get products => List.unmodifiable(_products);
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final catalog = await _masterService.loadMasterCatalog();
      await _repository.saveCatalog(
        catalog,
        auditAction: 'Refresh catalog from store master',
      );
      _products = List.of(catalog.products);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(CatalogProduct product) async {
    _validate(product);
    final index = _products.indexWhere((item) => item.productId == product.productId);
    if (index < 0) {
      throw StateError('Product not found: ${product.productId}');
    }
    final updated = List<CatalogProduct>.of(_products)..[index] = product;
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(products: updated),
      auditAction: 'Update product sizes and variants in store master',
    );
    _products = List.of(accepted.products);
    notifyListeners();
  }

  Future<void> addSize(CatalogProduct product, ProductSize size) async {
    _validateSize(size, product.sizes);
    await save(product.copyWith(sizes: [...product.sizes, size]));
  }

  Future<void> updateSize(CatalogProduct product, ProductSize size) async {
    final sizes = List<ProductSize>.of(product.sizes);
    final index = sizes.indexWhere((item) => item.sizeId == size.sizeId);
    if (index < 0) {
      throw StateError('Size not found: ${size.sizeId}');
    }
    _validateSize(size, product.sizes, editingId: size.sizeId);
    sizes[index] = size;
    await save(product.copyWith(sizes: sizes));
  }

  Future<void> deleteSize(CatalogProduct product, String id) async {
    await save(
      product.copyWith(
        sizes: product.sizes.where((item) => item.sizeId != id).toList(),
      ),
    );
  }

  Future<void> addVariant(CatalogProduct product, ProductVariant variant) async {
    _validateVariant(variant, product.variants);
    await save(product.copyWith(variants: [...product.variants, variant]));
  }

  Future<void> updateVariant(
    CatalogProduct product,
    ProductVariant variant,
  ) async {
    final variants = List<ProductVariant>.of(product.variants);
    final index = variants.indexWhere((item) => item.variantId == variant.variantId);
    if (index < 0) {
      throw StateError('Variant not found: ${variant.variantId}');
    }
    _validateVariant(variant, product.variants, editingId: variant.variantId);
    variants[index] = variant;
    await save(product.copyWith(variants: variants));
  }

  Future<void> deleteVariant(CatalogProduct product, String id) async {
    await save(
      product.copyWith(
        variants:
            product.variants.where((item) => item.variantId != id).toList(),
      ),
    );
  }

  void _validate(CatalogProduct product) {
    if (product.sizes.map((item) => item.sizeId).toSet().length !=
        product.sizes.length) {
      throw StateError('Duplicate size ID.');
    }
    if (product.variants.map((item) => item.variantId).toSet().length !=
        product.variants.length) {
      throw StateError('Duplicate variant ID.');
    }
  }

  void _validateSize(
    ProductSize size,
    List<ProductSize> existing, {
    String? editingId,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(size.sizeId)) {
      throw StateError(
        'Size ID must use lowercase letters, numbers, and underscores.',
      );
    }
    if (size.name.trim().isEmpty) {
      throw StateError('Size name is required.');
    }
    if (size.price != null && size.price! < 0) {
      throw StateError('Size price cannot be negative.');
    }
    if (existing.any((item) =>
        item.sizeId == size.sizeId && item.sizeId != editingId)) {
      throw StateError('Size ID already exists.');
    }
  }

  void _validateVariant(
    ProductVariant variant,
    List<ProductVariant> existing, {
    String? editingId,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(variant.variantId)) {
      throw StateError(
        'Variant ID must use lowercase letters, numbers, and underscores.',
      );
    }
    if (variant.name.trim().isEmpty) {
      throw StateError('Variant name is required.');
    }
    if (variant.price != null && variant.price! < 0) {
      throw StateError('Variant price cannot be negative.');
    }
    if (existing.any((item) =>
        item.variantId == variant.variantId && item.variantId != editingId)) {
      throw StateError('Variant ID already exists.');
    }
  }
}

class ProductSizeVariantManagerPage extends StatefulWidget {
  const ProductSizeVariantManagerPage({super.key});

  @override
  State<ProductSizeVariantManagerPage> createState() =>
      _ProductSizeVariantManagerPageState();
}

class _ProductSizeVariantManagerPageState
    extends State<ProductSizeVariantManagerPage> {
  final _controller = ProductSizeVariantManagerController();
  String _search = '';
  CatalogProduct? _selected;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      final selectedId = _selected?.productId;
      if (selectedId == null) return;
      _selected = _controller.products.firstWhere(
        (product) => product.productId == selectedId,
        orElse: () => _selected!,
      );
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  List<CatalogProduct> get _filtered {
    final query = _search.toLowerCase().trim();
    if (query.isEmpty) return _controller.products;
    return _controller.products
        .where((product) =>
            product.name.toLowerCase().contains(query) ||
            product.productId.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _msg(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  Future<void> _editSize(CatalogProduct product, ProductSize? current) async {
    final result = await showDialog<ProductSize>(
      context: context,
      builder: (_) => _SizeDialog(size: current),
    );
    if (result == null) return;
    try {
      if (current == null) {
        await _controller.addSize(product, result);
      } else {
        await _controller.updateSize(product, result);
      }
    } catch (error) {
      _msg(error);
    }
  }

  Future<void> _editVariant(
    CatalogProduct product,
    ProductVariant? current,
  ) async {
    final result = await showDialog<ProductVariant>(
      context: context,
      builder: (_) => _VariantDialog(variant: current),
    );
    if (result == null) return;
    try {
      if (current == null) {
        await _controller.addVariant(product, result);
      } else {
        await _controller.updateVariant(product, result);
      }
    } catch (error) {
      _msg(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);
    final selected = _selected;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'SIZE & VARIANT MANAGER',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _controller.loading ? null : _controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 370,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search product or ID',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final product = _filtered[index];
                      final active = selected?.productId == product.productId;
                      return ListTile(
                        selected: active,
                        selectedTileColor: gold.withValues(alpha: 0.12),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${product.productId}\n${product.sizes.length} sizes • ${product.variants.length} variants',
                        ),
                        isThreeLine: true,
                        onTap: () => setState(() => _selected = product),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const Center(child: Text('Select a product'))
                : _detail(selected),
          ),
        ],
      ),
    );
  }

  Widget _detail(CatalogProduct product) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          product.name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        Text(product.productId, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        _section(
          'SIZES',
          product.sizes.length,
          () => _editSize(product, null),
          product.sizes
              .map(
                (size) => _row(
                  size.name,
                  '${size.displayVolume ?? ''}'
                  '${size.price == null ? ' • no price' : ' • ${StoreCurrency.format(size.price!)}'}',
                  () => _editSize(product, size),
                  () => _controller.deleteSize(product, size.sizeId),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 24),
        _section(
          'VARIANTS',
          product.variants.length,
          () => _editVariant(product, null),
          product.variants
              .map(
                (variant) => _row(
                  variant.name,
                  '${variant.active ? 'Active' : 'Inactive'}'
                  '${variant.price == null ? ' • no price' : ' • ${StoreCurrency.format(variant.price!)}'}',
                  () => _editVariant(product, variant),
                  () => _controller.deleteVariant(product, variant.variantId),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    int count,
    VoidCallback add,
    List<Widget> rows,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$title  ($count)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD'),
                ),
              ],
            ),
            const Divider(),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(
    String title,
    String subtitle,
    VoidCallback edit,
    Future<void> Function() remove,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Wrap(
        children: [
          IconButton(
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () async {
              final ok = await CatalogChangeGuard.confirm(
                context,
                title: 'Delete item?',
                message:
                    'Delete $title? This removes the size/variant from this product and cannot be undone.',
                confirmLabel: 'DELETE',
                destructive: true,
              );
              if (ok) await remove();
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _SizeDialog extends StatefulWidget {
  const _SizeDialog({this.size});

  final ProductSize? size;

  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _volume;
  late final TextEditingController _display;
  late final TextEditingController _price;
  String? _error;

  @override
  void initState() {
    super.initState();
    final size = widget.size;
    _id = TextEditingController(text: size?.sizeId ?? '');
    _name = TextEditingController(text: size?.name ?? '');
    _volume = TextEditingController(text: size?.volumeMl?.toString() ?? '');
    _display = TextEditingController(text: size?.displayVolume ?? '');
    _price = TextEditingController(text: size?.price?.toString() ?? '');
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _volume.dispose();
    _display.dispose();
    _price.dispose();
    super.dispose();
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _setError(String message) {
    setState(() => _error = message);
  }

  void _save() {
    final name = _name.text.trim();
    final id = widget.size == null
        ? _slug(_id.text.trim().isEmpty ? name : _id.text)
        : _id.text.trim();
    final volumeText = _volume.text.trim();
    final priceText = _price.text.trim();

    if (name.isEmpty) {
      _setError('Size name is required.');
      return;
    }
    if (id.isEmpty || !RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(id)) {
      _setError('Enter a valid Size ID, e.g. regular or go_big.');
      return;
    }
    if (volumeText.isNotEmpty && int.tryParse(volumeText) == null) {
      _setError('Volume must be a whole number in ml.');
      return;
    }
    if (priceText.isNotEmpty && double.tryParse(priceText) == null) {
      _setError('Selling price must be a valid number.');
      return;
    }
    final price = priceText.isEmpty ? null : double.parse(priceText);
    if (price != null && price < 0) {
      _setError('Selling price cannot be negative.');
      return;
    }

    Navigator.pop(
      context,
      ProductSize(
        sizeId: id,
        name: name,
        volumeMl: volumeText.isEmpty ? null : int.parse(volumeText),
        displayVolume:
            _display.text.trim().isEmpty ? null : _display.text.trim(),
        price: price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.size == null ? 'ADD SIZE' : 'EDIT SIZE'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: .3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextField(
                controller: _id,
                readOnly: widget.size != null,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Size ID',
                  helperText: widget.size == null
                      ? 'Example: regular, go_big, go_bigger. Spaces are converted to underscores.'
                      : 'Stable ID',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _volume,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Volume (ml)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _display,
                decoration: const InputDecoration(
                  labelText: 'Display volume',
                  hintText: 'e.g. 12oz',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Selling price',
                  prefixText: StoreCurrency.symbol,
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _VariantDialog extends StatefulWidget {
  const _VariantDialog({this.variant});

  final ProductVariant? variant;

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _active;
  String? _error;

  @override
  void initState() {
    super.initState();
    final variant = widget.variant;
    _id = TextEditingController(text: variant?.variantId ?? '');
    _name = TextEditingController(text: variant?.name ?? '');
    _price = TextEditingController(text: variant?.price?.toString() ?? '');
    _active = variant?.active ?? true;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _setError(String message) {
    setState(() => _error = message);
  }

  void _save() {
    final name = _name.text.trim();
    final id = widget.variant == null
        ? _slug(_id.text.trim().isEmpty ? name : _id.text)
        : _id.text.trim();
    final priceText = _price.text.trim();

    if (name.isEmpty) {
      _setError('Variant name is required.');
      return;
    }
    if (id.isEmpty || !RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(id)) {
      _setError('Enter a valid Variant ID, e.g. classic or cheese_foam.');
      return;
    }
    if (priceText.isNotEmpty && double.tryParse(priceText) == null) {
      _setError('Selling price must be a valid number.');
      return;
    }
    final price = priceText.isEmpty ? null : double.parse(priceText);
    if (price != null && price < 0) {
      _setError('Selling price cannot be negative.');
      return;
    }

    Navigator.pop(
      context,
      ProductVariant(
        variantId: id,
        name: name,
        price: price,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.variant == null ? 'ADD VARIANT' : 'EDIT VARIANT'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: .3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextField(
                controller: _id,
                readOnly: widget.variant != null,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Variant ID',
                  helperText: widget.variant == null
                      ? 'Example: classic, cheese_foam. Spaces are converted to underscores.'
                      : 'Stable ID',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Selling price',
                  prefixText: StoreCurrency.symbol,
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Active'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('SAVE'),
        ),
      ],
    );
  }
}
