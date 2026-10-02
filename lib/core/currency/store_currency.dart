class StoreCurrency {
  static const code = 'PHP';
  static const symbol = '₱';

  /// Formats monetary values with thousands separators and two decimals.
  /// Example: 12500.5 -> ₱12,500.50
  static String format(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    return '$symbol$formattedInteger.$decimalPart';
  }
}
