import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../product_catalog/catalog_schema_guard.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import '../../core/auth/store_management_auth.dart';

class StoreCatalogMasterService {
  StoreCatalogMasterService({ProductCatalogRepository? repository})
      : _repository = repository ?? const ProductCatalogRepository();

  final ProductCatalogRepository _repository;
  static const _versionKey = 'bigger_brew_store_management_catalog_version_v1';

  String _storeId() {
    final id = const StoreManagementAuth().storeId?.trim() ?? '';
    if (id.isEmpty) throw StateError('Your account is not assigned to a store.');
    return id;
  }

  void _requireManager() {
    final auth = const StoreManagementAuth();
    if (!auth.isSignedIn) throw StateError('Please sign in first.');
    if (!auth.canManageCatalog) throw StateError('Manager or owner access is required for catalog changes.');
  }

  Future<ProductCatalog> loadMasterCatalog() async {
    final storeId = _storeId();
    final client = Supabase.instance.client;
    final version = (await client.rpc('get_store_management_catalog_version')).toString().trim();
    if (version.isEmpty) throw StateError('No store master catalog exists yet.');
    final raw = await client.rpc('get_store_management_catalog');
    if (raw is! Map) throw const FormatException('The store master catalog returned an invalid payload.');
    final json = Map<String, dynamic>.from(raw);
    json['catalogVersion'] = (json['catalogVersion'] ?? version).toString();
    json['schemaVersion'] = json['schemaVersion'] ?? ProductCatalog.currentSchemaVersion;
    final catalog = CatalogSchemaGuard.decodeAndValidate(json, source: 'store master catalog');
    ProductCatalogRepository.validate(catalog);
    if (storeId.isEmpty) throw StateError('Invalid store access.');
    return catalog;
  }

  Future<ProductCatalog> publishCatalog(ProductCatalog catalog, {String auditAction = 'Publish catalog'}) async {
    _requireManager();
    CatalogSchemaGuard.ensureSupported(catalog.schemaVersion, source: 'catalog');
    ProductCatalogRepository.validate(catalog);
    final client = Supabase.instance.client;
    final currentVersion = (await client.rpc('get_store_management_catalog_version')).toString().trim();
    if (currentVersion.isEmpty) throw StateError('No store master catalog exists yet. Initialize it first.');
    final result = await client.rpc('publish_store_catalog_from_management', params: {
      'p_expected_version': currentVersion,
      'p_catalog': catalog.toJson(),
    });
    final newVersion = result?.toString().trim() ?? '';
    if (newVersion.isEmpty) throw StateError('The database did not return the new catalog version.');
    final accepted = catalog.copyWith(catalogVersion: newVersion);
    ProductCatalogRepository.validate(accepted);
    await _repository.saveCatalog(accepted, auditAction: auditAction);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, newVersion);
    return accepted;
  }

  Future<void> cacheMasterCatalog(ProductCatalog catalog, {String auditAction = 'Refresh catalog'}) async {
    await _repository.saveCatalog(catalog, auditAction: auditAction);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, catalog.catalogVersion);
  }
}
