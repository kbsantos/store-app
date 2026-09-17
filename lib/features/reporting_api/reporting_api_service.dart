import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only client for the MyCoffeeShop store-scoped reporting REST API.
/// The caller must have an authenticated Supabase session whose JWT
/// app_metadata contains the permitted store_id.
class ReportingApiService {
  ReportingApiService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool get isAuthenticated => _client.auth.currentSession != null;

  Future<List<ReportingProductSale>> getProductSales({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? deviceId,
  }) async {
    _requireSession();
    var query = _client
        .from('report_product_sales')
        .select(
          'store_id,device_id,sales_date,category,product_id,product_name,quantity_sold,total_sales,average_unit_price',
        )
        .gte('sales_date', _dateOnly(startDate))
        .lte('sales_date', _dateOnly(endDate));
    if (category != null && category.trim().isNotEmpty && category != 'ALL') {
      query = query.eq('category', category.trim());
    }
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      query = query.eq('device_id', deviceId.trim());
    }
    final rows = await query
        .order('category')
        .order('product_name')
        .order('sales_date');
    return rows.map(ReportingProductSale.fromMap).toList(growable: false);
  }

  Future<List<ReportingCategorySale>> getCategorySales({
    required DateTime startDate,
    required DateTime endDate,
    String? deviceId,
  }) async {
    _requireSession();
    var query = _client
        .from('report_category_sales')
        .select(
          'store_id,device_id,sales_date,category,quantity_sold,total_sales',
        )
        .gte('sales_date', _dateOnly(startDate))
        .lte('sales_date', _dateOnly(endDate));
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      query = query.eq('device_id', deviceId.trim());
    }
    final rows = await query.order('category').order('sales_date');
    return rows.map(ReportingCategorySale.fromMap).toList(growable: false);
  }

  Future<List<ReportingDailySale>> getDailySales({
    required DateTime startDate,
    required DateTime endDate,
    String? deviceId,
  }) async {
    _requireSession();
    var query = _client
        .from('report_daily_sales')
        .select(
          'store_id,device_id,sales_date,transaction_count,subtotal,discount,total_sales',
        )
        .gte('sales_date', _dateOnly(startDate))
        .lte('sales_date', _dateOnly(endDate));
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      query = query.eq('device_id', deviceId.trim());
    }
    final rows = await query.order('sales_date');
    return rows.map(ReportingDailySale.fromMap).toList(growable: false);
  }

  Future<List<ReportingDeviceSale>> getDeviceSales({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _requireSession();
    final rows = await _client
        .from('report_device_sales')
        .select(
          'store_id,device_id,sales_date,transaction_count,subtotal,discount,total_sales',
        )
        .gte('sales_date', _dateOnly(startDate))
        .lte('sales_date', _dateOnly(endDate))
        .order('device_id')
        .order('sales_date');
    return rows.map(ReportingDeviceSale.fromMap).toList(growable: false);
  }

  void _requireSession() {
    if (!isAuthenticated) {
      throw StateError(
        'Reporting API requires an authenticated Supabase session with app_metadata.store_id.',
      );
    }
  }

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class ReportingProductSale {
  const ReportingProductSale({
    required this.storeId,
    required this.deviceId,
    required this.salesDate,
    required this.category,
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalSales,
    required this.averageUnitPrice,
  });
  final String storeId, deviceId, category, productId, productName;
  final DateTime salesDate;
  final int quantitySold;
  final num totalSales, averageUnitPrice;
  factory ReportingProductSale.fromMap(Map<String, dynamic> map) =>
      ReportingProductSale(
        storeId: '${map['store_id'] ?? ''}',
        deviceId: '${map['device_id'] ?? ''}',
        salesDate: DateTime.parse('${map['sales_date']}'),
        category: '${map['category'] ?? 'Uncategorized'}',
        productId: '${map['product_id'] ?? ''}',
        productName: '${map['product_name'] ?? ''}',
        quantitySold: _toInt(map['quantity_sold']),
        totalSales: _toNum(map['total_sales']),
        averageUnitPrice: _toNum(map['average_unit_price']),
      );
}

class ReportingCategorySale {
  const ReportingCategorySale({
    required this.storeId,
    required this.deviceId,
    required this.salesDate,
    required this.category,
    required this.quantitySold,
    required this.totalSales,
  });
  final String storeId, deviceId, category;
  final DateTime salesDate;
  final int quantitySold;
  final num totalSales;
  factory ReportingCategorySale.fromMap(Map<String, dynamic> map) =>
      ReportingCategorySale(
        storeId: '${map['store_id'] ?? ''}',
        deviceId: '${map['device_id'] ?? ''}',
        salesDate: DateTime.parse('${map['sales_date']}'),
        category: '${map['category'] ?? 'Uncategorized'}',
        quantitySold: _toInt(map['quantity_sold']),
        totalSales: _toNum(map['total_sales']),
      );
}

class ReportingDailySale {
  const ReportingDailySale({
    required this.storeId,
    required this.deviceId,
    required this.salesDate,
    required this.transactionCount,
    required this.subtotal,
    required this.discount,
    required this.totalSales,
  });
  final String storeId, deviceId;
  final DateTime salesDate;
  final int transactionCount;
  final num subtotal, discount, totalSales;
  factory ReportingDailySale.fromMap(Map<String, dynamic> map) =>
      ReportingDailySale(
        storeId: '${map['store_id'] ?? ''}',
        deviceId: '${map['device_id'] ?? ''}',
        salesDate: DateTime.parse('${map['sales_date']}'),
        transactionCount: _toInt(map['transaction_count']),
        subtotal: _toNum(map['subtotal']),
        discount: _toNum(map['discount']),
        totalSales: _toNum(map['total_sales']),
      );
}

class ReportingDeviceSale {
  const ReportingDeviceSale({
    required this.storeId,
    required this.deviceId,
    required this.salesDate,
    required this.transactionCount,
    required this.subtotal,
    required this.discount,
    required this.totalSales,
  });
  final String storeId, deviceId;
  final DateTime salesDate;
  final int transactionCount;
  final num subtotal, discount, totalSales;
  factory ReportingDeviceSale.fromMap(Map<String, dynamic> map) =>
      ReportingDeviceSale(
        storeId: '${map['store_id'] ?? ''}',
        deviceId: '${map['device_id'] ?? ''}',
        salesDate: DateTime.parse('${map['sales_date']}'),
        transactionCount: _toInt(map['transaction_count']),
        subtotal: _toNum(map['subtotal']),
        discount: _toNum(map['discount']),
        totalSales: _toNum(map['total_sales']),
      );
}

int _toInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
num _toNum(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
