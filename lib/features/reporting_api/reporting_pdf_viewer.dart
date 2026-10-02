import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../home/pdf_download_stub.dart'
    if (dart.library.html) '../home/pdf_download_web.dart' as pdf_download;

class ReportingPdfViewer {
  static Future<void> show({
    required BuildContext context,
    required String filename,
    required Future<Uint8List> Function(PdfPageFormat format) build,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(dialogContext).height * 0.9,
          child: PdfPreview(
            build: build,
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: filename,
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.download_outlined),
                onPressed: (context, buildPdf, pageFormat) async {
                  try {
                    final bytes = await buildPdf(pageFormat);
                    await pdf_download.downloadPdf(bytes, filename);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to download PDF: $error')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
