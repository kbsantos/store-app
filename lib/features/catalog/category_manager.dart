import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import 'product_size_variant_manager.dart';
import 'product_category_assignment.dart';
import 'catalog_manager_dashboard.dart';
import 'package:flutter/material.dart';
import 'product_option_manager.dart';
import 'catalog_change_guard.dart';
import 'product_manager.dart';
import 'store_catalog_master_service.dart';

class CategoryManagerController extends ChangeNotifier {
  CategoryManagerController({
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
  bool get loading => _loading;

  int productCount(String categoryId) =>
      _products.where((product) => product.categoryId == categoryId).length;

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

  Future<void> save(ProductCategory category) async {
    _validateCategory(category, editingId: category.categoryId);
    final index = _categories
        .indexWhere((item) => item.categoryId == category.categoryId);
    if (index < 0) {
      throw StateError('Category not found: ${category.categoryId}');
    }
    final updated = List<ProductCategory>.of(_categories)..[index] = category;
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(categories: updated),
      auditAction: 'Update category in store master',
    );
    _categories = List.of(accepted.categories);
    notifyListeners();
  }

  Future<void> add({
    required String categoryId,
    required String name,
    required String subtitle,
    String? icon,
    bool active = true,
  }) async {
    final category = ProductCategory(
      categoryId: categoryId.trim(),
      name: name.trim(),
      subtitle: subtitle.trim(),
      active: active,
      icon: icon,
    );
    _validateCategory(category);
    if (_categories.any((item) => item.categoryId == category.categoryId)) {
      throw StateError('Category ID already exists.');
    }
    if (_categories.any(
        (item) => item.name.toLowerCase() == category.name.toLowerCase())) {
      throw StateError('Category name already exists.');
    }
    final updated = [..._categories, category];
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(categories: updated),
      auditAction: 'Add category to store master',
    );
    _categories = List.of(accepted.categories);
    notifyListeners();
  }

  Future<void> setActive(ProductCategory category, bool active) async {
    await save(category.copyWith(active: active));
  }

  Future<void> delete(ProductCategory category) async {
    final count = productCount(category.categoryId);
    if (count > 0) {
      throw StateError(
          'Cannot delete a category containing $count product${count == 1 ? '' : 's'}. Disable it instead.');
    }
    final updated = _categories
        .where((item) => item.categoryId != category.categoryId)
        .toList();
    if (updated.length == _categories.length) return;
    final current = await _repository.load();
    final accepted = await _masterService.publishCatalog(
      current.copyWith(categories: updated),
      auditAction: 'Delete category from store master',
    );
    _categories = List.of(accepted.categories);
    notifyListeners();
  }

  void _validateCategory(ProductCategory category, {String? editingId}) {
    if (!RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(category.categoryId)) {
      throw StateError(
          'Category ID must use lowercase letters, numbers, and underscores.');
    }
    if (category.name.trim().isEmpty) {
      throw StateError('Category name is required.');
    }
    if (_categories.any((item) =>
        item.categoryId != editingId &&
        item.name.toLowerCase() == category.name.toLowerCase())) {
      throw StateError('Category name already exists.');
    }
  }
}


String _defaultIconForCategory(String? id) {
  switch (id) {
    case 'milk_tea': return '🧋';
    case 'fruit_tea': return '🍓';
    case 'coffee': return '☕';
    case 'chocolate': return '🍫';
    case 'matcha': return '🍵';
    case 'frappe': return '🥤';
    case 'fruity_soda': return '🫧';
    case 'slushies': return '🧊';
    case 'rice_meals': return '🍚';
    case 'burgers': return '🍔';
    case 'merienda': return '🍟';
    case 'accessories': return '🛍️';
    case 'add_ons': return '➕';
    default: return '📦';
  }
}

class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({super.key});

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<CategoryManagerPage> {
  final CategoryManagerController _controller = CategoryManagerController();

  static const _dark = Color(0xFF171717);
  static const _gold = Color(0xFFC69214);

  @override
  void initState() {
    super.initState();
    _controller.load();
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit(ProductCategory category) async {
    final result = await showDialog<ProductCategory>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (result == null) return;
    try {
      await _controller.save(result);
      if (mounted) _message('Category updated.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  Future<void> _add() async {
    final result = await showDialog<_NewCategory>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (result == null) return;
    try {
      await _controller.add(
        categoryId: result.categoryId,
        name: result.name,
        subtitle: result.subtitle,
        icon: result.icon,
        active: result.active,
      );
      if (mounted) _message('Category added.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  Future<void> _delete(ProductCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete “${category.name}”? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.delete(category);
      if (mounted) _message('Category deleted.');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: const Text('CATEGORY MANAGER',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CatalogManagerDashboardPage())),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('CATALOG HUB'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductOptionManagerPage())),
              icon: const Icon(Icons.extension_outlined),
              label: const Text('OPTIONS'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductSizeVariantManagerPage())),
              icon: const Icon(Icons.straighten),
              label: const Text('SIZES & VARIANTS'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductManagerPage())),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('PRODUCTS'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProductCategoryAssignmentPage())),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('ASSIGN PRODUCTS'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
            ),
          ),
          IconButton(
              onPressed: _controller.load, icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('ADD CATEGORY'),
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _controller.categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final category = _controller.categories[index];
              final count = _controller.productCount(category.categoryId);
              return Card(
                elevation: 2,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: category.active ? _gold : Colors.grey,
                    child: Text(
                      category.icon ?? _defaultIconForCategory(category.categoryId),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  title: Text(category.name,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${category.categoryId}  •  ${category.subtitle.isEmpty ? 'No subtitle' : category.subtitle}  •  $count product${count == 1 ? '' : 's'}'),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(
                          value: category.active,
                          onChanged: (value) async {
                            if (!value &&
                                _controller.productCount(category.categoryId) >
                                    0) {
                              final count =
                                  _controller.productCount(category.categoryId);
                              final ok = await CatalogChangeGuard.confirm(
                                context,
                                title: 'Disable category?',
                                message:
                                    '${category.name} has $count product${count == 1 ? '' : 's'}. Disabling it will hide those products from the customer kiosk.',
                                confirmLabel: 'DISABLE',
                              );
                              if (!ok) return;
                            }
                            await _controller.setActive(category, value);
                          }),
                      IconButton(
                          onPressed: () => _edit(category),
                          icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                          onPressed: () => _delete(category),
                          icon: const Icon(Icons.delete_outline)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NewCategory {
  const _NewCategory(
      {required this.categoryId,
      required this.name,
      required this.subtitle,
      required this.icon,
      required this.active});
  final String categoryId;
  final String name;
  final String subtitle;
  final String icon;
  final bool active;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});
  final ProductCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  static const _categoryIcons = <String>[
    '🧋', '🍓', '☕', '🍫', '🍵', '🥤', '🫧', '🧊',
    '🍚', '🍔', '🍟', '🛍️', '➕', '🍰', '🍕', '🍦',
    '🥐', '⭐', '🎁', '📦',
  ];

  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _subtitle;
  late bool _active;
  late String _icon;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _id = TextEditingController(text: category?.categoryId ?? '');
    _name = TextEditingController(text: category?.name ?? '');
    _subtitle = TextEditingController(text: category?.subtitle ?? '');
    _active = category?.active ?? true;
    _icon = category?.icon ?? _defaultIconForCategory(category?.categoryId);
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Category' : 'Add Category'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _id,
              enabled: !editing,
              decoration: const InputDecoration(
                  labelText: 'Category ID', hintText: 'coffee')),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Category Name')),
          const SizedBox(height: 12),
          TextField(
              controller: _subtitle,
              decoration: const InputDecoration(labelText: 'Subtitle')),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CATEGORY ICON',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.all(Radius.circular(12)),
              border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryIcons.map((icon) {
                final selected = _icon == icon;
                return InkWell(
                  onTap: () => setState(() => _icon = icon),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFC69214).withValues(alpha: 0.18)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFC69214)
                            : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 25)),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Selected: $_icon',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(
            onPressed: () {
              if (_id.text.trim().isEmpty || _name.text.trim().isEmpty) return;
              if (editing) {
                Navigator.pop(
                    context,
                    widget.category!.copyWith(
                        name: _name.text.trim(),
                        subtitle: _subtitle.text.trim(),
                        active: _active,
                        icon: _icon));
              } else {
                Navigator.pop(
                    context,
                    _NewCategory(
                        categoryId: _id.text.trim(),
                        name: _name.text.trim(),
                        subtitle: _subtitle.text.trim(),
                        active: _active,
                        icon: _icon));
              }
            },
            child: const Text('SAVE')),
      ],
    );
  }
}
