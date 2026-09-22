class HourlySale {
  const HourlySale({
    required this.hour,
    required this.label,
    required this.transactionCount,
    required this.itemCount,
    required this.totalSales,
  });

  final int hour;
  final String label;
  final int transactionCount;
  final int itemCount;
  final num totalSales;

  factory HourlySale.fromMap(Map<String, dynamic> map) => HourlySale(
        hour: _toInt(map['hour']),
        label: '${map['label'] ?? ''}',
        transactionCount: _toInt(map['transactionCount']),
        itemCount: _toInt(map['itemCount']),
        totalSales: _toNum(map['totalSales']),
      );
}

int _toInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
num _toNum(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
