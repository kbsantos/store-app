import 'product_catalog_models.dart';

class CatalogValidationIssue {
  final String code;
  final String severity;
  final String message;
  final String? entityId;
  const CatalogValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.entityId,
  });
}

class CatalogValidationReport {
  final List<CatalogValidationIssue> issues;
  final DateTime checkedAt;
  const CatalogValidationReport(this.issues, this.checkedAt);
  bool get isValid => !issues.any((i) => i.severity == 'error');
  int get errors => issues.where((i) => i.severity == 'error').length;
  int get warnings => issues.where((i) => i.severity == 'warning').length;
}

class CatalogValidator {
  static final _id = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');
  static const _types = {'drink', 'food', 'accessory', 'addOn'};
  static const _temperatures = {'hot', 'iced'};

  CatalogValidationReport validate(ProductCatalog catalog) {
    final issues = <CatalogValidationIssue>[];
    void error(String code, String message, [String? id]) => issues.add(
          CatalogValidationIssue(
            code: code,
            severity: 'error',
            message: message,
            entityId: id,
          ),
        );
    void warn(String code, String message, [String? id]) => issues.add(
          CatalogValidationIssue(
            code: code,
            severity: 'warning',
            message: message,
            entityId: id,
          ),
        );

    if (catalog.schemaVersion <= 0) {
      error(
        'invalid_catalog_schema_version',
        'Catalog schema version must be greater than zero.',
      );
    } else if (catalog.schemaVersion > ProductCatalog.currentSchemaVersion) {
      error(
        'unsupported_catalog_schema_version',
        'Catalog schema version ${catalog.schemaVersion} is newer than the supported version ${ProductCatalog.currentSchemaVersion}.',
      );
    }
    if (catalog.catalogVersion.trim().isEmpty) {
      error('missing_catalog_version', 'Catalog version is required.');
    }
    if (catalog.categories.isEmpty) {
      warn('no_categories', 'Catalog contains no categories.');
    }
    if (catalog.products.isEmpty) {
      warn('no_products', 'Catalog contains no products.');
    }

    final categoryIds = <String>{};
    final categoryNames = <String, String>{};
    for (final c in catalog.categories) {
      if (c.categoryId.isEmpty || !_id.hasMatch(c.categoryId)) {
        error('invalid_category_id', 'Invalid category ID: ${c.categoryId}', c.categoryId);
      }
      if (!categoryIds.add(c.categoryId)) {
        error('duplicate_category_id', 'Duplicate category ID: ${c.categoryId}', c.categoryId);
      }
      if (c.name.trim().isEmpty) {
        error('missing_category_name', 'Category name is required.', c.categoryId);
      } else {
        final nameKey = c.name.trim().toLowerCase();
        final previous = categoryNames[nameKey];
        if (previous != null && previous != c.categoryId) {
          warn('duplicate_category_name', 'Category name is duplicated: ${c.name}', c.categoryId);
        } else {
          categoryNames[nameKey] = c.categoryId;
        }
      }
    }

    final optionDefinitionsById = <String, CatalogOptionDefinition>{};
    final optionIds = <String>{};
    for (final o in catalog.optionDefinitions) {
      if (o.optionId.isEmpty || !_id.hasMatch(o.optionId)) {
        error('invalid_option_id', 'Invalid option ID: ${o.optionId}', o.optionId);
      }
      if (!optionIds.add(o.optionId)) {
        error('duplicate_option_id', 'Duplicate shared option ID: ${o.optionId}', o.optionId);
      }
      optionDefinitionsById[o.optionId] = o;
      if (o.name.trim().isEmpty) {
        error('missing_option_name', 'Option name is required.', o.optionId);
      }
      if (o.price != null && o.price! < 0) {
        error('negative_option_price', 'Option price cannot be negative.', o.optionId);
      }
      if (o.productTypes.isEmpty) {
        warn('option_missing_product_types', 'Shared option has no product type restrictions configured.', o.optionId);
      }
      final seenTypes = <String>{};
      for (final type in o.productTypes) {
        if (!_types.contains(type)) {
          error('invalid_option_product_type', 'Option uses invalid product type: $type', o.optionId);
        }
        if (!seenTypes.add(type)) {
          warn('duplicate_option_product_type', 'Option repeats product type: $type', o.optionId);
        }
      }
    }

    final productIds = <String>{};
    final skuOwners = <String, String>{};
    final productNamesByCategory = <String, Map<String, String>>{};
    for (final p in catalog.products) {
      if (p.productId.isEmpty || !_id.hasMatch(p.productId)) {
        error('invalid_product_id', 'Invalid product ID: ${p.productId}', p.productId);
      }
      if (!productIds.add(p.productId)) {
        error('duplicate_product_id', 'Duplicate product ID: ${p.productId}', p.productId);
      }
      if (p.name.trim().isEmpty) {
        error('missing_product_name', 'Product name is required.', p.productId);
      } else {
        final categoryProducts = productNamesByCategory.putIfAbsent(p.categoryId, () => {});
        final nameKey = p.name.trim().toLowerCase();
        final previous = categoryProducts[nameKey];
        if (previous != null && previous != p.productId) {
          warn('duplicate_product_name', 'Product name is duplicated within its category: ${p.name}', p.productId);
        } else {
          categoryProducts[nameKey] = p.productId;
        }
      }
      if (!_types.contains(p.productType)) {
        error('invalid_product_type', 'Invalid product type: ${p.productType}', p.productId);
      }
      final category = catalog.categories.where((c) => c.categoryId == p.categoryId).toList();
      if (category.isEmpty) {
        error('missing_category_reference', 'Product references missing category: ${p.categoryId}', p.productId);
      } else if (!category.single.active) {
        warn('inactive_category_product', 'Product is assigned to inactive category: ${category.single.name}', p.productId);
      }
      if (p.productType == 'drink') {
        if (p.drinkTemperature == null || p.drinkTemperature!.trim().isEmpty) {
          error('missing_drink_temperature', 'Drink must have a Hot or Iced temperature.', p.productId);
        } else if (!_temperatures.contains(p.drinkTemperature!.trim().toLowerCase())) {
          error('invalid_drink_temperature', 'Invalid drink temperature: ${p.drinkTemperature}', p.productId);
        }
        if (p.recipeRef == null || p.recipeRef!.trim().isEmpty) {
          warn('drink_missing_recipe_ref', 'Drink has no recipe reference.', p.productId);
        }
      } else if (p.drinkTemperature != null && p.drinkTemperature!.trim().isNotEmpty) {
        warn('non_drink_temperature', 'Non-drink product contains a drink temperature value.', p.productId);
      }

      if (p.sku != null && p.sku!.trim().isNotEmpty) {
        final skuKey = p.sku!.trim().toLowerCase();
        final previous = skuOwners[skuKey];
        if (previous != null && previous != p.productId) {
          error('duplicate_sku', 'SKU is shared by multiple products: ${p.sku}', p.productId);
        } else {
          skuOwners[skuKey] = p.productId;
        }
      }

      if (p.price != null && p.price! < 0) {
        error('negative_product_price', 'Product base price cannot be negative.', p.productId);
      }
      final hasSizes = p.sizes.isNotEmpty;
      final hasVariants = p.variants.isNotEmpty;
      if (!hasSizes && !hasVariants && p.price == null) {
        error('missing_product_price', 'Product has no base price, size price, or variant price.', p.productId);
      }
      if (hasSizes && p.price != null) {
        warn('mixed_base_and_size_pricing', 'Product has both a base price and configured sizes; confirm the intended pricing model.', p.productId);
      }

      final sizeIds = <String>{};
      for (final s in p.sizes) {
        if (s.sizeId.isEmpty || !_id.hasMatch(s.sizeId)) {
          error('invalid_size_id', 'Invalid size ID: ${s.sizeId}', p.productId);
        }
        if (!sizeIds.add(s.sizeId)) {
          error('duplicate_size_id', 'Duplicate size ID ${s.sizeId} on product.', p.productId);
        }
        if (s.name.trim().isEmpty) {
          error('missing_size_name', 'Size name is required.', p.productId);
        }
        if (s.price != null && s.price! < 0) {
          error('negative_size_price', 'Size ${s.sizeId} has negative price.', p.productId);
        }
        if (s.volumeMl != null && s.volumeMl! <= 0) {
          error('invalid_size_volume', 'Size ${s.sizeId} must have a positive volume in ml.', p.productId);
        }
        if (s.volumeMl == null && (s.displayVolume == null || s.displayVolume!.trim().isEmpty) && p.productType == 'drink') {
          warn('size_missing_volume', 'Drink size has no volume/display volume.', p.productId);
        }
      }
      if (p.sizes.length > 1) {
        final unpriced = p.sizes.where((s) => s.price == null).toList();
        if (unpriced.isNotEmpty) {
          warn('incomplete_size_pricing', 'Product has ${unpriced.length} unpriced configured size(s).', p.productId);
        }
      }

      final variantIds = <String>{};
      for (final v in p.variants) {
        if (v.variantId.isEmpty || !_id.hasMatch(v.variantId)) {
          error('invalid_variant_id', 'Invalid variant ID: ${v.variantId}', p.productId);
        }
        if (!variantIds.add(v.variantId)) {
          error('duplicate_variant_id', 'Duplicate variant ID ${v.variantId} on product.', p.productId);
        }
        if (v.name.trim().isEmpty) {
          error('missing_variant_name', 'Variant name is required.', p.productId);
        }
        if (v.price != null && v.price! < 0) {
          error('negative_variant_price', 'Variant ${v.variantId} has negative price.', p.productId);
        }
      }
      if (p.variants.isNotEmpty && p.price == null) {
        final unpricedVariants = p.variants.where((v) => v.price == null).length;
        if (unpricedVariants > 0) {
          warn('incomplete_variant_pricing', 'Product has $unpricedVariants unpriced variant(s) and no base price.', p.productId);
        }
      }

      final productOptionIds = <String>{};
      for (final o in p.options) {
        if (!productOptionIds.add(o.optionId)) {
          error('duplicate_product_option', 'Duplicate option ${o.optionId} on product.', p.productId);
        }
        if (o.name.trim().isEmpty) {
          error('missing_product_option_name', 'Product option name is required.', p.productId);
        }
        if (o.price != null && o.price! < 0) {
          error('negative_product_option_price', 'Product option ${o.optionId} has negative price.', p.productId);
        }
        if (o.optionId.trim().isEmpty || !_id.hasMatch(o.optionId)) {
          error('invalid_product_option', 'Product option has invalid ID: ${o.optionId}', p.productId);
        }
        final shared = optionDefinitionsById[o.optionId];
        if (shared != null && shared.productTypes.isNotEmpty && !shared.productTypes.contains(p.productType)) {
          error('incompatible_shared_option', 'Shared option ${o.optionId} is not valid for product type ${p.productType}.', p.productId);
        }
        if (shared != null && !shared.active && o.active) {
          warn('inactive_shared_option', 'Product uses an inactive shared option definition: ${o.optionId}.', p.productId);
        }
      }
    }

    final activeProductsByCategory = <String, int>{};
    for (final p in catalog.products) {
      if (p.active) activeProductsByCategory[p.categoryId] = (activeProductsByCategory[p.categoryId] ?? 0) + 1;
    }
    for (final c in catalog.categories) {
      if (c.active && (activeProductsByCategory[c.categoryId] ?? 0) == 0) {
        warn('empty_active_category', 'Active category has no active products.', c.categoryId);
      }
    }

    return CatalogValidationReport(issues, DateTime.now());
  }
}
