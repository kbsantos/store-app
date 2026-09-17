import 'product_catalog_models.dart';

/// Kiosk-side projection of a neutral catalog product.
///
/// This adapter intentionally contains no import from the Recipe Guide.
/// `recipeRef` is retained only as an identifier for future cross-system
/// traceability; the kiosk never resolves it.
class KioskCatalogProduct {
  final String productId;
  final String name;
  final String productType;
  /// Explicit drink temperature (hot/iced). Null for non-drinks and legacy products.
  final String? drinkTemperature;
  final String categoryId;
  final String? groupId;
  final String? groupName;
  final String? description;
  final String? image;
  final bool available;
  final bool kitchenPrepared;
  final num? price;
  final String? recipeRef;
  final List<ProductSize> sizes;
  final List<ProductVariant> variants;
  final List<ProductOption> options;

  const KioskCatalogProduct({
    required this.productId,
    required this.name,
    required this.productType,
    this.drinkTemperature,
    required this.categoryId,
    this.groupId,
    this.groupName,
    this.description,
    this.image,
    required this.available,
    required this.kitchenPrepared,
    this.price,
    this.recipeRef,
    required this.sizes,
    required this.variants,
    required this.options,
  });

  factory KioskCatalogProduct.fromCatalog(CatalogProduct product) {
    return KioskCatalogProduct(
      productId: product.productId,
      name: product.name,
      productType: product.productType,
      // New drinks default to Iced when the catalog does not yet specify
      // a temperature. Non-drinks remain null.
      drinkTemperature: product.drinkTemperature ??
          (product.productType.trim().toLowerCase() == 'drink' ? 'iced' : null),
      categoryId: product.categoryId,
      groupId: product.groupId,
      groupName: product.groupName,
      description: product.description,
      image: product.image,
      available: product.available,
      kitchenPrepared: product.kitchenPrepared,
      price: product.price,
      recipeRef: product.recipeRef,
      sizes: product.sizes,
      variants: product.variants,
      options: product.options,
    );
  }
}

class KioskCatalogAdapter {
  const KioskCatalogAdapter();

  List<KioskCatalogProduct> productsForCategory(
    ProductCatalog catalog,
    String categoryId,
  ) {
    return catalog.products
        .where((product) =>
            product.active &&
            product.categoryId == categoryId)
        .map(KioskCatalogProduct.fromCatalog)
        .toList(growable: false);
  }
}
