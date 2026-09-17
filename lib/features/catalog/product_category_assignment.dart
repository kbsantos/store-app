import 'package:flutter/material.dart';

import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import 'store_catalog_master_service.dart';

class ProductCategoryAssignmentController extends ChangeNotifier {
  ProductCategoryAssignmentController({
    ProductCatalogRepository? repository,
    StoreCatalogMasterService? masterService,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _masterService = masterService ??
            StoreCatalogMasterService(
              repository: repository ?? const ProductCatalogRepository(),
            );

  final ProductCatalogRepository _repository;
  final StoreCatalogMasterService _masterService;
  List<ProductCategory> _categories = const [];
  List<CatalogProduct> _products = const [];
  bool _loading = false;

  List<ProductCategory> get categories => List.unmodifiable(_categories);
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
      _categories = List.of(catalog.categories);
      _products = List.of(catalog.products);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> assignProduct(CatalogProduct product, String categoryId) async {
    if (!_categories.any((category) => category.categoryId == categoryId)) {
      throw StateError('Category not found: $categoryId');
    }
    final index = _products.indexWhere((item) => item.productId == product.productId);
    if (index < 0) throw StateError('Product not found: ${product.productId}');
    final updated = List<CatalogProduct>.of(_products)
      ..[index] = product.copyWith(categoryId: categoryId);
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(products: updated),
      auditAction: 'Assign product category in store master',
    );
    _products = List.of(accepted.products);
    notifyListeners();
  }

  List<CatalogProduct> productsForCategory(String categoryId) =>
      _products.where((product) => product.categoryId == categoryId).toList(growable: false);
}

class ProductCategoryAssignmentPage extends StatefulWidget {
  const ProductCategoryAssignmentPage({super.key});

  @override
  State<ProductCategoryAssignmentPage> createState() => _ProductCategoryAssignmentPageState();
}

class _ProductCategoryAssignmentPageState extends State<ProductCategoryAssignmentPage> {
  final _controller = ProductCategoryAssignmentController();
  String _search = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _controller.load();
  }

  void _changed() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  List<CatalogProduct> get _filtered {
    final q = _search.trim().toLowerCase();
    return _controller.products.where((product) {
      final matchesSearch = q.isEmpty || product.name.toLowerCase().contains(q) || product.productId.toLowerCase().contains(q);
      final matchesCategory = _categoryFilter == null || product.categoryId == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList(growable: false);
  }

  Future<void> _assign(CatalogProduct product) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Assign ${product.name}'),
        children: [
          for (final category in _controller.categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, category.categoryId),
              child: Row(children: [
                Expanded(child: Text(category.name)),
                if (category.categoryId == product.categoryId) const Icon(Icons.check),
              ]),
            ),
        ],
      ),
    );
    if (selected == null || selected == product.categoryId) return;
    try {
      await _controller.assignProduct(product, selected);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product category updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _categoryName(String id) {
    for (final category in _controller.categories) {
      if (category.categoryId == id) return category.name;
    }
    return 'Unassigned';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PRODUCT CATEGORY ASSIGNMENT'),
        actions: [IconButton(onPressed: _controller.load, icon: const Icon(Icons.refresh))],
      ),
      body: _controller.loading && _controller.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search product'),
                    onChanged: (value) => setState(() => _search = value),
                  )),
                  const SizedBox(width: 12),
                  SizedBox(width: 220, child: DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                      ..._controller.categories.map((c) => DropdownMenuItem<String?>(value: c.categoryId, child: Text(c.name)))],
                    onChanged: (value) => setState(() => _categoryFilter = value),
                  )),
                ]),
              ),
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final product = _filtered[index];
                  return ListTile(
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${product.productId}  •  ${_categoryName(product.categoryId)}'),
                    trailing: FilledButton.icon(onPressed: () => _assign(product), icon: const Icon(Icons.swap_horiz), label: const Text('ASSIGN')),
                  );
                },
              )),
            ]),
    );
  }
}
