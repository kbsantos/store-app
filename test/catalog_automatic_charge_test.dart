import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_store_management/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_store_management/product_catalog/catalog_validator.dart';

void main() {
  test('automatic charge round trips through catalog JSON', () {
    const charge = CatalogAutomaticCharge(
      chargeId: 'packaging_fee',
      name: 'Packaging Fee',
      amount: 5,
      active: true,
      scope: 'product_type',
      productTypes: ['drink'],
    );
    final decoded = CatalogAutomaticCharge.fromJson(charge.toJson());
    expect(decoded.chargeId, 'packaging_fee');
    expect(decoded.amount, 5);
    expect(decoded.productTypes, ['drink']);
  });

  test('valid automatic charge passes catalog validation', () {
    final catalog = ProductCatalog(
      catalogVersion: 'v1',
      categories: const [ProductCategory(categoryId: 'drinks', name: 'Drinks', subtitle: '', active: true)],
      products: const [CatalogProduct(productId: 'latte', name: 'Latte', productType: 'drink', drinkTemperature: 'iced', categoryId: 'drinks', active: true, available: true, price: 120, sizes: const [], variants: const [], options: const [])],
      automaticCharges: const [CatalogAutomaticCharge(chargeId: 'packaging_fee', name: 'Packaging Fee', amount: 5, active: true, scope: 'product_type', productTypes: ['drink'])],
    );
    expect(CatalogValidator().validate(catalog).errors, 0);
  });

  test('automatic charge requires a target', () {
    final catalog = ProductCatalog(
      catalogVersion: 'v1',
      categories: const [ProductCategory(categoryId: 'drinks', name: 'Drinks', subtitle: '', active: true)],
      products: const [CatalogProduct(productId: 'latte', name: 'Latte', productType: 'drink', drinkTemperature: 'iced', categoryId: 'drinks', active: true, available: true, price: 120, sizes: const [], variants: const [], options: const [])],
      automaticCharges: const [CatalogAutomaticCharge(chargeId: 'fee', name: 'Fee', amount: 5, active: true, scope: 'product_type')],
    );
    expect(CatalogValidator().validate(catalog).issues.any((i) => i.code == 'missing_charge_target'), isTrue);
  });
}
