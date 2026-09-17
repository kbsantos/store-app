import 'package:flutter/material.dart';
import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import '../../product_catalog/catalog_validator.dart';

class CatalogValidationController extends ChangeNotifier {
  final ProductCatalogRepository repository;
  CatalogValidationReport? report;
  ProductCatalog? catalog;
  bool loading = false;
  CatalogValidationController({ProductCatalogRepository? repository}) : repository = repository ?? const ProductCatalogRepository();
  Future<void> validate() async {
    loading = true; notifyListeners();
    try { catalog = await repository.load(); report = CatalogValidator().validate(catalog!); }
    finally { loading = false; notifyListeners(); }
  }
}

class CatalogValidationPage extends StatefulWidget {
  const CatalogValidationPage({super.key});
  @override State<CatalogValidationPage> createState() => _CatalogValidationPageState();
}
class _CatalogValidationPageState extends State<CatalogValidationPage> {
  final c = CatalogValidationController();
  bool errorsOnly = false;
  @override void initState() { super.initState(); c.addListener(_changed); c.validate(); }
  void _changed() { if (mounted) setState(() {}); }
  @override void dispose() { c.removeListener(_changed); c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final r = c.report;
    final issues = r?.issues.where((i) => !errorsOnly || i.severity == 'error').toList() ?? const [];
    return Scaffold(backgroundColor: const Color(0xFFF5F2ED), appBar: AppBar(backgroundColor: const Color(0xFF171717), foregroundColor: Colors.white, title: const Text('CATALOG HEALTH CHECK', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: c.validate, icon: const Icon(Icons.refresh))]), body: c.loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [if (r != null) _summary(r), const SizedBox(height: 16), if (r != null) SwitchListTile(title: const Text('Show errors only'), value: errorsOnly, onChanged: (v) => setState(() => errorsOnly = v)), ...issues.map(_issue), if (r != null && r.issues.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(28), child: Column(children: [Icon(Icons.verified, size: 56), SizedBox(height: 12), Text('CATALOG HEALTHY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('No integrity issues detected.')]))) ]));
  }
  Widget _summary(CatalogValidationReport r) { final healthy = r.errors == 0; return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(healthy ? 'READY' : 'ACTION REQUIRED', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 14), Wrap(spacing: 12, runSpacing: 12, children: [_stat('Products', '${c.catalog!.products.length}'), _stat('Categories', '${c.catalog!.categories.length}'), _stat('Errors', '${r.errors}'), _stat('Warnings', '${r.warnings}')]), const SizedBox(height: 10), Text('Checked ${r.checkedAt.toLocal()}')]))); }
  Widget _stat(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(label)]));
  Widget _issue(CatalogValidationIssue i) => Card(child: ListTile(leading: Icon(i.severity == 'error' ? Icons.error : Icons.warning), title: Text(i.message), subtitle: Text('${i.code}${i.entityId == null ? '' : ' • ${i.entityId}'}')));
}
