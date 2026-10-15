import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import 'resume_insights.dart';

/// Reads a resume PDF with AI and returns its key facts.
class ResumeReader {
  ResumeReader(this.ai);

  final AiChain ai;

  /// Resumes rarely exceed this; it also bounds the text sent to Groq.
  static const _maxTextLength = 20000;

  static const _system =
      'You are a career assistant that reads resumes and extracts structured '
      'facts. Only use what the resume says. Reply with JSON only.';

  static const _prompt = '''
Read the attached resume and return a JSON object with these keys:
- "headline": one line, e.g. "UI/UX designer with 4 years in fintech"
- "summary": 2-3 sentences on experience and strengths
- "roles": up to 5 job titles this person should search for, best fit first
- "skills": up to 25 concrete skills and tools (e.g. "Figma", "SQL", "Customer service")
- "years_of_experience": total years of professional experience as a number, or null
- "seniority": one of "Entry-level", "Junior", "Mid-level", "Senior", "Lead"
- "location": city and country if stated, or null''';

  Future<ResumeInsights> read(Uint8List pdfBytes, {required String fileName}) async {
    final text = await _extractText(pdfBytes);
    final reply = await ai.complete(
      AiRequest(
        system: _system,
        prompt: _prompt,
        pdfBytes: pdfBytes,
        pdfText: text,
        json: true,
      ),
    );

    final json = extractJson(reply.text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException("Couldn't understand the resume summary");
    }
    final insights = ResumeInsights.fromJson({
      ...json,
      'file_name': fileName,
      'uploaded_at': DateTime.now().toIso8601String(),
    });
    // Keep it compact for account metadata.
    return ResumeInsights(
      fileName: insights.fileName,
      uploadedAt: insights.uploadedAt,
      headline: _clip(insights.headline, 140),
      summary: _clip(insights.summary, 600),
      roles: insights.roles.take(5).toList(),
      skills: insights.skills.take(25).toList(),
      yearsOfExperience: insights.yearsOfExperience,
      seniority: insights.seniority,
      location: insights.location,
    );
  }

  /// Local text extraction, used by models that can't read PDFs. Returns
  /// null for scanned (image-only) PDFs.
  Future<String?> _extractText(Uint8List bytes) async {
    PdfDocument? document;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openData(Uint8List.fromList(bytes));
      final buffer = StringBuffer();
      for (final page in document.pages) {
        final text = await page.loadText();
        if (text != null) buffer.writeln(text.fullText);
        if (buffer.length > _maxTextLength) break;
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) return null;
      return text.length > _maxTextLength
          ? text.substring(0, _maxTextLength)
          : text;
    } catch (e) {
      debugPrint('Resume text extraction failed: $e');
      return null;
    } finally {
      await document?.dispose();
    }
  }

  static String? _clip(String? text, int max) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max - 1)}…';
  }
}
