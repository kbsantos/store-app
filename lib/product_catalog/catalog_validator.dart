import 'product_catalog_models.dart';

class CatalogValidationIssue {
  final String code;
  final String severity;
  final String message;
  final String? entityId;
  const CatalogValidationIssue(
      {required this.code,
      required this.severity,
      required this.message,
      this.entityId});
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

  CatalogValidationReport validate(ProductCatalog catalog) {
    final issues = <CatalogValidationIssue>[];
    void error(String code, String message, [String? id]) =>
        issues.add(CatalogValidationIssue(
            code: code, severity: 'error', message: message, entityId: id));
    void warn(String code, String message, [String? id]) =>
        issues.add(CatalogValidationIssue(
            code: code, severity: 'warning', message: message, entityId: id));

    final categoryIds = <String>{};
    for (final c in catalog.categories) {
      if (c.categoryId.isEmpty || !_id.hasMatch(c.categoryId)) {
        error('invalid_category_id', 'Invalid category ID: ${c.categoryId}',
            c.categoryId);
      }
      if (!categoryIds.add(c.categoryId)) {
        error('duplicate_category_id', 'Duplicate category ID: ${c.categoryId}',
            c.categoryId);
      }
      if (c.name.trim().isEmpty) {
        error('missing_category_name', 'Category name is required.',
            c.categoryId);
      }
    }

    final optionIds = <String>{};
    for (final o in catalog.optionDefinitions) {
      if (o.optionId.isEmpty || !_id.hasMatch(o.optionId)) {
        error('invalid_option_id', 'Invalid option ID: ${o.optionId}',
            o.optionId);
      }
      if (!optionIds.add(o.optionId)) {
        error('duplicate_option_id',
            'Duplicate shared option ID: ${o.optionId}', o.optionId);
      }
      if (o.name.trim().isEmpty) {
        error('missing_option_name', 'Option name is required.', o.optionId);
      }
      if (o.price != null && o.price! < 0) {
        error('negative_option_price', 'Option price cannot be negative.',
            o.optionId);
      }
      for (final type in o.productTypes) {
        if (!_types.contains(type)) {
          error('invalid_option_product_type',
              'Option uses invalid product type: $type', o.optionId);
        }
      }
    }

    final productIds = <String>{};
    for (final p in catalog.products) {
      if (p.productId.isEmpty || !_id.hasMatch(p.productId)) {
        error('invalid_product_id', 'Invalid product ID: ${p.productId}',
            p.productId);
      }
      if (!productIds.add(p.productId)) {
        error('duplicate_product_id', 'Duplicate product ID: ${p.productId}',
            p.productId);
      }
      if (p.name.trim().isEmpty) {
        error('missing_product_name', 'Product name is required.', p.productId);
      }
      if (!_types.contains(p.productType)) {
        error('invalid_product_type', 'Invalid product type: ${p.productType}',
            p.productId);
      }
      final category = catalog.categories
          .where((c) => c.categoryId == p.categoryId)
          .toList();
      if (category.isEmpty) {
        error(
            'missing_category_reference',
            'Product references missing category: ${p.categoryId}',
            p.productId);
      } else if (!category.single.active) {
        warn(
            'inactive_category_product',
            'Product is assigned to inactive category: ${category.single.name}',
            p.productId);
      }
      if (p.productType == 'drink' && p.recipeRef == null) {
        warn('drink_missing_recipe_ref', 'Drink has no recipe reference.',
            p.productId);
      }
      final sizeIds = <String>{};
      for (final s in p.sizes) {
        if (s.sizeId.isEmpty || !_id.hasMatch(s.sizeId)) {
          error('invalid_size_id', 'Invalid size ID: ${s.sizeId}', p.productId);
        }
        if (!sizeIds.add(s.sizeId)) {
          error('duplicate_size_id',
              'Duplicate size ID ${s.sizeId} on product.', p.productId);
        }
        if (s.name.trim().isEmpty) {
          error('missing_size_name', 'Size name is required.', p.productId);
        }
        if (s.price != null && s.price! < 0) {
          error('negative_size_price', 'Size ${s.sizeId} has negative price.',
              p.productId);
        }
      }
      if (p.sizes.length > 1) {
        final unpriced = p.sizes.where((s) => s.price == null).toList();
        if (unpriced.isNotEmpty) {
          warn(
              'incomplete_size_pricing',
              'Product has ${unpriced.length} unpriced configured size(s).',
              p.productId);
        }
      }
      final variantIds = <String>{};
      for (final v in p.variants) {
        if (v.variantId.isEmpty || !_id.hasMatch(v.variantId)) {
          error('invalid_variant_id', 'Invalid variant ID: ${v.variantId}',
              p.productId);
        }
        if (!variantIds.add(v.variantId)) {
          error('duplicate_variant_id',
              'Duplicate variant ID ${v.variantId} on product.', p.productId);
        }
        if (v.name.trim().isEmpty) {
          error(
              'missing_variant_name', 'Variant name is required.', p.productId);
        }
        if (v.price != null && v.price! < 0) {
          error('negative_variant_price',
              'Variant ${v.variantId} has negative price.', p.productId);
        }
      }
      final productOptionIds = <String>{};
      for (final o in p.options) {
        if (!productOptionIds.add(o.optionId)) {
          error('duplicate_product_option',
              'Duplicate option ${o.optionId} on product.', p.productId);
        }
        if (o.name.trim().isEmpty) {
          error('missing_product_option_name',
              'Product option name is required.', p.productId);
        }
        if (o.price != null && o.price! < 0) {
          error('negative_product_option_price',
              'Product option ${o.optionId} has negative price.', p.productId);
        }
        if (o.optionId.trim().isEmpty) {
          error('invalid_product_option', 'Product option has invalid ID.',
              p.productId);
        } else if (catalog.optionDefinition(o.optionId) == null) {
          warn(
              'unregistered_product_option',
              'Product option is not present in shared option definitions.',
              p.productId);
        }
      }
    }
    return CatalogValidationReport(issues, DateTime.now());
  }
}
