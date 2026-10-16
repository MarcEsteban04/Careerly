import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/json_extract.dart';
import '../../studio/data/career_writer.dart';
import 'company_research.dart';

/// Researches employers with AI and a web search (Gemini, then Groq, then
/// OpenAI), and keeps each brief on the device for [maxAge] so reopening a
/// job doesn't spend AI quota again.
class CompanyResearcher {
  CompanyResearcher(this.ai, {SharedPreferencesAsync? prefs})
      : _injectedPrefs = prefs;

  final AiChain ai;
  final SharedPreferencesAsync? _injectedPrefs;
  late final _prefs = _injectedPrefs ?? SharedPreferencesAsync();

  static const maxAge = Duration(days: 30);

  bool get isConfigured => ai.isConfigured;

  static String _key(String company) =>
      'company_research.${company.trim().toLowerCase()}';

  /// The saved brief for [company], if there's a fresh one.
  Future<CompanyResearch?> cached(String company, {DateTime? now}) async {
    try {
      final raw = await _prefs.getString(_key(company));
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final research = CompanyResearch.fromStored(json);
      final age = (now ?? DateTime.now()).difference(research.createdAt);
      return age > maxAge || research.isEmpty ? null : research;
    } catch (e) {
      debugPrint('Company research cache unreadable: $e');
      return null;
    }
  }

  /// Looks the employer up and saves the brief.
  Future<CompanyResearch> research(JobContext job, {DateTime? now}) async {
    final description = job.description?.trim() ?? '';
    final reply = await ai.complete(
      AiRequest(
        json: true,
        webSearch: true,
        system: 'You research employers for job seekers in the Philippines. '
            'You are factual and careful: you only state what you found or '
            'can reasonably tell from the job post, and you say so when '
            'reliable information is thin. Never invent numbers, awards or '
            'reviews. Reply with JSON only.',
        prompt: '''
Research this employer for a candidate considering: ${job.label}.
${job.location == null ? '' : 'Location: ${job.location}\n'}${description.isEmpty ? '' : 'Job post:\n${description.length > 3000 ? description.substring(0, 3000) : description}\n'}
Search the web for ${job.company}: what they do, who they serve, size, headquarters, and recent news. Then judge the job post itself.

- "good_signs": things that look positive for a candidate (e.g. clear salary, established company, growth, good benefits).
- "watch_outs": red flags or things to verify (e.g. no web presence, vague duties, fees, unrealistic pay, poor reviews, recent layoffs). Be fair, not alarmist; if nothing stands out, give 1-2 sensible checks.
- If you can't find reliable information about the company, set "found" to false and say so in the summary.

Don't include citation markers or source numbers in the text.

Return JSON:
{
  "found": true,
  "summary": "<2-3 sentences: what they do and for whom>",
  "facts": ["<Label: short value, under 35 characters, e.g. Industry: Fintech>", "... up to 5: industry, size, headquarters city, founded, website"],
  "good_signs": ["<up to 4, short>"],
  "watch_outs": ["<up to 4, short>"],
  "questions_to_ask": ["<3-4 smart questions to ask them in the interview>"]
}''',
      ),
    );

    final json = extractJson(reply.text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('AI did not return company research');
    }
    final research = CompanyResearch.fromJson(
      json,
      company: job.company,
      provider: reply.provider,
      createdAt: now ?? DateTime.now(),
    );
    if (research.isEmpty) {
      throw const FormatException('AI returned no company research');
    }
    try {
      await _prefs.setString(_key(job.company), jsonEncode(research.toJson()));
    } catch (e) {
      // Still show it; it just won't be remembered.
      debugPrint('Company research not saved: $e');
    }
    return research;
  }
}
