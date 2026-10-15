/// Parses the light Markdown used by resumes and cover letters into blocks,
/// shared by the in-app view and the PDF export.
sealed class MarkupBlock {
  const MarkupBlock();
}

/// `# Name`
class TitleBlock extends MarkupBlock {
  const TitleBlock(this.text);
  final String text;
}

/// `## Section`
class HeadingBlock extends MarkupBlock {
  const HeadingBlock(this.text);
  final String text;
}

/// `- item`
class BulletBlock extends MarkupBlock {
  const BulletBlock(this.spans);
  final List<MarkupSpan> spans;
}

/// Any other line (consecutive lines join into one paragraph).
class ParagraphBlock extends MarkupBlock {
  const ParagraphBlock(this.spans);
  final List<MarkupSpan> spans;
}

/// Vertical space for a blank line.
class GapBlock extends MarkupBlock {
  const GapBlock();
}

class MarkupSpan {
  const MarkupSpan(this.text, {this.bold = false});
  final String text;
  final bool bold;
}

List<MarkupBlock> parseMarkup(String source) {
  final blocks = <MarkupBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(parseSpans(paragraph.join(' '))));
    paragraph.clear();
  }

  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      flush();
      if (blocks.isNotEmpty && blocks.last is! GapBlock) {
        blocks.add(const GapBlock());
      }
    } else if (trimmed.startsWith('## ') || trimmed.startsWith('### ')) {
      flush();
      blocks.add(HeadingBlock(_strip(trimmed.replaceFirst(RegExp(r'^#+\s'), ''))));
    } else if (trimmed.startsWith('# ')) {
      flush();
      blocks.add(TitleBlock(_strip(trimmed.substring(2))));
    } else if (RegExp(r'^[-*•]\s').hasMatch(trimmed)) {
      flush();
      blocks.add(BulletBlock(parseSpans(trimmed.substring(2).trim())));
    } else {
      paragraph.add(trimmed);
    }
  }
  flush();
  while (blocks.isNotEmpty && blocks.last is GapBlock) {
    blocks.removeLast();
  }
  return blocks;
}

/// Splits `**bold**` markers into spans.
List<MarkupSpan> parseSpans(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) MarkupSpan(parts[i], bold: i.isOdd),
  ];
}

/// Plain text without markup, for copying.
String markupToPlainText(String source) => source
    .replaceAll(RegExp(r'^#+\s', multiLine: true), '')
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^[-*]\s', multiLine: true), '• ');

String _strip(String text) => text.replaceAll('**', '').trim();
