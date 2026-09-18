import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_store_management/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_store_management/product_catalog/product_catalog_repository.dart';

void main() {
  test('allows product-specific options without shared definitions', () {
    final catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: const [
        ProductCategory(
          categoryId: 'drinks',
          name: 'Drinks',
          subtitle: '',
          icon: null,
          active: true,
        ),
      ],
      optionDefinitions: const [],
      products: const [
        CatalogProduct(
          productId: 'biscoff_milktea',
          name: 'Biscoff Milktea',
          productType: 'drink',
          categoryId: 'drinks',
          active: true,
          available: true,
          sizes: [],
          variants: [],
          options: [
            ProductOption(
              optionId: 'testoption',
              name: 'Test Option',
              price: 10,
              active: true,
              kitchenPrepared: false,
            ),
          ],
        ),
      ],
    );

    expect(() => ProductCatalogRepository.validate(catalog), returnsNormally);
  });
}
