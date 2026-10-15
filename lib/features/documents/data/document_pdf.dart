import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'document_markup.dart';

/// Renders resumes and cover letters to a clean A4 PDF and opens the share
/// sheet (save to Files, email, Drive…).
abstract final class DocumentPdf {
  static const _accent = PdfColor.fromInt(0xFF2563EB);
  static const _muted = PdfColor.fromInt(0xFF4B5563);

  static Future<void> share({
    required String title,
    required String content,
  }) async {
    final bytes = await build(content);
    await Printing.sharePdf(bytes: bytes, filename: '${_fileName(title)}.pdf');
  }

  static Future<Uint8List> build(String content) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/inter/Inter-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/inter/Inter-Bold.ttf'),
    );
    final semiBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/inter/Inter-SemiBold.ttf'),
    );

    final body = pw.TextStyle(font: regular, fontBold: bold, fontSize: 10.5, lineSpacing: 2.5);
    pw.TextSpan rich(List<MarkupSpan> parts) => pw.TextSpan(
          children: [
            for (final part in parts)
              pw.TextSpan(
                text: part.text,
                style: part.bold ? pw.TextStyle(font: bold) : null,
              ),
          ],
        );

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 44),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          for (final block in parseMarkup(content))
            switch (block) {
              TitleBlock(:final text) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(font: bold, fontSize: 22),
                  ),
                ),
              HeadingBlock(:final text) => pw.Container(
                  margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                    ),
                  ),
                  child: pw.Text(
                    text.toUpperCase(),
                    style: pw.TextStyle(
                      font: semiBold,
                      fontSize: 10,
                      color: _accent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              BulletBlock(:final spans) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.fromLTRB(2, 0, 8, 0),
                        child: pw.Text('•', style: body.copyWith(color: _muted)),
                      ),
                      pw.Expanded(child: pw.RichText(text: pw.TextSpan(style: body, children: [rich(spans)]))),
                    ],
                  ),
                ),
              ParagraphBlock(:final spans) => pw.RichText(text: pw.TextSpan(style: body, children: [rich(spans)])),
              GapBlock() => pw.SizedBox(height: 8),
            },
        ],
      ),
    );
    return document.save();
  }

  static String _fileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Careerly_document' : cleaned;
  }
}
