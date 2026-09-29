import 'package:flutter/material.dart';
import '../../core/currency/store_currency.dart';

import 'catalog_change_guard.dart';
import 'store_catalog_master_service.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';

class ProductOptionManagerController extends ChangeNotifier {
  ProductOptionManagerController({
    ProductCatalogRepository? repository,
    StoreCatalogMasterService? masterService,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _masterService = masterService ??
            StoreCatalogMasterService(
              repository: repository ?? const ProductCatalogRepository(),
            );

  final ProductCatalogRepository _repository;
  final StoreCatalogMasterService _masterService;
  ProductCatalog? _catalog;
  bool loading = false;

  List<CatalogProduct> get products => _catalog?.products ?? const [];
  List<CatalogOptionDefinition> get definitions =>
      _catalog?.optionDefinitions ?? const [];
  List<CatalogAutomaticCharge> get automaticCharges =>
      _catalog?.automaticCharges ?? const [];
  List<ProductCategory> get categories => _catalog?.categories ?? const [];

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _catalog = await _masterService.loadMasterCatalog();
      await _repository.saveCatalog(_catalog!, auditAction: 'Refresh catalog from store master');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveDefinitions(List<CatalogOptionDefinition> value) async {
    _catalog = await _masterService.publishCatalog(
      _catalog!.copyWith(optionDefinitions: value),
      auditAction: 'Update option definitions in store master',
    );
    notifyListeners();
  }

  Future<void> saveProducts(List<CatalogProduct> value) async {
    _catalog = await _masterService.publishCatalog(
      _catalog!.copyWith(products: value),
      auditAction: 'Update product options in store master',
    );
    notifyListeners();
  }

  Future<void> addAutomaticCharge(CatalogAutomaticCharge charge) async {
    _validateAutomaticCharge(charge);
    await saveCatalogCharges([...automaticCharges, charge]);
  }

  Future<void> updateAutomaticCharge(CatalogAutomaticCharge charge) async {
    _validateAutomaticCharge(charge);
    final next = automaticCharges
        .map((item) => item.chargeId == charge.chargeId ? charge : item)
        .toList(growable: false);
    await saveCatalogCharges(next);
  }

  Future<void> deleteAutomaticCharge(String chargeId) async {
    await saveCatalogCharges(automaticCharges
        .where((item) => item.chargeId != chargeId)
        .toList(growable: false));
  }

  Future<void> saveCatalogCharges(List<CatalogAutomaticCharge> value) async {
    _catalog = await _masterService.publishCatalog(
      _catalog!.copyWith(automaticCharges: value),
      auditAction: 'Update automatic charges in store master',
    );
    notifyListeners();
  }

  void _validateAutomaticCharge(CatalogAutomaticCharge charge) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(charge.chargeId)) {
      throw StateError('Charge ID must use lowercase letters, numbers, and underscores.');
    }
    if (charge.name.trim().isEmpty) throw StateError('Charge name is required.');
    if (charge.amount < 0) throw StateError('Charge amount cannot be negative.');
    if (!{'category', 'product', 'product_type'}.contains(charge.scope)) {
      throw StateError('Invalid charge scope.');
    }
    final hasTarget = switch (charge.scope) {
      'category' => charge.categoryIds.isNotEmpty,
      'product' => charge.productIds.isNotEmpty,
      'product_type' => charge.productTypes.isNotEmpty,
      _ => false,
    };
    if (!hasTarget) throw StateError('Select at least one target for this charge.');
    if (charge.scope == 'category' && charge.categoryIds.any((id) => !categories.any((c) => c.categoryId == id))) {
      throw StateError('Charge references an unknown category.');
    }
    if (charge.scope == 'product' && charge.productIds.any((id) => !products.any((p) => p.productId == id))) {
      throw StateError('Charge references an unknown product.');
    }
    if (automaticCharges.any((item) => item.chargeId == charge.chargeId)) {
      // Allow replacement by the update path; callers handle duplicate IDs there.
    }
  }

  Future<void> addDefinition(CatalogOptionDefinition option) async {
    _validateDefinition(option, definitions);
    await saveDefinitions([...definitions, option]);
  }

  Future<void> updateDefinition(CatalogOptionDefinition option) async {
    _validateDefinition(option, definitions, editingId: option.optionId);
    final next = definitions
        .map((item) => item.optionId == option.optionId ? option : item)
        .toList(growable: false);
    await saveDefinitions(next);
  }

  Future<void> deleteDefinition(String id) async {
    if (products.any((product) =>
        product.options.any((option) => option.optionId == id))) {
      throw StateError(
        'This option is assigned to a product. Remove it from products first.',
      );
    }
    await saveDefinitions(
      definitions.where((item) => item.optionId != id).toList(growable: false),
    );
  }

  Future<void> addProductOption(
    CatalogProduct product,
    ProductOption option,
  ) async {
    _validateProductOption(option, product.options);
    await _replaceProduct(
      product,
      product.copyWith(options: [...product.options, option]),
    );
  }

  Future<void> updateProductOption(
    CatalogProduct product,
    ProductOption option,
  ) async {
    _validateProductOption(option, product.options, editingId: option.optionId);
    final next = product.options
        .map((item) => item.optionId == option.optionId ? option : item)
        .toList(growable: false);
    await _replaceProduct(product, product.copyWith(options: next));
  }

  Future<void> removeProductOption(
    CatalogProduct product,
    String optionId,
  ) async {
    await _replaceProduct(
      product,
      product.copyWith(
        options: product.options
            .where((item) => item.optionId != optionId)
            .toList(growable: false),
      ),
    );
  }

  Future<void> assignDefinition(
    CatalogProduct product,
    CatalogOptionDefinition definition,
  ) async {
    final option = ProductOption(
      optionId: definition.optionId,
      name: definition.name,
      price: definition.price,
      active: definition.active,
      kitchenPrepared: definition.kitchenPrepared,
      autoApply: false,
    );
    if (product.options.any((item) => item.optionId == option.optionId)) {
      return;
    }
    await addProductOption(product, option);
  }

  Future<void> _replaceProduct(
    CatalogProduct oldProduct,
    CatalogProduct nextProduct,
  ) async {
    final next = products
        .map((item) =>
            item.productId == oldProduct.productId ? nextProduct : item)
        .toList(growable: false);
    await saveProducts(next);
  }

  void _validateDefinition(
    CatalogOptionDefinition option,
    List<CatalogOptionDefinition> existing, {
    String? editingId,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(option.optionId)) {
      throw StateError(
        'Option ID must use lowercase letters, numbers, and underscores.',
      );
    }
    if (option.name.trim().isEmpty) {
      throw StateError('Option name is required.');
    }
    if (option.productTypes.isEmpty) {
      throw StateError('Select at least one applicable product type.');
    }
    if (option.price != null && option.price! < 0) {
      throw StateError('Option price cannot be negative.');
    }
    if (existing.any((item) =>
        item.optionId == option.optionId && item.optionId != editingId)) {
      throw StateError('Option ID already exists.');
    }
  }

  void _validateProductOption(
    ProductOption option,
    List<ProductOption> existing, {
    String? editingId,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(option.optionId)) {
      throw StateError(
        'Option ID must use lowercase letters, numbers, and underscores.',
      );
    }
    if (option.name.trim().isEmpty) {
      throw StateError('Option name is required.');
    }
    if (option.price != null && option.price! < 0) {
      throw StateError('Option price cannot be negative.');
    }
    if (existing.any((item) =>
        item.optionId == option.optionId && item.optionId != editingId)) {
      throw StateError('Option is already assigned to this product.');
    }
  }
}

class ProductOptionManagerPage extends StatefulWidget {
  const ProductOptionManagerPage({super.key});

  @override
  State<ProductOptionManagerPage> createState() =>
      _ProductOptionManagerPageState();
}

class _ProductOptionManagerPageState extends State<ProductOptionManagerPage>
    with SingleTickerProviderStateMixin {
  final _controller = ProductOptionManagerController();
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String _search = '';
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (!mounted) return;
    final selectedId = _selectedProductId;
    if (selectedId != null &&
        !_controller.products.any((product) => product.productId == selectedId)) {
      _selectedProductId = null;
    }
    setState(() {});
  }

  CatalogProduct? get _selectedProduct {
    final selectedId = _selectedProductId;
    if (selectedId == null) return null;
    for (final product in _controller.products) {
      if (product.productId == selectedId) return product;
    }
    return null;
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _tabs.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'PRODUCT OPTIONS / ADD-ONS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _controller.loading ? null : _controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'SHARED OPTIONS'),
            Tab(text: 'PRODUCT ASSIGNMENT'),
            Tab(text: 'CHARGES & FEES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_sharedTab(), _assignmentTab(), _chargesTab()],
      ),
    );
  }

  Widget _chargesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(
                '${_controller.automaticCharges.length} charges',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _editAutomaticCharge(null),
                icon: const Icon(Icons.add),
                label: const Text('ADD CHARGE'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _controller.automaticCharges.isEmpty
              ? const Center(child: Text('No automatic charges configured.'))
              : ListView.builder(
                  itemCount: _controller.automaticCharges.length,
                  itemBuilder: (context, index) {
                    final charge = _controller.automaticCharges[index];
                    final targets = switch (charge.scope) {
                      'category' => charge.categoryIds.join(', '),
                      'product' => charge.productIds.join(', '),
                      'product_type' => charge.productTypes.join(', '),
                      _ => '',
                    };
                    return ListTile(
                      title: Text(charge.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${StoreCurrency.format(charge.amount)} • ${charge.scope} • $targets • ${charge.active ? 'Active' : 'Inactive'}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            onPressed: () => _editAutomaticCharge(charge),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () async {
                              final ok = await CatalogChangeGuard.confirm(
                                context,
                                title: 'Delete automatic charge?',
                                message: 'Remove ${charge.name} from the catalog?',
                                destructive: true,
                              );
                              if (!ok) return;
                              try {
                                await _controller.deleteAutomaticCharge(charge.chargeId);
                              } catch (error) {
                                _msg(error);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sharedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(
                '${_controller.definitions.length} options',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _editDefinition(null),
                icon: const Icon(Icons.add),
                label: const Text('ADD OPTION'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _controller.definitions.length,
            itemBuilder: (context, index) {
              final option = _controller.definitions[index];
              return ListTile(
                title: Text(
                  option.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${option.optionId} • ${option.productTypes.join(', ')} • '
                  '${option.price == null ? 'No price' : StoreCurrency.format(option.price!)}',
                ),
                leading: Icon(
                  option.active ? Icons.check_circle : Icons.pause_circle,
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: () => _editDefinition(option),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      onPressed: () async {
                        final ok = await CatalogChangeGuard.confirm(
                          context,
                          title: 'Delete shared option?',
                          message:
                              'Delete ${option.name}? This cannot be undone. '
                              'Options assigned to products must be removed first.',
                          confirmLabel: 'DELETE',
                          destructive: true,
                        );
                        if (!ok) return;
                        try {
                          await _controller.deleteDefinition(option.optionId);
                        } catch (error) {
                          _msg(error);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _assignmentTab() {
    return Row(
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
                    return ListTile(
                      selected: _selectedProductId == product.productId,
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${product.productId}\n${product.options.length} product-specific options',
                      ),
                      isThreeLine: true,
                      onTap: () => setState(() => _selectedProductId = product.productId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedProduct == null
              ? const Center(child: Text('Select a product'))
              : _productDetail(_selectedProduct!),
        ),
      ],
    );
  }

  Widget _productDetail(CatalogProduct product) {
    final assigned = product.options;
    final available = _controller.definitions
        .where((definition) =>
            definition.active &&
            definition.productTypes.contains(product.productType) &&
            !assigned.any((option) => option.optionId == definition.optionId))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          product.name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        Text(product.productId, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'PRODUCT OPTIONS (${assigned.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _editProductOption(product, null),
              icon: const Icon(Icons.add),
              label: const Text('ADD'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...assigned.map(
          (option) => Card(
            child: ListTile(
              title: Text(
                option.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${option.optionId} • '
                '${option.price == null ? 'No price' : StoreCurrency.format(option.price!)} • '
                '${option.kitchenPrepared ? 'Kitchen' : 'Not kitchen'} • '
                '${option.autoApply ? 'Auto apply' : 'Manual'}',
              ),
              leading: Icon(
                option.active ? Icons.check_circle : Icons.pause_circle,
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () => _editProductOption(product, option),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () async {
                      final ok = await CatalogChangeGuard.confirm(
                        context,
                        title: 'Remove product option?',
                        message:
                            'Remove ${option.name} from ${product.name}? '
                            'The shared option definition, if any, will remain unchanged.',
                        confirmLabel: 'REMOVE',
                        destructive: true,
                      );
                      if (!ok) return;
                      try {
                        await _controller.removeProductOption(
                          product,
                          option.optionId,
                        );
                      } catch (error) {
                        _msg(error);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SHARED OPTIONS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...available.map(
          (definition) => Card(
            child: ListTile(
              title: Text(definition.name),
              subtitle: Text(
                '${definition.optionId} • '
                '${definition.price == null ? 'No price' : StoreCurrency.format(definition.price!)}',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  try {
                    await _controller.assignDefinition(product, definition);
                  } catch (error) {
                    _msg(error);
                  }
                },
                child: const Text('ASSIGN'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editAutomaticCharge(CatalogAutomaticCharge? current) async {
    final result = await showDialog<CatalogAutomaticCharge>(
      context: context,
      builder: (_) => _AutomaticChargeDialog(
        value: current,
        categories: _controller.categories,
        products: _controller.products,
      ),
    );
    if (result == null) return;
    try {
      if (current == null) {
        if (_controller.automaticCharges.any((item) => item.chargeId == result.chargeId)) {
          throw StateError('Charge ID already exists.');
        }
        await _controller.addAutomaticCharge(result);
      } else {
        await _controller.updateAutomaticCharge(result);
      }
    } catch (error) {
      _msg(error);
    }
  }

  Future<void> _editDefinition(CatalogOptionDefinition? current) async {
    final result = await showDialog<CatalogOptionDefinition>(
      context: context,
      builder: (_) => _DefinitionDialog(value: current),
    );
    if (result == null) return;
    try {
      if (current == null) {
        await _controller.addDefinition(result);
      } else {
        await _controller.updateDefinition(result);
      }
    } catch (error) {
      _msg(error);
    }
  }

  Future<void> _editProductOption(
    CatalogProduct product,
    ProductOption? current,
  ) async {
    final result = await showDialog<ProductOption>(
      context: context,
      builder: (_) => _ProductOptionDialog(value: current),
    );
    if (result == null) return;
    try {
      if (current == null) {
        await _controller.addProductOption(product, result);
      } else {
        await _controller.updateProductOption(product, result);
      }
    } catch (error) {
      _msg(error);
    }
  }
}

class _DefinitionDialog extends StatefulWidget {
  const _DefinitionDialog({this.value});

  final CatalogOptionDefinition? value;

  @override
  State<_DefinitionDialog> createState() => _DefinitionDialogState();
}

class _DefinitionDialogState extends State<_DefinitionDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _active;
  late bool _kitchenPrepared;
  final Set<String> _types = {'drink', 'food', 'accessory', 'addOn'};
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final value = widget.value;
    _id = TextEditingController(text: value?.optionId ?? '');
    _name = TextEditingController(text: value?.name ?? '');
    _price = TextEditingController(text: value?.price?.toString() ?? '');
    _active = value?.active ?? true;
    _kitchenPrepared = value?.kitchenPrepared ?? false;
    _selected = {...(value?.productTypes ?? const <String>[])};
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.value == null ? 'ADD SHARED OPTION' : 'EDIT SHARED OPTION'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _id,
                readOnly: widget.value != null,
                decoration: const InputDecoration(labelText: 'Option ID'),
              ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (optional)'),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Applicable product types'),
              ),
              Wrap(
                children: _types.map((type) {
                  return FilterChip(
                    label: Text(type),
                    selected: _selected.contains(type),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selected.add(type);
                        } else {
                          _selected.remove(type);
                        }
                      });
                    },
                  );
                }).toList(growable: false),
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                title: const Text('Kitchen prepared'),
                value: _kitchenPrepared,
                onChanged: (value) =>
                    setState(() => _kitchenPrepared = value),
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
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              CatalogOptionDefinition(
                optionId: _id.text.trim(),
                name: _name.text.trim(),
                productTypes: _selected.toList(growable: false),
                price: _price.text.trim().isEmpty
                    ? null
                    : num.tryParse(_price.text.trim()),
                active: _active,
                kitchenPrepared: _kitchenPrepared,
              ),
            );
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _ProductOptionDialog extends StatefulWidget {
  const _ProductOptionDialog({this.value});

  final ProductOption? value;

  @override
  State<_ProductOptionDialog> createState() => _ProductOptionDialogState();
}

class _ProductOptionDialogState extends State<_ProductOptionDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late bool _active;
  late bool _kitchenPrepared;
  late bool _autoApply;

  @override
  void initState() {
    super.initState();
    final value = widget.value;
    _id = TextEditingController(text: value?.optionId ?? '');
    _name = TextEditingController(text: value?.name ?? '');
    _price = TextEditingController(text: value?.price?.toString() ?? '');
    _active = value?.active ?? true;
    _kitchenPrepared = value?.kitchenPrepared ?? false;
    _autoApply = value?.autoApply ?? false;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.value == null ? 'ADD PRODUCT OPTION' : 'EDIT PRODUCT OPTION',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              readOnly: widget.value != null,
              decoration: const InputDecoration(labelText: 'Option ID'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (optional)'),
            ),
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            SwitchListTile(
              title: const Text('Kitchen prepared'),
              value: _kitchenPrepared,
              onChanged: (value) =>
                  setState(() => _kitchenPrepared = value),
            ),
            SwitchListTile(
              title: const Text('Auto apply'),
              subtitle: const Text(
                'Select this add-on automatically when the product is added. The customer can still remove it.',
              ),
              value: _autoApply,
              onChanged: (value) => setState(() => _autoApply = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              ProductOption(
                optionId: _id.text.trim(),
                name: _name.text.trim(),
                price: _price.text.trim().isEmpty
                    ? null
                    : num.tryParse(_price.text.trim()),
                active: _active,
                kitchenPrepared: _kitchenPrepared,
                autoApply: _autoApply,
              ),
            );
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}


class _AutomaticChargeDialog extends StatefulWidget {
  const _AutomaticChargeDialog({this.value, required this.categories, required this.products});
  final CatalogAutomaticCharge? value;
  final List<ProductCategory> categories;
  final List<CatalogProduct> products;
  @override State<_AutomaticChargeDialog> createState() => _AutomaticChargeDialogState();
}

class _AutomaticChargeDialogState extends State<_AutomaticChargeDialog> {
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late bool _active;
  late String _scope;
  late Set<String> _categoryIds;
  late Set<String> _productIds;
  late Set<String> _productTypes;
  static const _types = ['drink', 'food', 'accessory', 'addOn'];

  @override void initState() {
    super.initState();
    final value = widget.value;
    _id = TextEditingController(text: value?.chargeId ?? '');
    _name = TextEditingController(text: value?.name ?? '');
    _amount = TextEditingController(text: value?.amount.toString() ?? '');
    _active = value?.active ?? true;
    _scope = value?.scope ?? 'category';
    _categoryIds = {...(value?.categoryIds ?? const [])};
    _productIds = {...(value?.productIds ?? const [])};
    _productTypes = {...(value?.productTypes ?? const [])};
  }
  @override void dispose() { _id.dispose(); _name.dispose(); _amount.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.value == null ? 'ADD AUTOMATIC CHARGE' : 'EDIT AUTOMATIC CHARGE'),
      content: SizedBox(
        width: 560,
        height: 620,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _id, readOnly: widget.value != null, decoration: const InputDecoration(labelText: 'Charge ID')),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
            SwitchListTile(title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Scope'),
              items: const [
                DropdownMenuItem(value: 'category', child: Text('Category')),
                DropdownMenuItem(value: 'product', child: Text('Product')),
                DropdownMenuItem(value: 'product_type', child: Text('Product Type')),
              ],
              onChanged: (v) => setState(() => _scope = v ?? 'category'),
            ),
            const SizedBox(height: 12),
            Text('Targets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (_scope == 'category') ...widget.categories.map((c) => CheckboxListTile(
              dense: true, title: Text(c.name), value: _categoryIds.contains(c.categoryId),
              onChanged: (v) => setState(() => v == true ? _categoryIds.add(c.categoryId) : _categoryIds.remove(c.categoryId)),
            )),
            if (_scope == 'product') ...widget.products.map((p) {
              String? categoryName;
              for (final category in widget.categories) {
                if (category.categoryId == p.categoryId) {
                  categoryName = category.name;
                  break;
                }
              }
              final categoryLabel = (categoryName == null || categoryName.trim().isEmpty)
                  ? p.categoryId
                  : categoryName;
              final typeLabel = p.productType.trim().isEmpty ? 'Unknown' : p.productType;
              return CheckboxListTile(
                dense: true,
                title: Text(p.name),
                subtitle: Text(
                  'Category: $categoryLabel • Type: $typeLabel • ID: ${p.productId}',
                ),
                value: _productIds.contains(p.productId),
                onChanged: (v) => setState(() => v == true ? _productIds.add(p.productId) : _productIds.remove(p.productId)),
              );
            }),
            if (_scope == 'product_type') ..._types.map((type) => CheckboxListTile(
              dense: true, title: Text(type), value: _productTypes.contains(type),
              onChanged: (v) => setState(() => v == true ? _productTypes.add(type) : _productTypes.remove(type)),
            )),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () {
          final amount = num.tryParse(_amount.text.trim());
          Navigator.pop(context, CatalogAutomaticCharge(
            chargeId: _id.text.trim(), name: _name.text.trim(), amount: amount ?? 0, active: _active, scope: _scope,
            categoryIds: _categoryIds.toList(growable: false), productIds: _productIds.toList(growable: false), productTypes: _productTypes.toList(growable: false),
          ));
        }, child: const Text('SAVE')),
      ],
    );
  }
}
