class ProductCatalog {
  /// Product-catalog data contract version. This is separate from the
  /// commercial catalogVersion and is used to guard file compatibility.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String catalogVersion;
  final List<ProductCategory> categories;
  final List<CatalogOptionDefinition> optionDefinitions;
  final List<CatalogProduct> products;

  const ProductCatalog({
    this.schemaVersion = currentSchemaVersion,
    required this.catalogVersion,
    required this.categories,
    this.optionDefinitions = const [],
    required this.products,
  });

  factory ProductCatalog.fromJson(Map<String, dynamic> json) {
    return ProductCatalog(
      schemaVersion: _parseSchemaVersion(json['schemaVersion']),
      catalogVersion: json['catalogVersion']?.toString() ?? '',
      categories: _parseCategories(json),
      optionDefinitions: (json['optionDefinitions'] as List<dynamic>? ?? const [])
          .map((e) => CatalogOptionDefinition.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      products: (json['products'] as List<dynamic>? ?? const [])
          .map((e) => CatalogProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'catalogVersion': catalogVersion,
    'categories': categories.map((e) => e.toJson()).toList(),
    'optionDefinitions': optionDefinitions.map((e) => e.toJson()).toList(),
    'products': products.map((e) => e.toJson()).toList(),
  };

  List<CatalogProduct> productsForCategory(String categoryId) {
    return products
        .where((product) => product.categoryId == categoryId && product.active)
        .toList(growable: false);
  }

  ProductCatalog copyWith({
    int? schemaVersion,
    String? catalogVersion,
    List<ProductCategory>? categories,
    List<CatalogOptionDefinition>? optionDefinitions,
    List<CatalogProduct>? products,
  }) {
    return ProductCatalog(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      categories: categories ?? this.categories,
      optionDefinitions: optionDefinitions ?? this.optionDefinitions,
      products: products ?? this.products,
    );
  }

  static List<ProductCategory> _parseCategories(Map<String, dynamic> json) {
    final raw = json['categories'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
    }

    // Legacy catalog files may predate the explicit categories array.
    // Derive the referenced categories so older kiosk/catalog data remains
    // readable without changing stable category IDs.
    final seen = <String>{};
    final derived = <ProductCategory>[];
    final products = json['products'];
    if (products is List) {
      for (final rawProduct in products) {
        if (rawProduct is! Map) continue;
        final id = rawProduct['categoryId']?.toString().trim() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        derived.add(ProductCategory(
          categoryId: id,
          name: _categoryDisplayName(id),
          subtitle: '',
          active: true,
        ));
      }
    }
    return List<ProductCategory>.unmodifiable(derived);
  }

  static String _categoryDisplayName(String id) {
    return id
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static int _parseSchemaVersion(dynamic value) {
    if (value == null) return currentSchemaVersion;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? -1;
  }

  CatalogOptionDefinition? optionDefinition(String optionId) {
    for (final option in optionDefinitions) {
      if (option.optionId == optionId) return option;
    }
    return null;
  }
}

class ProductCategory {
  final String categoryId;
  final String name;
  final String subtitle;
  final bool active;
  /// Optional emoji/icon selected by staff for the customer-facing kiosk.
  /// Kept nullable so legacy catalog files continue to work.
  final String? icon;

  const ProductCategory({
    required this.categoryId,
    required this.name,
    required this.subtitle,
    required this.active,
    this.icon,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      active: json['active'] == true,
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'name': name,
    'subtitle': subtitle,
    'active': active,
    if (icon != null && icon!.trim().isNotEmpty) 'icon': icon,
  };

  ProductCategory copyWith({
    String? categoryId,
    String? name,
    String? subtitle,
    bool? active,
    String? icon,
  }) => ProductCategory(
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    active: active ?? this.active,
    icon: icon ?? this.icon,
  );
}

class CatalogOptionDefinition {
  final String optionId;
  final String name;
  final List<String> productTypes;
  final num? price;
  final bool active;
  final bool kitchenPrepared;

  const CatalogOptionDefinition({
    required this.optionId,
    required this.name,
    required this.productTypes,
    this.price,
    required this.active,
    this.kitchenPrepared = false,
  });

  factory CatalogOptionDefinition.fromJson(Map<String, dynamic> json) {
    return CatalogOptionDefinition(
      optionId: json['optionId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      productTypes: (json['productTypes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      price: json['price'] as num?,
      active: json['active'] == true,
      kitchenPrepared: json['kitchenPrepared'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'optionId': optionId,
    'name': name,
    'productTypes': productTypes,
    if (price != null) 'price': price,
    'active': active,
    'kitchenPrepared': kitchenPrepared,
  };

  CatalogOptionDefinition copyWith({
    String? optionId, String? name, List<String>? productTypes,
    num? price, bool? active, bool? kitchenPrepared,
  }) => CatalogOptionDefinition(
    optionId: optionId ?? this.optionId, name: name ?? this.name,
    productTypes: productTypes ?? this.productTypes, price: price ?? this.price,
    active: active ?? this.active, kitchenPrepared: kitchenPrepared ?? this.kitchenPrepared,
  );
}

class CatalogProduct {
  final String productId;
  final String name;
  final String productType;
  /// Explicit drink temperature. Null preserves legacy catalog records.
  final String? drinkTemperature;
  final String categoryId;
  final String? groupId;
  final String? groupName;
  final String? description;
  final String? image;
  final bool active;
  final bool available;
  final bool kitchenPrepared;
  /// Base selling price for products without size/variant pricing.
  /// Size/variant prices remain authoritative when those structures are used.
  final num? price;
  final String? sku;
  final String? recipeRef;
  final List<ProductSize> sizes;
  final List<ProductVariant> variants;
  final List<ProductOption> options;

  const CatalogProduct({
    required this.productId,
    required this.name,
    required this.productType,
    this.drinkTemperature,
    required this.categoryId,
    this.groupId,
    this.groupName,
    this.description,
    this.image,
    required this.active,
    required this.available,
    this.kitchenPrepared = false,
    this.price,
    this.sku,
    this.recipeRef,
    required this.sizes,
    required this.variants,
    required this.options,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      productType: json['productType']?.toString() ?? '',
      drinkTemperature: json['drinkTemperature']?.toString(),
      categoryId: json['categoryId']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      groupName: json['groupName']?.toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      active: json['active'] == true,
      available: json['available'] == true,
      kitchenPrepared: json['kitchenPrepared'] == true,
      price: json['price'] as num?,
      sku: json['sku']?.toString(),
      recipeRef: json['recipeRef']?.toString(),
      sizes: (json['sizes'] as List<dynamic>? ?? const [])
          .map((e) => ProductSize.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => ProductOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId, 'name': name, 'productType': productType, if (drinkTemperature != null) 'drinkTemperature': drinkTemperature, 'categoryId': categoryId,
    if (groupId != null) 'groupId': groupId, if (groupName != null) 'groupName': groupName,
    if (description != null) 'description': description, if (image != null) 'image': image,
    'active': active, 'available': available, 'kitchenPrepared': kitchenPrepared,
    if (price != null) 'price': price,
    if (sku != null) 'sku': sku, if (recipeRef != null) 'recipeRef': recipeRef,
    'sizes': sizes.map((x) => x.toJson()).toList(), 'variants': variants.map((x) => x.toJson()).toList(),
    'options': options.map((x) => x.toJson()).toList(),
  };

  CatalogProduct copyWith({String? productId, String? name, String? productType, String? drinkTemperature, String? categoryId, String? groupId, String? groupName, String? description, String? image, bool? active, bool? available, bool? kitchenPrepared, num? price, String? sku, String? recipeRef, List<ProductSize>? sizes, List<ProductVariant>? variants, List<ProductOption>? options}) => CatalogProduct(
    productId: productId ?? this.productId, name: name ?? this.name, productType: productType ?? this.productType, drinkTemperature: drinkTemperature ?? this.drinkTemperature, categoryId: categoryId ?? this.categoryId,
    groupId: groupId ?? this.groupId, groupName: groupName ?? this.groupName, description: description ?? this.description, image: image ?? this.image,
    active: active ?? this.active, available: available ?? this.available, kitchenPrepared: kitchenPrepared ?? this.kitchenPrepared, price: price ?? this.price, sku: sku ?? this.sku,
    recipeRef: recipeRef ?? this.recipeRef, sizes: sizes ?? this.sizes, variants: variants ?? this.variants, options: options ?? this.options,
  );
}

class ProductSize {
  final String sizeId;
  final String name;
  final int? volumeMl;
  final String? displayVolume;
  final num? price;

  const ProductSize({
    required this.sizeId,
    required this.name,
    this.volumeMl,
    this.displayVolume,
    this.price,
  });

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      sizeId: json['sizeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      volumeMl: (json['volumeMl'] as num?)?.toInt(),
      displayVolume: json['displayVolume']?.toString(),
      price: json['price'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sizeId': sizeId, 'name': name, if (volumeMl != null) 'volumeMl': volumeMl,
    if (displayVolume != null) 'displayVolume': displayVolume, if (price != null) 'price': price,
  };

  ProductSize copyWith({String? sizeId, String? name, int? volumeMl, String? displayVolume, num? price}) => ProductSize(
    sizeId: sizeId ?? this.sizeId, name: name ?? this.name, volumeMl: volumeMl ?? this.volumeMl,
    displayVolume: displayVolume ?? this.displayVolume, price: price ?? this.price,
  );
}

class ProductVariant {
  final String variantId;
  final String name;
  final num? price;
  final bool active;

  const ProductVariant({
    required this.variantId,
    required this.name,
    this.price,
    required this.active,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      variantId: json['variantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price'] as num?,
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'variantId': variantId, 'name': name, if (price != null) 'price': price, 'active': active,
  };

  ProductVariant copyWith({String? variantId, String? name, num? price, bool? active}) => ProductVariant(
    variantId: variantId ?? this.variantId, name: name ?? this.name, price: price ?? this.price,
    active: active ?? this.active,
  );
}

class ProductOption {
  final String optionId;
  final String name;
  final num? price;
  final bool active;
  final bool kitchenPrepared;

  const ProductOption({
    required this.optionId,
    required this.name,
    this.price,
    required this.active,
    this.kitchenPrepared = false,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      optionId: json['optionId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price'] as num?,
      active: json['active'] == true,
      kitchenPrepared: json['kitchenPrepared'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'optionId': optionId, 'name': name, if (price != null) 'price': price,
    'active': active, 'kitchenPrepared': kitchenPrepared,
  };

  ProductOption copyWith({String? optionId, String? name, num? price, bool? active, bool? kitchenPrepared}) => ProductOption(
    optionId: optionId ?? this.optionId, name: name ?? this.name, price: price ?? this.price,
    active: active ?? this.active, kitchenPrepared: kitchenPrepared ?? this.kitchenPrepared,
  );
}
