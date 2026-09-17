class StoreCurrency {
  static const code = 'PHP';
  static const symbol = '₱';

  static String format(num value) => '$symbol${value.toStringAsFixed(2)}';
}
