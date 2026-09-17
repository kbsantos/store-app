import 'product_catalog_models.dart';

/// Protects catalog import/restore from schema formats this kiosk cannot safely read.
class CatalogSchemaGuard {
  static const int currentSchemaVersion = ProductCatalog.currentSchemaVersion;
  static const int minimumSupportedSchemaVersion = 1;

  const CatalogSchemaGuard._();

  static ProductCatalog decodeAndValidate(Map<String, dynamic> json, {required String source}) {
    final normalized = migrateLegacyJson(Map<String, dynamic>.from(json));
    final schemaVersion = _readSchemaVersion(normalized['schemaVersion']);
    ensureSupported(schemaVersion, source: source);
    return ProductCatalog.fromJson(normalized);
  }

  /// Legacy K15.3.14 files did not contain schemaVersion. They are explicitly
  /// recognized as schema 1 rather than being silently treated as a future format.
  static Map<String, dynamic> migrateLegacyJson(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    result['schemaVersion'] ??= currentSchemaVersion;
    return result;
  }

  static void ensureSupported(int schemaVersion, {required String source}) {
    if (schemaVersion < minimumSupportedSchemaVersion) {
      throw StateError(
        'Unsupported $source schema version $schemaVersion. Minimum supported version is $minimumSupportedSchemaVersion.',
      );
    }
    if (schemaVersion > currentSchemaVersion) {
      throw StateError(
        'Incompatible $source schema version $schemaVersion. This kiosk supports schema version $currentSchemaVersion or earlier.',
      );
    }
  }

  static int _readSchemaVersion(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }
}
