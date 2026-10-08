import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Store PDF generators use the bundled Unicode-safe font theme', () {
    final reporting = File('lib/features/reporting_api/reporting_pdf_service.dart').readAsStringSync();
    final dashboard = File('lib/features/home/store_dashboard_pdf_service.dart').readAsStringSync();
    final export = File('lib/features/reporting_api/reporting_export_service.dart').readAsStringSync();
    final font = File('lib/features/reporting_api/reporting_pdf_font.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(reporting, contains('StoreReportingPdfFont.theme()'));
    expect(reporting, contains('theme: theme'));
    expect(dashboard, contains('StoreReportingPdfFont.theme()'));
    expect(dashboard, contains('theme: theme'));
    expect(export, contains("import 'reporting_pdf_font.dart';"));
    expect(export, contains('final theme = await StoreReportingPdfFont.theme();'));
    expect(export, contains('theme: theme'));

    expect(font, contains('assets/fonts/DejaVuSans.ttf'));
    expect(font, contains('assets/fonts/DejaVuSans-Bold.ttf'));
    expect(pubspec, contains('assets/fonts/DejaVuSans.ttf'));
    expect(pubspec, contains('assets/fonts/DejaVuSans-Bold.ttf'));
    expect(pubspec, isNot(contains('NotoSans-Regular.ttf')));
  });
}
