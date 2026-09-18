import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_store_management/product_catalog/catalog_validator.dart';
import 'package:bigger_brew_store_management/product_catalog/product_catalog_models.dart';

ProductCategory category({String id = 'drinks', String name = 'Drinks', bool active = true}) =>
    ProductCategory(categoryId: id, name: name, subtitle: '', active: active);

CatalogProduct product({
  String id = 'latte',
  String name = 'Latte',
  String type = 'drink',
  String? temperature = 'iced',
  String categoryId = 'drinks',
  num? price = 120,
  String? sku,
  List<ProductSize> sizes = const [],
  List<ProductVariant> variants = const [],
  List<ProductOption> options = const [],
}) => CatalogProduct(
      productId: id,
      name: name,
      productType: type,
      drinkTemperature: temperature,
      categoryId: categoryId,
      active: true,
      available: true,
      price: price,
      sku: sku,
      sizes: sizes,
      variants: variants,
      options: options,
    );

ProductCatalog catalog(List<CatalogProduct> products, {int schemaVersion = 1, String version = 'v1'}) =>
    ProductCatalog(
      schemaVersion: schemaVersion,
      catalogVersion: version,
      categories: [category()],
      products: products,
    );

void main() {
  final validator = CatalogValidator();

  test('valid catalog has no errors', () {
    final report = validator.validate(catalog([product()]));
    expect(report.errors, 0);
  });

  test('rejects unsupported schema version', () {
    final report = validator.validate(catalog([product()], schemaVersion: 99));
    expect(report.issues.any((i) => i.code == 'unsupported_catalog_schema_version' && i.severity == 'error'), isTrue);
  });

  test('requires pricing when no size or variant pricing exists', () {
    final report = validator.validate(catalog([product(price: null)]));
    expect(report.issues.any((i) => i.code == 'missing_product_price' && i.severity == 'error'), isTrue);
  });

  test('validates drink temperature', () {
    final report = validator.validate(catalog([product(temperature: 'warm')]));
    expect(report.issues.any((i) => i.code == 'invalid_drink_temperature'), isTrue);
  });

  test('detects duplicate SKU', () {
    final report = validator.validate(catalog([
      product(id: 'latte', sku: 'SKU-1'),
      product(id: 'mocha', name: 'Mocha', sku: 'SKU-1'),
    ]));
    expect(report.issues.any((i) => i.code == 'duplicate_sku' && i.severity == 'error'), isTrue);
  });

  test('detects invalid drink size volume', () {
    final report = validator.validate(catalog([
      product(sizes: [const ProductSize(sizeId: 'regular', name: 'Regular', volumeMl: 0, price: 120)]),
    ]));
    expect(report.issues.any((i) => i.code == 'invalid_size_volume'), isTrue);
  });

  test('allows product-specific option without shared definition', () {
    final report = validator.validate(catalog([
      product(options: [const ProductOption(optionId: 'biscoff', name: 'Biscoff', price: 30, active: true)]),
    ]));
    expect(report.issues.any((i) => i.code == 'missing_shared_option'), isFalse);
    expect(report.errors, 0);
  });
}
