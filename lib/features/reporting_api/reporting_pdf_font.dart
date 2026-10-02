import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Unicode-safe fonts shared by every Store Management PDF.
///
/// DejaVu Sans has a broad Unicode glyph set, including the Philippine peso
/// sign (₱), bullets, accented characters, and other punctuation used by
/// store/catalog data. The fonts are bundled locally so PDF rendering is
/// deterministic and does not depend on the host/browser fonts.
class StoreReportingPdfFont {
  static Future<pw.ThemeData> theme() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );
  }
}
