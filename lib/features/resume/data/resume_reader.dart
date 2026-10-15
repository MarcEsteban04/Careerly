import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import 'resume_insights.dart';

/// The result of reading a resume.
class ResumeRead {
  const ResumeRead(this.insights, this.text);

  final ResumeInsights insights;

  /// Full plain text, or null if it couldn't be recovered.
  final String? text;
}

/// Reads a resume PDF with AI and returns its key facts and text.
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

  /// Reads the resume: its key facts, plus its full text (extracted locally,
  /// or transcribed by AI for scanned PDFs) for later enhancement.
  Future<ResumeRead> read(Uint8List pdfBytes, {required String fileName}) async {
    final extracted = await _extractText(pdfBytes);
    final insights = await _readInsights(pdfBytes, extracted, fileName);
    final text = extracted ?? await _transcribe(pdfBytes);
    return ResumeRead(insights, text);
  }

  Future<String?> _transcribe(Uint8List pdfBytes) async {
    try {
      final reply = await ai.complete(
        AiRequest(
          system: 'You transcribe documents faithfully.',
          prompt: 'Transcribe this resume as plain text, keeping its sections '
              'and bullet points. Output only the transcription.',
          pdfBytes: pdfBytes,
        ),
      );
      final text = reply.text.trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('Resume transcription failed: $e');
      return null;
    }
  }

  Future<ResumeInsights> _readInsights(
    Uint8List pdfBytes,
    String? text,
    String fileName,
  ) async {
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
