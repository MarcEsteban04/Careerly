import 'dart:convert';

import '../../../core/ai/ai_chain.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/citations.dart';
import '../../../core/ai/json_extract.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import 'answer_library.dart';
import 'applicant_details.dart';
import 'form_field_info.dart';

/// Who is applying: identity, saved details, profile and resume.
class Applicant {
  const Applicant({
    required this.name,
    required this.email,
    required this.details,
    required this.profile,
    this.resumeText,
  });

  final String? name;
  final String? email;
  final ApplicantDetails details;
  final CareerProfile profile;
  final String? resumeText;

  /// Splits "Princess Mae D. Elfa" into first, middle initial and last.
  ({String first, String middle, String last}) get nameParts {
    final words = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return (first: '', middle: '', last: '');
    if (words.length == 1) return (first: words.first, middle: '', last: '');
    final last = words.removeLast();
    final middle = words.length > 1 && words.last.replaceAll('.', '').length <= 2
        ? words.removeLast()
        : '';
    return (first: words.join(' '), middle: middle, last: last);
  }
}

/// Proposes answers for an application form: obvious fields straight from
/// the applicant's details, then answers she approved before, the rest
/// drafted by AI (Gemini, then Groq, then
/// OpenAI) from her resume and the job. Nothing is invented: unknown
/// fields are left for her.
class FormFiller {
  FormFiller(this.ai);

  final AiChain ai;

  bool get isConfigured => ai.isConfigured;

  /// Fields sent to AI at most, to keep requests small.
  static const maxAiFields = 40;

  Future<List<FieldAnswer>> answer({
    required List<FormFieldInfo> fields,
    required Applicant applicant,
    required JobContext job,
    String? companyBrief,
    List<SavedAnswer> saved = const [],
  }) async {
    final answers = <FieldAnswer>[];
    final open = <FormFieldInfo>[];
    for (final field in fields) {
      // Leave anything she has already typed alone.
      if (field.currentValue.isNotEmpty && !field.kind.hasOptions) continue;
      final value = matchFromDetails(field, applicant);
      if (value != null) {
        answers.add(
          FieldAnswer(field: field, value: value, source: AnswerSource.details),
        );
      } else if (field.label.isNotEmpty || field.placeholder.isNotEmpty) {
        // An answer she approved before beats a fresh AI draft.
        final previous =
            AnswerLibrary.match(field, saved, company: job.company);
        if (previous == null) {
          open.add(field);
        } else {
          answers.add(
            FieldAnswer(
              field: field,
              value: field.kind.hasOptions
                  ? field.optionFor(previous.answer)!
                  : previous.answer,
              source: AnswerSource.library,
            ),
          );
        }
      }
    }
    if (open.isNotEmpty && ai.isConfigured) {
      answers.addAll(
        await _draft(open.take(maxAiFields).toList(), applicant, job, companyBrief),
      );
    }
    // Keep the page's order.
    final order = {for (final (i, f) in fields.indexed) f.id: i};
    answers.sort((a, b) => order[a.field.id]!.compareTo(order[b.field.id]!));
    return answers;
  }

  /// The value for [field] from her details alone, or null when it needs
  /// judgment (or isn't something she has saved).
  static String? matchFromDetails(FormFieldInfo field, Applicant applicant) {
    final value = _rawMatch(field, applicant);
    if (value == null || value.trim().isEmpty) return null;
    if (field.kind.hasOptions) return field.optionFor(value);
    if (field.kind == FormFieldKind.date) {
      final date = DateTime.tryParse(value.trim());
      return date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';
    }
    return value.trim();
  }

  static String? _rawMatch(FormFieldInfo field, Applicant applicant) {
    final d = applicant.details;
    final names = applicant.nameParts;
    final auto = field.autocomplete;
    final h = field.hints;
    bool has(List<String> words) => words.any(h.contains);

    // The browser's own autocomplete hints are the most reliable.
    switch (auto) {
      case 'email':
        return applicant.email;
      case 'tel' || 'tel-national' || 'mobile':
        return d.phone;
      case 'given-name':
        return names.first;
      case 'family-name':
        return names.last;
      case 'additional-name':
        return names.middle;
      case 'name':
        return applicant.name;
      case 'street-address' || 'address-line1':
        return d.address;
      case 'address-level2':
        return d.city;
      case 'bday':
        return d.birthday;
    }

    if (field.kind == FormFieldKind.email || has(['email', 'e-mail'])) {
      return applicant.email;
    }
    if (field.kind == FormFieldKind.tel ||
        has(['phone', 'mobile', 'contact number', 'cellphone'])) {
      return d.phone;
    }
    if (has(['linkedin'])) return d.linkedin;
    if (has(['github'])) return d.github;
    if (has(['portfolio', 'personal website', 'website', 'personal site'])) {
      return d.portfolio;
    }
    if (has(['first name', 'firstname', 'first_name', 'given name'])) {
      return names.first;
    }
    if (has(['last name', 'lastname', 'last_name', 'surname', 'family name'])) {
      return names.last;
    }
    if (has(['middle name', 'middle initial', 'middlename'])) {
      return names.middle;
    }
    if (has(['full name', 'fullname', 'your name', 'complete name']) ||
        _isPersonName(field.label.toLowerCase())) {
      return applicant.name;
    }
    if (has(['birth', 'birthday', 'bday', 'dob'])) return d.birthday;
    if (has(['city', 'municipality'])) {
      return d.city ?? applicant.profile.effectiveLocation;
    }
    if (has(['address'])) return d.address;
    if (has(['expected salary', 'salary expectation', 'desired salary', 'expected pay'])) {
      return d.expectedSalary;
    }
    if (has(['start date', 'availability', 'available to start', 'notice period'])) {
      return d.availability;
    }
    if (has(['school', 'university', 'college'])) return d.school;
    if (has(['degree', 'course', 'major'])) return d.degree;
    if (has(['graduation', 'year graduated'])) return d.graduationYear;
    if (has(['years of experience', 'years experience'])) {
      final years = applicant.profile.effectiveYears;
      return years?.toString();
    }
    return null;
  }

  /// "Name", "Applicant name" or "Candidate name", but not someone or
  /// something else's name.
  static bool _isPersonName(String label) =>
      RegExp(r'^(?:[a-z]+ )?name$').hasMatch(label) &&
      !RegExp(r'company|school|user|file|reference|emergency|contact person|'
              r'manager|employer|project|nick')
          .hasMatch(label);

  Future<List<FieldAnswer>> _draft(
    List<FormFieldInfo> fields,
    Applicant applicant,
    JobContext job,
    String? companyBrief,
  ) async {
    final resume = applicant.resumeText?.trim() ?? '';
    final profile = applicant.profile;
    final described = [
      for (final f in fields)
        {
          'id': f.id,
          'question': f.displayLabel,
          'type': f.kind.name,
          if (f.options.isNotEmpty) 'options': f.options.take(30).toList(),
          if (f.maxLength != null) 'max_length': f.maxLength,
          if (f.required) 'required': true,
        },
    ];
    final about = [
      if (applicant.name != null) 'Name: ${applicant.name}',
      if (applicant.email != null) 'Email: ${applicant.email}',
      ...applicant.details.lines,
      if (profile.effectiveRoles.isNotEmpty)
        'Target roles: ${profile.effectiveRoles.take(3).join(', ')}',
      if (profile.effectiveYears != null)
        'Years of experience: ${profile.effectiveYears}',
      if (profile.effectiveLocation != null) 'Based in: ${profile.effectiveLocation}',
      'Preferred work setup: ${profile.workSetup.label}',
    ].join('\n');
    final description = job.description?.trim() ?? '';

    final reply = await ai.complete(
      AiRequest(
        json: true,
        system: 'You fill in job application forms for a candidate in the '
            'Philippines, in their voice. Use only the facts given about '
            'them; never invent employers, dates, numbers, IDs or personal '
            'details. When a question needs information you do not have, '
            'or is a legal declaration or consent, leave it empty. Reply '
            'with JSON only.',
        prompt: '''
Fill in this application form for ${job.label}.
${description.isEmpty ? '' : 'Job post:\n${description.length > 2500 ? description.substring(0, 2500) : description}\n'}${companyBrief == null || companyBrief.trim().isEmpty ? '' : 'About the company: ${companyBrief.trim()}\n'}
ABOUT THE CANDIDATE
$about
${resume.isEmpty ? '' : '\nRESUME\n${resume.length > 6000 ? resume.substring(0, 6000) : resume}\n'}
FORM FIELDS (JSON)
${jsonEncode(described)}

Rules:
- For select and radio fields, the value must be exactly one of the options, or empty.
- Long-answer questions (textarea): first person, specific to this job, 60-150 words, within max_length.
- Short text: just the value, no extra words.
- Leave empty anything you can't answer from the facts above (e.g. government ID numbers, references, previous salary).

Return JSON: {"answers": [{"id": "<field id>", "value": "<answer or empty>"}]}''',
      ),
    );

    final json = extractJson(reply.text);
    final list = json is Map<String, dynamic> ? json['answers'] : json;
    if (list is! List) {
      throw const FormatException('AI did not return form answers');
    }
    final byId = {for (final f in fields) f.id: f};
    final answers = <FieldAnswer>[];
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final field = byId[item['id']];
      final raw = item['value'];
      if (field == null || raw is! String) continue;
      var value = stripCitations(raw);
      if (field.kind.hasOptions) value = field.optionFor(value) ?? '';
      if (field.maxLength != null && value.length > field.maxLength!) {
        value = value.substring(0, field.maxLength!);
      }
      if (value.isEmpty) continue;
      answers.add(FieldAnswer(field: field, value: value, source: AnswerSource.ai));
    }
    return answers;
  }
}
