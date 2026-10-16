import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'document_markup.dart';
import 'resume_design.dart';

/// Renders resumes and cover letters to A4 PDFs, to view in the app, save
/// to the device, or share (email, Drive…). Resumes come in several
/// [ResumeDesign]s; cover letters use the classic layout.
abstract final class DocumentPdf {
  static const _ink = PdfColor.fromInt(0xFF202326);
  static const _accent = PdfColor.fromInt(0xFF26808C);
  static const _muted = PdfColor.fromInt(0xFF5B6168);
  static const _rule = PdfColor.fromInt(0xFFDDE1E4);
  static const _sidebar = PdfColor.fromInt(0xFFF1F3F4);

  /// File name for [title], e.g. "Resume for UI Designer at Acme.pdf".
  static String fileNameFor(String title) => '${_fileName(title)}.pdf';

  static Future<void> share({
    required String title,
    required Uint8List bytes,
  }) =>
      Printing.sharePdf(bytes: bytes, filename: fileNameFor(title));

  /// Opens the system "Save as" screen (Downloads by default). Returns
  /// false if the user cancelled.
  static Future<bool> download({
    required String title,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileNameFor(title),
      bytes: bytes,
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return saved != null;
  }

  static Future<Uint8List> build(
    String content, {
    ResumeDesign design = ResumeDesign.classic,
  }) async {
    final fonts = await _Fonts.load();
    final doc = _Doc.parse(content);
    final document = pw.Document();
    document.addPage(switch (design) {
      ResumeDesign.classic => _single(doc, fonts, _Style.classic(fonts)),
      ResumeDesign.compact => _single(doc, fonts, _Style.compact(fonts)),
      ResumeDesign.plain => _single(doc, fonts, _Style.plain(fonts)),
      ResumeDesign.modern => _modern(doc, fonts),
    });
    return document.save();
  }

  /// One column: name, contact lines, then each section in order.
  static pw.MultiPage _single(_Doc doc, _Fonts fonts, _Style style) =>
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: style.margin,
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        build: (context) => [
          if (doc.name != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(doc.name!, style: style.name),
            ),
          ..._blocks(doc.intro, style, intro: true),
          for (final section in doc.sections) ...[
            _heading(section.title, style),
            ..._blocks(section.blocks, style),
          ],
        ],
      );

  /// A dark banner with the name and intro, then a sidebar (skills,
  /// education, languages…) beside the main sections.
  static pw.MultiPage _modern(_Doc doc, _Fonts fonts) {
    const sidebarWidth = 178.0;
    final main = _Style.modernMain(fonts);
    final side = _Style.modernSide(fonts);
    final sideSections = doc.sections.where((s) => s.isSidebar).toList();
    final mainSections = doc.sections.where((s) => !s.isSidebar).toList();

    return pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(bottom: 32),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        // The sidebar's tint runs the full height of every page.
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(width: sidebarWidth, color: _sidebar),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ),
      ),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          color: _ink,
          padding: const pw.EdgeInsets.fromLTRB(36, 34, 36, 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (doc.name != null)
                pw.Text(
                  doc.name!,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 24,
                    color: PdfColors.white,
                  ),
                ),
              ..._blocks(doc.intro, _Style.banner(fonts), intro: true),
            ],
          ),
        ),
        pw.Partitions(
          children: [
            pw.Partition(
              width: sidebarWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final section in sideSections) ...[
                    _inset(_heading(section.title, side), left: 22, right: 16),
                    for (final block in _blocks(section.blocks, side))
                      _inset(block, left: 22, right: 16),
                  ],
                ],
              ),
            ),
            pw.Partition(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final section in mainSections) ...[
                    _inset(_heading(section.title, main), left: 24, right: 36),
                    for (final block in _blocks(section.blocks, main))
                      _inset(block, left: 24, right: 36),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _inset(pw.Widget child, {required double left, required double right}) =>
      pw.Padding(padding: pw.EdgeInsets.only(left: left, right: right), child: child);

  static pw.Widget _heading(String text, _Style style) => pw.Container(
        margin: pw.EdgeInsets.only(top: style.headingGap, bottom: style.headingGap / 2.3),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: style.headingRule == null
            ? null
            : pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: style.headingRule!, width: 0.8),
                ),
              ),
        child: pw.Text(
          style.uppercaseHeadings ? text.toUpperCase() : text,
          style: style.heading,
        ),
      );

  static List<pw.Widget> _blocks(
    List<MarkupBlock> blocks,
    _Style style, {
    bool intro = false,
  }) {
    final body = intro ? style.intro : style.body;
    pw.TextSpan rich(List<MarkupSpan> parts) => pw.TextSpan(
          style: body,
          children: [
            for (final part in parts)
              pw.TextSpan(
                text: part.text,
                style: part.bold ? pw.TextStyle(font: style.boldFont) : null,
              ),
          ],
        );

    return [
      for (final block in blocks)
        switch (block) {
          // A stray title mid-document reads as a bold line.
          TitleBlock(:final text) || HeadingBlock(:final text) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
              child: pw.Text(text, style: body.copyWith(font: style.boldFont)),
            ),
          BulletBlock(:final spans) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: style.bulletGap),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(2, 0, 7, 0),
                    child: pw.Text('•', style: body.copyWith(color: style.bullet)),
                  ),
                  pw.Expanded(child: pw.RichText(text: rich(spans))),
                ],
              ),
            ),
          ParagraphBlock(:final spans) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.RichText(text: rich(spans)),
            ),
          GapBlock() => pw.SizedBox(height: style.gap),
        },
    ];
  }

  static String _fileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'Careerly_document' : cleaned;
  }
}

class _Fonts {
  const _Fonts(this.regular, this.semiBold, this.bold);

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;

  static Future<_Fonts> load() async {
    Future<pw.Font> font(String file) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/inter/$file'));
    return _Fonts(
      await font('Inter-Regular.ttf'),
      await font('Inter-SemiBold.ttf'),
      await font('Inter-Bold.ttf'),
    );
  }
}

/// Type, spacing and color for one layout.
class _Style {
  const _Style({
    required this.margin,
    required this.name,
    required this.intro,
    required this.body,
    required this.heading,
    required this.boldFont,
    required this.bullet,
    this.headingRule,
    this.uppercaseHeadings = true,
    this.headingGap = 14,
    this.bulletGap = 3,
    this.gap = 8,
  });

  final pw.EdgeInsets margin;
  final pw.TextStyle name;
  final pw.TextStyle intro;
  final pw.TextStyle body;
  final pw.TextStyle heading;
  final pw.Font boldFont;
  final PdfColor bullet;
  final PdfColor? headingRule;
  final bool uppercaseHeadings;
  final double headingGap;
  final double bulletGap;
  final double gap;

  static pw.TextStyle _text(pw.Font font, double size, {PdfColor? color, double spacing = 2.5}) =>
      pw.TextStyle(font: font, fontSize: size, color: color ?? DocumentPdf._ink, lineSpacing: spacing);

  factory _Style.classic(_Fonts f) => _Style(
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 44),
        name: pw.TextStyle(font: f.bold, fontSize: 22, color: DocumentPdf._ink),
        intro: _text(f.regular, 10, color: DocumentPdf._muted),
        body: _text(f.regular, 10.5),
        heading: pw.TextStyle(
          font: f.semiBold,
          fontSize: 10,
          color: DocumentPdf._accent,
          letterSpacing: 1,
        ),
        boldFont: f.bold,
        bullet: DocumentPdf._accent,
        headingRule: DocumentPdf._rule,
      );

  factory _Style.compact(_Fonts f) => _Style(
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 30),
        name: pw.TextStyle(font: f.bold, fontSize: 18, color: DocumentPdf._ink),
        intro: _text(f.regular, 9, color: DocumentPdf._muted, spacing: 1.5),
        body: _text(f.regular, 9.5, spacing: 1.5),
        heading: pw.TextStyle(
          font: f.semiBold,
          fontSize: 9,
          color: DocumentPdf._accent,
          letterSpacing: 0.8,
        ),
        boldFont: f.bold,
        bullet: DocumentPdf._accent,
        headingRule: DocumentPdf._rule,
        headingGap: 9,
        bulletGap: 1.5,
        gap: 4,
      );

  factory _Style.plain(_Fonts f) => _Style(
        margin: const pw.EdgeInsets.symmetric(horizontal: 54, vertical: 48),
        name: pw.TextStyle(font: f.bold, fontSize: 18, color: PdfColors.black),
        intro: _text(f.regular, 10, color: PdfColors.black),
        body: _text(f.regular, 10.5, color: PdfColors.black),
        heading: pw.TextStyle(font: f.bold, fontSize: 11, color: PdfColors.black),
        boldFont: f.bold,
        bullet: PdfColors.black,
        uppercaseHeadings: false,
        headingGap: 12,
      );

  factory _Style.banner(_Fonts f) => _Style(
        margin: pw.EdgeInsets.zero,
        name: pw.TextStyle(font: f.bold, fontSize: 24, color: PdfColors.white),
        intro: _text(f.regular, 9.5, color: const PdfColor.fromInt(0xFFD5D9DD)),
        body: _text(f.regular, 9.5, color: PdfColors.white),
        heading: pw.TextStyle(font: f.semiBold, fontSize: 10, color: PdfColors.white),
        boldFont: f.bold,
        bullet: PdfColors.white,
        gap: 4,
      );

  factory _Style.modernMain(_Fonts f) => _Style(
        margin: pw.EdgeInsets.zero,
        name: pw.TextStyle(font: f.bold, fontSize: 22),
        intro: _text(f.regular, 10, color: DocumentPdf._muted),
        body: _text(f.regular, 10),
        heading: pw.TextStyle(
          font: f.semiBold,
          fontSize: 10,
          color: DocumentPdf._accent,
          letterSpacing: 1,
        ),
        boldFont: f.bold,
        bullet: DocumentPdf._accent,
        headingRule: DocumentPdf._rule,
        headingGap: 16,
      );

  factory _Style.modernSide(_Fonts f) => _Style(
        margin: pw.EdgeInsets.zero,
        name: pw.TextStyle(font: f.bold, fontSize: 22),
        intro: _text(f.regular, 9, color: DocumentPdf._muted),
        body: _text(f.regular, 9, spacing: 2),
        heading: pw.TextStyle(
          font: f.semiBold,
          fontSize: 9,
          color: DocumentPdf._ink,
          letterSpacing: 1,
        ),
        boldFont: f.bold,
        bullet: DocumentPdf._accent,
        headingGap: 16,
        bulletGap: 2,
        gap: 5,
      );
}

/// A resume split into its name, the lines before the first section
/// (contact details, a headline), and its sections.
class _Doc {
  const _Doc(this.name, this.intro, this.sections);

  factory _Doc.parse(String content) {
    String? name;
    final intro = <MarkupBlock>[];
    final sections = <_Section>[];
    for (final block in parseMarkup(content)) {
      if (block is TitleBlock && name == null && sections.isEmpty) {
        name = block.text;
      } else if (block is HeadingBlock) {
        sections.add(_Section(block.text, []));
      } else if (sections.isEmpty) {
        intro.add(block);
      } else {
        sections.last.blocks.add(block);
      }
    }
    // Trailing gaps would only add space before the next heading.
    for (final section in sections) {
      while (section.blocks.isNotEmpty && section.blocks.last is GapBlock) {
        section.blocks.removeLast();
      }
    }
    while (intro.isNotEmpty && intro.last is GapBlock) {
      intro.removeLast();
    }
    return _Doc(name, intro, sections);
  }

  final String? name;
  final List<MarkupBlock> intro;
  final List<_Section> sections;
}

class _Section {
  _Section(this.title, this.blocks);

  final String title;
  final List<MarkupBlock> blocks;

  static final _sidebarTitles = RegExp(
    r'skill|tool|technolog|language|certif|award|interest|contact|link|'
    r'education|strength|competenc',
    caseSensitive: false,
  );

  /// Short reference sections that suit a sidebar.
  bool get isSidebar => _sidebarTitles.hasMatch(title);
}
