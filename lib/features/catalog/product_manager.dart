import 'package:bigger_brew_store_management/features/catalog/product_option_manager.dart';
import 'package:flutter/material.dart';
import '../../core/currency/store_currency.dart';

import 'catalog_change_guard.dart';
import 'store_catalog_master_service.dart';

import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';

class ProductManagerController extends ChangeNotifier {
  ProductManagerController({
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
  List<ProductCategory> _categories = const [];
  bool _loading = false;

  List<CatalogProduct> get products => List.unmodifiable(_products);
  List<ProductCategory> get categories => List.unmodifiable(_categories);
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
      _categories = List.of(catalog.categories);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(CatalogProduct product) async {
    _validate(product);
    final index =
        _products.indexWhere((item) => item.productId == product.productId);
    if (index < 0) throw StateError('Product not found: ${product.productId}');

    final updated = List<CatalogProduct>.of(_products)..[index] = product;
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(products: updated),
      auditAction: 'Update product in store master',
    );
    _products = List.of(accepted.products);
    notifyListeners();
  }

  Future<void> add(CatalogProduct product) async {
    _validate(product);
    if (_products.any((item) => item.productId == product.productId)) {
      throw StateError('Product ID already exists: ${product.productId}');
    }
    final updated = List<CatalogProduct>.of(_products)..add(product);
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(products: updated),
      auditAction: 'Add product to store master',
    );
    _products = List.of(accepted.products);
    notifyListeners();
  }

  Future<void> setActive(CatalogProduct product, bool active) =>
      save(product.copyWith(active: active));

  Future<void> setAvailable(CatalogProduct product, bool available) =>
      save(product.copyWith(available: available));

  Future<void> delete(CatalogProduct product) async {
    final index =
        _products.indexWhere((item) => item.productId == product.productId);
    if (index < 0) throw StateError('Product not found: ${product.productId}');

    final updated = List<CatalogProduct>.of(_products)..removeAt(index);
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(products: updated),
      auditAction: 'Delete product from store master',
    );
    _products = List.of(accepted.products);
    notifyListeners();
  }

  String categoryName(String categoryId) {
    for (final category in _categories) {
      if (category.categoryId == categoryId) return category.name;
    }
    return 'Unknown category';
  }

  int pricedSizeCount(CatalogProduct product) =>
      product.sizes.where((size) => size.price != null).length;

  void _validate(CatalogProduct product) {
    if (product.productId.trim().isEmpty) {
      throw StateError('Product ID cannot be empty.');
    }
    if (product.name.trim().isEmpty) {
      throw StateError('Product name is required.');
    }
    const validTypes = {'drink', 'food', 'accessory', 'addOn'};
    if (!validTypes.contains(product.productType)) {
      throw StateError('Invalid product type: ${product.productType}');
    }
    if (!_categories
        .any((category) => category.categoryId == product.categoryId)) {
      throw StateError('Category not found: ${product.categoryId}');
    }
    if (product.price != null && product.price! < 0) {
      throw StateError('Base selling price cannot be negative.');
    }
  }
}

class ProductManagerPage extends StatefulWidget {
  const ProductManagerPage({super.key});

  @override
  State<ProductManagerPage> createState() => _ProductManagerPageState();
}

class _ProductManagerPageState extends State<ProductManagerPage> {
  final ProductManagerController _controller = ProductManagerController();
  String _search = '';
  String? _typeFilter;
  String? _categoryFilter;
  bool _showInactive = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  List<CatalogProduct> get _filtered {
    final query = _search.trim().toLowerCase();
    return _controller.products.where((product) {
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.productId.toLowerCase().contains(query) ||
          (product.sku ?? '').toLowerCase().contains(query);
      final matchesType =
          _typeFilter == null || product.productType == _typeFilter;
      final matchesCategory =
          _categoryFilter == null || product.categoryId == _categoryFilter;
      final matchesStatus = _showInactive || product.active;
      return matchesSearch && matchesType && matchesCategory && matchesStatus;
    }).toList(growable: false);
  }

  Future<void> _add() async {
    if (_controller.categories.isEmpty) {
      _message('Create a category first before adding a product.', error: true);
      return;
    }
    final product = await showDialog<CatalogProduct>(
      context: context,
      builder: (_) => _AddProductDialog(categories: _controller.categories),
    );
    if (product == null) return;
    try {
      await _controller.add(product);
      if (mounted) _message('Product added.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  Future<void> _delete(CatalogProduct product) async {
    final ok = await CatalogChangeGuard.confirm(
      context,
      title: 'Delete product?',
      message:
          '${product.name} will be permanently removed from the catalog. This also removes its product-specific sizes, variants, and option assignments. This action cannot be undone.',
      confirmLabel: 'DELETE',
    );
    if (!ok) return;

    try {
      await _controller.delete(product);
      if (mounted) _message('Product deleted.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  Future<void> _edit(CatalogProduct product) async {
    final edited = await showDialog<CatalogProduct>(
      context: context,
      builder: (_) =>
          _ProductDialog(product: product, categories: _controller.categories),
    );
    if (edited == null) return;
    try {
      await _controller.save(edited);
      if (mounted) _message('Product updated.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text('PRODUCT MANAGER',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        actions: [
          FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('ADD PRODUCT'),
              style: FilledButton.styleFrom(
                  backgroundColor: gold, foregroundColor: Colors.white)),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductOptionManagerPage())),
              icon: const Icon(Icons.extension_outlined),
              label: const Text('OPTIONS'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54))),
          const SizedBox(width: 8),
          IconButton(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'),
        ],
      ),
      body: _controller.loading && _controller.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 360,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search product, ID, or SKU',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _typeFilter,
                          decoration: const InputDecoration(
                              labelText: 'Product type',
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('All types')),
                            for (final type in const [
                              'drink',
                              'food',
                              'accessory',
                              'addOn'
                            ])
                              DropdownMenuItem<String?>(
                                  value: type, child: Text(type)),
                          ],
                          onChanged: (value) =>
                              setState(() => _typeFilter = value),
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _categoryFilter,
                          decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('All categories')),
                            ..._controller.categories
                                .map((category) => DropdownMenuItem<String?>(
                                      value: category.categoryId,
                                      child: Text(category.name),
                                    )),
                          ],
                          onChanged: (value) =>
                              setState(() => _categoryFilter = value),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Show inactive'),
                        selected: _showInactive,
                        onSelected: (value) =>
                            setState(() => _showInactive = value),
                      ),
                      Chip(label: Text('${_filtered.length} products')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final product = _filtered[index];
                      final sizeCount = product.sizes.length;
                      final pricedCount = _controller.pricedSizeCount(product);
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                product.active ? gold : Colors.grey,
                            child: Icon(
                              product.productType == 'drink'
                                  ? Icons.local_cafe
                                  : Icons.fastfood,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                  child: Text(product.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              if (!product.active)
                                const Chip(label: Text('INACTIVE')),
                              if (!product.available)
                                const Chip(label: Text('UNAVAILABLE')),
                            ],
                          ),
                          subtitle: Text(
                            '${product.productId}  •  ${product.productType}  •  ${_controller.categoryName(product.categoryId)}'
                            '${product.sku == null || product.sku!.isEmpty ? '' : '  •  SKU ${product.sku}'}\n'
                            '${sizeCount > 0 ? '$sizeCount size${sizeCount == 1 ? '' : 's'}  •  $pricedCount priced' : 'No sizes'}'
                            '${sizeCount == 0 && product.variants.isEmpty && product.price != null ? '  •  Base ${StoreCurrency.format(product.price!)}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Switch(
                                value: product.active,
                                onChanged: (value) async {
                                  if (!value) {
                                    final ok = await CatalogChangeGuard.confirm(
                                      context,
                                      title: 'Disable product?',
                                      message:
                                          '${product.name} will stop appearing as an active product on the customer kiosk. Existing catalog data and pricing will be preserved.',
                                      confirmLabel: 'DISABLE',
                                    );
                                    if (!ok) return;
                                  }
                                  await _controller.setActive(product, value);
                                },
                              ),
                              IconButton(
                                  onPressed: () => _edit(product),
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit product'),
                              IconButton(
                                onPressed: () => _delete(product),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete product',
                                color: Colors.red.shade700,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}


class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({required this.categories});

  final List<ProductCategory> categories;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late String _categoryId;
  String _productType = 'drink';
  String? _drinkTemperature = 'iced';
  bool _active = true;
  bool _available = true;
  bool _kitchenPrepared = true;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController();
    _name = TextEditingController();
    _description = TextEditingController();
    _image = TextEditingController();
    _sku = TextEditingController();
    _price = TextEditingController();
    _categoryId = widget.categories.first.categoryId;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _sku.dispose();
    _price.dispose();
    super.dispose();
  }

  String _slug(String value) {
    final slug = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'product' : slug;
  }

  num? _parsePrice() {
    final text = _price.text.trim();
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _id,
                decoration: const InputDecoration(
                  labelText: 'Product ID',
                  helperText: 'Unique stable ID. Example: iced_latte',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  if (_id.text.isEmpty) _id.text = _slug(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map((category) => DropdownMenuItem(
                          value: category.categoryId,
                          child: Text(category.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Product Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'drink', child: Text('Drink')),
                  DropdownMenuItem(value: 'food', child: Text('Food')),
                  DropdownMenuItem(value: 'accessory', child: Text('Accessory')),
                  DropdownMenuItem(value: 'addOn', child: Text('Add-on')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _productType = value);
                },
              ),
              if (_productType == 'drink') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _drinkTemperature,
                  decoration: const InputDecoration(
                    labelText: 'Drink Temperature',
                    helperText: 'Set Hot or Iced for EOD cup reporting.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hot', child: Text('Hot')),
                    DropdownMenuItem(value: 'iced', child: Text('Iced')),
                  ],
                  onChanged: (value) => setState(() => _drinkTemperature = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Customer Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'Image / Reference',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sku,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Base Selling Price (${StoreCurrency.code})',
                  helperText: 'Leave empty if this product will use size/variant pricing.',
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for sale'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kitchen prepared'),
                value: _kitchenPrepared,
                onChanged: (value) => setState(() => _kitchenPrepared = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            final id = _id.text.trim();
            final name = _name.text.trim();
            final price = _parsePrice();
            if (id.isEmpty || name.isEmpty) return;
            if (_productType == 'drink' && _drinkTemperature == null) return;
            if (_price.text.trim().isNotEmpty && (price == null || price < 0)) return;
            Navigator.pop(
              context,
              CatalogProduct(
                productId: id,
                name: name,
                productType: _productType,
                drinkTemperature: _productType == 'drink' ? _drinkTemperature : null,
                categoryId: _categoryId,
                description: _description.text.trim(),
                image: _image.text.trim(),
                active: _active,
                available: _available,
                kitchenPrepared: _kitchenPrepared,
                price: price,
                sku: _sku.text.trim(),
                sizes: const [],
                variants: const [],
                options: const [],
              ),
            );
          },
          child: const Text('CREATE PRODUCT'),
        ),
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.product, required this.categories});

  final CatalogProduct product;
  final List<ProductCategory> categories;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late String _categoryId;
  late String _productType;
  String? _drinkTemperature;
  late bool _active;
  late bool _available;
  late bool _kitchenPrepared;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p.name);
    _description = TextEditingController(text: p.description ?? '');
    _image = TextEditingController(text: p.image ?? '');
    _sku = TextEditingController(text: p.sku ?? '');
    _price = TextEditingController(text: p.price?.toString() ?? '');
    _categoryId = p.categoryId;
    _productType = p.productType;
    _drinkTemperature = p.drinkTemperature ??
        (p.productType.trim().toLowerCase() == 'drink' ? 'iced' : null);
    _active = p.active;
    _available = p.available;
    _kitchenPrepared = p.kitchenPrepared;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _sku.dispose();
    _price.dispose();
    super.dispose();
  }

  num? _parsePrice() {
    final text = _price.text.trim();
    if (text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null || value < 0) return widget.product.price;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return AlertDialog(
      title: Text('Edit ${p.name}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Product ID (stable)',
                    helperText: 'Product ID cannot be changed.',
                    border: OutlineInputBorder()),
                child: Align(
                    alignment: Alignment.centerLeft, child: Text(p.productId)),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Product Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map((category) => DropdownMenuItem(
                        value: category.categoryId, child: Text(category.name)))
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Product Type',
                  helperText: 'Changing this may affect which options/add-ons are valid.',
                ),
                items: const [
                  DropdownMenuItem(value: 'drink', child: Text('Drink')),
                  DropdownMenuItem(value: 'food', child: Text('Food')),
                  DropdownMenuItem(value: 'accessory', child: Text('Accessory')),
                  DropdownMenuItem(value: 'addOn', child: Text('Add-on')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _productType = value);
                },
              ),
              if (_productType == 'drink') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _drinkTemperature,
                  decoration: const InputDecoration(
                    labelText: 'Drink Temperature',
                    helperText: 'Set Hot or Iced for EOD cup reporting.',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hot', child: Text('Hot')),
                    DropdownMenuItem(value: 'iced', child: Text('Iced')),
                  ],
                  onChanged: (value) => setState(() => _drinkTemperature = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Customer Description')),
              const SizedBox(height: 12),
              TextField(
                  controller: _image,
                  decoration:
                      const InputDecoration(labelText: 'Image / Reference')),
              const SizedBox(height: 12),
              TextField(
                  controller: _sku,
                  decoration: const InputDecoration(labelText: 'SKU')),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                  labelText: 'Base Selling Price (${StoreCurrency.code})',
                  helperText: p.sizes.isNotEmpty || p.variants.isNotEmpty
                      ? 'Size/variant prices are authoritative for this product.'
                      : 'Used for products without size/variant pricing.',
                ),
              ),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for sale'),
                  value: _available,
                  onChanged: (value) => setState(() => _available = value)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kitchen prepared'),
                  value: _kitchenPrepared,
                  onChanged: (value) =>
                      setState(() => _kitchenPrepared = value)),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${p.sizes.length} size(s) • ${p.variants.length} variant(s) • ${p.options.length} option(s)\nThe Product Catalog is the single source of truth for selling prices.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            if (_productType == 'drink' && _drinkTemperature == null) return;
            Navigator.pop(
              context,
              p.copyWith(
                name: _name.text.trim(),
                productType: _productType,
                drinkTemperature: _productType == 'drink' ? _drinkTemperature : null,
                categoryId: _categoryId,
                description: _description.text.trim(),
                image: _image.text.trim(),
                sku: _sku.text.trim(),
                active: _active,
                available: _available,
                kitchenPrepared: _kitchenPrepared,
                price: _parsePrice(),
              ),
            );
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
