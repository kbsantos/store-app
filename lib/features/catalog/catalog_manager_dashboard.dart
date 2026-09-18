import 'package:flutter/material.dart';

import '../../product_catalog/catalog_validator.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../core/auth/store_management_auth.dart';
import 'category_manager.dart';
import 'product_manager.dart';
import 'product_size_variant_manager.dart';
import 'product_option_manager.dart';
import 'product_category_assignment.dart';
import 'catalog_validation_manager.dart';
import 'store_catalog_master_service.dart';

class CatalogManagerDashboardPage extends StatefulWidget {
  const CatalogManagerDashboardPage({super.key});

  @override
  State<CatalogManagerDashboardPage> createState() =>
      _CatalogManagerDashboardPageState();
}

class _CatalogManagerDashboardPageState
    extends State<CatalogManagerDashboardPage> {
  final _masterService = StoreCatalogMasterService();
  ProductCatalog? _catalog;
  CatalogValidationReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _masterService.loadMasterCatalog();
      await _masterService.cacheMasterCatalog(
        catalog,
        auditAction: 'Refresh catalog from store master',
      );
      final report = CatalogValidator().validate(catalog);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  void _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = const StoreManagementAuth();
    final canEdit = auth.canManageCatalog;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'PRODUCT CATALOG',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _header(),
            const SizedBox(height: 18),
            if (!canEdit)
              _infoCard(
                'READ-ONLY ACCESS',
                'Your account can view the store catalog but does not have manager access to change it.',
              ),
            if (_error != null) _errorCard(_error!),
            const SizedBox(height: 18),
            _sectionTitle('CATALOG MANAGEMENT'),
            const SizedBox(height: 10),
            _grid([
              _tile(
                Icons.category_outlined,
                'Categories',
                'Manage customer-facing categories',
                '${_catalog?.categories.length ?? 0}',
                () => _open(const CategoryManagerPage()),
                enabled: canEdit,
              ),
              _tile(
                Icons.inventory_2_outlined,
                'Products',
                'Manage products and availability',
                '${_catalog?.products.length ?? 0}',
                () => _open(const ProductManagerPage()),
                enabled: canEdit,
              ),
              _tile(
                Icons.straighten,
                'Sizes & Variants',
                'Manage product sizes and variants',
                _sizeVariantSummary(),
                () => _open(const ProductSizeVariantManagerPage()),
                enabled: canEdit,
              ),
              _tile(
                Icons.extension_outlined,
                'Options / Add-ons',
                'Manage shared and product options',
                _optionSummary(),
                () => _open(const ProductOptionManagerPage()),
                enabled: canEdit,
              ),
              _tile(
                Icons.swap_horiz,
                'Category Assignment',
                'Assign products to categories',
                'MANAGE',
                () => _open(const ProductCategoryAssignmentPage()),
                enabled: canEdit,
              ),
              _tile(
                Icons.health_and_safety_outlined,
                'Catalog Health',
                'Validate catalog integrity',
                _report == null
                    ? 'CHECK'
                    : '${_report!.errors} errors • ${_report!.warnings} warnings',
                () => _open(const CatalogValidationPage()),
                enabled: true,
              ),
            ]),
            const SizedBox(height: 24),
            _sectionTitle('QUICK STATUS'),
            const SizedBox(height: 10),
            _statusCard(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loading ? 'Loading the store master catalog...' : 'Supabase is the master catalog. This application writes the master first; the kiosk receives the published catalog through synchronization.',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF171717),
            foregroundColor: Colors.white,
            child: Icon(Icons.inventory_2_outlined, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MyCoffeeShop',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Store Master Catalog',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  _catalog == null
                      ? 'Catalog unavailable'
                      : 'Master version ${_catalog!.catalogVersion}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          if (_report != null) _badge(_report!.errors == 0),
        ],
      ),
    ),
  );

  Widget _badge(bool healthy) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: healthy ? Colors.green : Colors.red),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(healthy ? Icons.verified : Icons.error_outline, size: 19),
        const SizedBox(width: 7),
        Text(
          healthy ? 'READY' : 'ACTION REQUIRED',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.1,
    ),
  );

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 700
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((w) => SizedBox(width: width, child: w))
            .toList(),
      );
    },
  );

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    String value,
    VoidCallback onTap, {
    required bool enabled,
  }) => Card(
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: enabled
                  ? const Color(0xFF171717)
                  : Colors.black26,
              foregroundColor: Colors.white,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 7),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  Widget _statusCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _stat('Products', '${_catalog?.products.length ?? 0}'),
          _stat(
            'Active products',
            '${_catalog?.products.where((p) => p.active).length ?? 0}',
          ),
          _stat('Categories', '${_catalog?.categories.length ?? 0}'),
          _stat(
            'Active categories',
            '${_catalog?.categories.where((c) => c.active).length ?? 0}',
          ),
          _stat('Errors', '${_report?.errors ?? 0}'),
          _stat('Warnings', '${_report?.warnings ?? 0}'),
        ],
      ),
    ),
  );
  Widget _stat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(label),
      ],
    ),
  );
  Widget _infoCard(String title, String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
  Widget _errorCard(String message) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SelectableText(message),
    ),
  );

  String _sizeVariantSummary() {
    if (_catalog == null) return 'CHECK';
    final sizes = _catalog!.products.fold<int>(0, (n, p) => n + p.sizes.length);
    final variants = _catalog!.products.fold<int>(
      0,
      (n, p) => n + p.variants.length,
    );
    return '$sizes sizes • $variants variants';
  }

  String _optionSummary() {
    if (_catalog == null) return 'CHECK';
    final assigned = _catalog!.products.fold<int>(
      0,
      (n, p) => n + p.options.length,
    );
    return '${_catalog!.optionDefinitions.length} shared • $assigned assigned';
  }
}
