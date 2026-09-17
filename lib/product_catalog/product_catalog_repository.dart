import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'product_catalog_models.dart';
import 'catalog_schema_guard.dart';

class ProductCatalogRepository {
  static const String assetPath = 'assets/catalog/product_catalog.v4.commercial.json';
  static const String _categoriesOverrideKey = 'bigger_brew_catalog_categories_v1';
  static const String _productsOverrideKey = 'bigger_brew_catalog_products_v1';
  static const String _optionDefinitionsOverrideKey = 'bigger_brew_catalog_option_definitions_v1';
  static const String _auditKey = 'bigger_brew_catalog_audit_v1';
  static const int _maxAuditEntries = 100;

  const ProductCatalogRepository();

  Future<ProductCatalog> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = CatalogSchemaGuard.decodeAndValidate(json, source: 'bundled catalog');

    final prefs = await SharedPreferences.getInstance();
    final categoryOverride = prefs.getString(_categoriesOverrideKey);
    final productOverride = prefs.getString(_productsOverrideKey);
    final optionOverride = prefs.getString(_optionDefinitionsOverrideKey);
    var result = catalog;

    if (categoryOverride != null && categoryOverride.isNotEmpty) {
      try {
        final decoded = jsonDecode(categoryOverride) as List<dynamic>;
        final categories = decoded.map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        result = result.copyWith(categories: categories);
      } catch (_) {}
    }

    if (optionOverride != null && optionOverride.isNotEmpty) {
      try {
        final decoded = jsonDecode(optionOverride) as List<dynamic>;
        final definitions = decoded.map((e) => CatalogOptionDefinition.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        result = result.copyWith(optionDefinitions: definitions);
      } catch (_) {}
    }

    if (productOverride != null && productOverride.isNotEmpty) {
      try {
        final decoded = jsonDecode(productOverride) as List<dynamic>;
        final products = decoded.map((e) => CatalogProduct.fromJson(Map<String, dynamic>.from(e as Map))).toList(growable: false);
        result = result.copyWith(products: products);
      } catch (_) {}
    }

    return result;
  }


  Future<void> save(ProductCatalog catalog) => saveCatalog(catalog, auditAction: 'Save catalog');

  Future<void> backup() async {
    await saveBackup(await load());
  }

  Future<ProductCatalog> restoreBackup() async {
    final backup = await loadBackup();
    if (backup == null) throw StateError('No catalog backup is available.');
    await saveCatalog(backup, auditAction: 'Restore catalog backup');
    return backup;
  }

  Future<ProductCatalog> resetToBundledCatalog() async {
    await clearAllOverrides();
    return load();
  }

  static void validate(ProductCatalog catalog) {
    if (catalog.catalogVersion.trim().isEmpty) throw const FormatException('Catalog version is required.');
    final categoryIds = <String>{};
    for (final c in catalog.categories) {
      if (c.categoryId.trim().isEmpty || !categoryIds.add(c.categoryId)) throw FormatException('Invalid or duplicate category ID: ${c.categoryId}');
    }
    final optionIds = <String>{};
    for (final o in catalog.optionDefinitions) {
      if (o.optionId.trim().isEmpty || !optionIds.add(o.optionId)) throw FormatException('Invalid or duplicate option ID: ${o.optionId}');
      if (o.price != null && o.price! < 0) throw FormatException('Option ${o.optionId} has a negative price.');
    }
    final productIds = <String>{};
    for (final p in catalog.products) {
      if (p.productId.trim().isEmpty || !productIds.add(p.productId)) throw FormatException('Invalid or duplicate product ID: ${p.productId}');
      if (p.name.trim().isEmpty) throw FormatException('Product ${p.productId} must have a name.');
      if (!categoryIds.contains(p.categoryId)) throw FormatException('Product ${p.productId} references unknown category ${p.categoryId}.');
      if (p.price != null && p.price! < 0) throw FormatException('Product ${p.productId} has a negative price.');
      final sizeIds = <String>{};
      for (final x in p.sizes) { if (x.sizeId.trim().isEmpty || !sizeIds.add(x.sizeId)) throw FormatException('Invalid or duplicate size ID: ${x.sizeId}'); if (x.price != null && x.price! < 0) throw FormatException('Product ${p.productId} size ${x.sizeId} has a negative price.'); }
      final variantIds = <String>{};
      for (final x in p.variants) { if (x.variantId.trim().isEmpty || !variantIds.add(x.variantId)) throw FormatException('Invalid or duplicate variant ID: ${x.variantId}'); if (x.price != null && x.price! < 0) throw FormatException('Product ${p.productId} variant ${x.variantId} has a negative price.'); }
      final optionIdsForProduct = <String>{};
      for (final x in p.options) { if (x.optionId.trim().isEmpty || !optionIdsForProduct.add(x.optionId)) throw FormatException('Invalid or duplicate product option ID: ${x.optionId}'); if (!optionIds.contains(x.optionId)) throw FormatException('Product ${p.productId} references unknown option ${x.optionId}.'); if (x.price != null && x.price! < 0) throw FormatException('Product ${p.productId} option ${x.optionId} has a negative price.'); }
    }
  }

  Future<void> saveCategories(List<ProductCategory> categories) async {
    final before = await load();
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(categories.map((category) => category.toJson()).toList());
    await prefs.setString(_categoriesOverrideKey, payload);
    await _appendAudit(
      action: _describeListChange(before.categories.map((e) => e.categoryId).toList(), categories.map((e) => e.categoryId).toList(), 'category'),
      entityType: 'category',
      entityId: _firstChangedId(before.categories.map((e) => e.categoryId).toList(), categories.map((e) => e.categoryId).toList()),
      beforeSummary: 'categories=${before.categories.length}',
      afterSummary: 'categories=${categories.length}',
    );
  }

  Future<void> saveProducts(List<CatalogProduct> products) async {
    final before = await load();
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(products.map((product) => product.toJson()).toList());
    await prefs.setString(_productsOverrideKey, payload);
    await _appendAudit(
      action: _describeListChange(before.products.map((e) => e.productId).toList(), products.map((e) => e.productId).toList(), 'product'),
      entityType: 'product',
      entityId: _firstChangedId(before.products.map((e) => e.productId).toList(), products.map((e) => e.productId).toList()),
      beforeSummary: 'products=${before.products.length}',
      afterSummary: 'products=${products.length}',
    );
  }

  Future<void> saveCatalog(ProductCatalog catalog, {String auditAction = 'Restore catalog snapshot'}) async {
    CatalogSchemaGuard.ensureSupported(catalog.schemaVersion, source: 'catalog');
    final before = await load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesOverrideKey, jsonEncode(catalog.categories.map((e) => e.toJson()).toList()));
    await prefs.setString(_productsOverrideKey, jsonEncode(catalog.products.map((e) => e.toJson()).toList()));
    await prefs.setString(_optionDefinitionsOverrideKey, jsonEncode(catalog.optionDefinitions.map((e) => e.toJson()).toList()));
    await _appendAudit(
      action: auditAction,
      entityType: 'catalog',
      entityId: catalog.catalogVersion,
      beforeSummary: 'categories=${before.categories.length}, products=${before.products.length}, options=${before.optionDefinitions.length}',
      afterSummary: 'categories=${catalog.categories.length}, products=${catalog.products.length}, options=${catalog.optionDefinitions.length}',
    );
  }

  Future<void> clearAllOverrides() async {
    final before = await load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_categoriesOverrideKey);
    await prefs.remove(_productsOverrideKey);
    await prefs.remove(_optionDefinitionsOverrideKey);
    await _appendAudit(
      action: 'Reset to bundled catalog',
      entityType: 'catalog',
      entityId: before.catalogVersion,
      beforeSummary: 'categories=${before.categories.length}, products=${before.products.length}, options=${before.optionDefinitions.length}',
      afterSummary: 'local overrides cleared',
    );
  }

  Future<void> saveBackup(ProductCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bigger_brew_catalog_backup_v1', jsonEncode(catalog.toJson()));
    await prefs.setString('bigger_brew_catalog_backup_time_v1', DateTime.now().toIso8601String());
  }

  Future<ProductCatalog?> loadBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bigger_brew_catalog_backup_v1');
    if (raw == null || raw.isEmpty) return null;
    try {
      return CatalogSchemaGuard.decodeAndValidate(jsonDecode(raw) as Map<String, dynamic>, source: 'backup');
    } catch (_) {
      return null;
    }
  }

  Future<String?> backupTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bigger_brew_catalog_backup_time_v1');
  }

  /// Stores the exact pre-import state for the most recently accepted catalog merge.
  /// This is separate from the manual/general backup so a later manual backup
  /// cannot accidentally destroy the rollback point for the last import.
  Future<void> saveImportRecoveryBackup(ProductCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bigger_brew_catalog_import_recovery_v1', jsonEncode(catalog.toJson()));
    await prefs.setString('bigger_brew_catalog_import_recovery_time_v1', DateTime.now().toIso8601String());
  }

  Future<ProductCatalog?> loadImportRecoveryBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bigger_brew_catalog_import_recovery_v1');
    if (raw == null || raw.isEmpty) return null;
    try {
      return CatalogSchemaGuard.decodeAndValidate(jsonDecode(raw) as Map<String, dynamic>, source: 'import recovery backup');
    } catch (_) {
      return null;
    }
  }

  Future<String?> importRecoveryTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bigger_brew_catalog_import_recovery_time_v1');
  }

  Future<void> clearImportRecoveryBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bigger_brew_catalog_import_recovery_v1');
    await prefs.remove('bigger_brew_catalog_import_recovery_time_v1');
  }

  Future<bool> hasImportRecoveryBackup() async => await loadImportRecoveryBackup() != null;

  Future<void> clearCategoryOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_categoriesOverrideKey);
  }

  Future<void> saveOptionDefinitions(List<CatalogOptionDefinition> definitions) async {
    final before = await load();
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(definitions.map((option) => option.toJson()).toList());
    await prefs.setString(_optionDefinitionsOverrideKey, payload);
    await _appendAudit(
      action: _describeListChange(before.optionDefinitions.map((e) => e.optionId).toList(), definitions.map((e) => e.optionId).toList(), 'option'),
      entityType: 'option',
      entityId: _firstChangedId(before.optionDefinitions.map((e) => e.optionId).toList(), definitions.map((e) => e.optionId).toList()),
      beforeSummary: 'options=${before.optionDefinitions.length}',
      afterSummary: 'options=${definitions.length}',
    );
  }

  Future<void> clearOptionDefinitionOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_optionDefinitionsOverrideKey);
  }

  Future<void> clearProductOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_productsOverrideKey);
  }
  Future<List<Map<String, dynamic>>> loadAudit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_auditKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearAudit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_auditKey);
  }

  Future<void> _appendAudit({required String action, required String entityType, String? entityId, required String beforeSummary, required String afterSummary}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAudit();
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'before': beforeSummary,
      'after': afterSummary,
    };
    final next = <Map<String, dynamic>>[entry, ...existing].take(_maxAuditEntries).toList(growable: false);
    await prefs.setString(_auditKey, jsonEncode(next));
  }

  String _describeListChange(List<String> before, List<String> after, String entity) {
    final added = after.where((id) => !before.contains(id)).toList();
    final removed = before.where((id) => !after.contains(id)).toList();
    if (added.length == 1) return 'Add $entity';
    if (removed.length == 1) return 'Delete $entity';
    return 'Update $entity';
  }

  String? _firstChangedId(List<String> before, List<String> after) {
    for (final id in after) { if (!before.contains(id)) return id; }
    for (final id in before) { if (!after.contains(id)) return id; }
    for (final id in after) { if (before.contains(id)) return id; }
    return null;
  }

}
