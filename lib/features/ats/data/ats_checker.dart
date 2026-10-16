import '../../discover/data/skill_vocabulary.dart';
import '../../documents/data/document_markup.dart';
import '../../studio/data/career_writer.dart';

/// One part of an ATS score, e.g. "Keywords from the job".
class AtsCheck {
  const AtsCheck({
    required this.title,
    required this.points,
    required this.outOf,
    required this.detail,
    this.tip,
  });

  final String title;
  final int points;
  final int outOf;

  /// What was found.
  final String detail;

  /// How to earn the missing points; null when full marks.
  final String? tip;

  bool get passed => points >= outOf;
}

class AtsReport {
  const AtsReport({
    required this.score,
    required this.checks,
    required this.matchedKeywords,
    required this.missingKeywords,
    required this.hasJobDetails,
  });

  /// 0–100.
  final int score;
  final List<AtsCheck> checks;

  /// Skills and title words from the job that the resume includes.
  final List<String> matchedKeywords;
  final List<String> missingKeywords;

  /// False when the job has no description, so keywords come from the
  /// title alone.
  final bool hasJobDetails;

  String get verdict => score >= 80
      ? 'Strong. This resume should get past most screeners.'
      : score >= 60
          ? 'Good, with a few fixes that could lift it.'
          : 'Needs work before you send it to this job.';
}

/// Scores a resume against a job the way applicant-tracking systems read
/// it: keywords, the job title, standard sections, contact details,
/// measurable results and length. Runs on the device; no AI.
abstract final class AtsChecker {
  static const _sections = {
    'Summary': ['summary', 'profile', 'objective', 'about me'],
    'Experience': ['experience', 'employment', 'work history'],
    'Skills': ['skills', 'technical skills', 'competencies', 'tools'],
    'Education': ['education', 'academic'],
  };

  static const _actionVerbs = {
    'achieved', 'analyzed', 'automated', 'built', 'collaborated',
    'conducted', 'created', 'cut', 'debugged', 'delivered', 'deployed',
    'designed', 'developed', 'digitized', 'drove', 'engineered',
    'enhanced', 'established', 'handled', 'implemented', 'improved',
    'increased', 'integrated', 'launched', 'led', 'maintained', 'managed',
    'migrated', 'optimized', 'organized', 'owned', 'processed', 'reduced',
    'resolved', 'shipped', 'streamlined', 'supported', 'tested', 'trained',
    'wrote',
  };

  static const _titleStopWords = {
    'and', 'or', 'the', 'of', 'for', 'to', 'in', 'a', 'an', 'with', 'at',
    'senior', 'junior', 'jr', 'sr', 'lead', 'remote', 'hybrid', 'mid',
    'level', 'i', 'ii', 'iii', 'part', 'time', 'full', 'contract', 'urgent',
    'hiring',
  };

  static AtsReport check({required String resume, required JobContext job}) {
    final plain = markupToPlainText(resume);
    final text = plain.toLowerCase();
    final lines = resume.split('\n').map((l) => l.trim()).toList();
    final description = (job.description ?? '').toLowerCase();
    final hasJobDetails = description.trim().length > 80;

    // Keywords (40): skills the job asks for, plus its title words.
    final titleWords = [
      for (final word in job.title.toLowerCase().split(RegExp(r'[^a-z0-9+#.]+')))
        if (word.length > 1 && !_titleStopWords.contains(word)) word,
    ];
    final keywords = <String>{
      for (final skill in SkillVocabulary.skills)
        if (SkillVocabulary.mentions(description, skill)) skill,
    };
    final matched = <String>[];
    final missing = <String>[];
    for (final keyword in keywords) {
      (SkillVocabulary.mentions(text, keyword) ? matched : missing).add(keyword);
    }
    final keywordShare = keywords.isEmpty
        ? (hasJobDetails ? 0.8 : 0.5)
        : matched.length / keywords.length;
    final keywordPoints = (keywordShare * 40).round();

    // Job title (10).
    final titleHits = titleWords.where((w) => SkillVocabulary.mentions(text, w));
    final titleShare = titleWords.isEmpty
        ? 1.0
        : titleHits.length / titleWords.length;
    final titlePoints = titleShare >= 0.99
        ? 10
        : titleShare >= 0.5
            ? 6
            : 0;

    // Sections (15).
    final headings = [
      for (final line in lines)
        if (line.startsWith('#') ||
            (line.length < 40 && line == line.toUpperCase() && line.isNotEmpty))
          line.replaceAll('#', '').trim().toLowerCase(),
    ];
    final foundSections = [
      for (final MapEntry(:key, :value) in _sections.entries)
        if (headings.any((h) => value.any(h.contains))) key,
    ];
    final missingSections = [
      for (final name in _sections.keys)
        if (!foundSections.contains(name)) name,
    ];
    final sectionPoints = (foundSections.length / _sections.length * 15).round();

    // Contact details (10).
    final hasEmail = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(plain);
    final hasPhone =
        RegExp(r'(\+?63|0)\s?9\d{2}[\s-]?\d{3}[\s-]?\d{4}|\+?\d[\d\s()-]{8,}\d')
            .hasMatch(plain);
    final hasLink =
        RegExp(r'linkedin\.com|github\.com|https?://|\.vercel\.app|\.dev\b')
            .hasMatch(text);
    final contactPoints = (hasEmail ? 4 : 0) + (hasPhone ? 4 : 0) + (hasLink ? 2 : 0);

    // Impact (15): bullets with numbers, and bullets led by action verbs.
    final bullets = [
      for (final line in lines)
        if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* '))
          line.substring(2).trim(),
    ];
    final quantified =
        bullets.where((b) => RegExp(r'\d').hasMatch(b)).length;
    final actionLed = bullets.where((b) {
      final first = b.split(RegExp(r'\s+')).first.toLowerCase();
      return _actionVerbs.contains(first.replaceAll(RegExp(r'[^a-z]'), ''));
    }).length;
    final numberShare = bullets.isEmpty ? 0.0 : quantified / bullets.length;
    final verbShare = bullets.isEmpty ? 0.0 : actionLed / bullets.length;
    final numberPoints = (numberShare / 0.3).clamp(0, 1) * 8;
    final verbPoints = (verbShare / 0.6).clamp(0, 1) * 7;
    final impactPoints = (numberPoints + verbPoints).round();

    // Length (10): one to two pages.
    final words = plain.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lengthPoints = words >= 300 && words <= 900
        ? 10
        : (words >= 200 && words < 300) || (words > 900 && words <= 1200)
            ? 6
            : 2;

    final checks = [
      AtsCheck(
        title: 'Keywords from the job',
        points: keywordPoints,
        outOf: 40,
        detail: keywords.isEmpty
            ? hasJobDetails
                ? "The post doesn't name many specific skills."
                : 'No job description saved, so only the title was checked.'
            : 'Includes ${matched.length} of ${keywords.length} skills the '
                'post mentions.',
        tip: missing.isEmpty
            ? null
            : 'Add the ones you really have, in your skills and in a bullet '
                'that shows them in use.',
      ),
      AtsCheck(
        title: 'Job title',
        points: titlePoints,
        outOf: 10,
        detail: titlePoints == 10
            ? 'Uses the title “${job.title}”.'
            : titlePoints > 0
                ? 'Uses part of the title “${job.title}”.'
                : "Doesn't use the title “${job.title}”.",
        tip: titlePoints == 10
            ? null
            : 'Put “${job.title}” (or the closest true title) in your headline '
                'or summary. Screeners search for it.',
      ),
      AtsCheck(
        title: 'Standard sections',
        points: sectionPoints,
        outOf: 15,
        detail: missingSections.isEmpty
            ? 'Has Summary, Experience, Skills and Education.'
            : 'Missing: ${missingSections.join(', ')}.',
        tip: missingSections.isEmpty
            ? null
            : 'Use plain headings like "Experience" and "Skills" so systems '
                'can find each part.',
      ),
      AtsCheck(
        title: 'Contact details',
        points: contactPoints,
        outOf: 10,
        detail: [
          hasEmail ? 'email ✓' : 'no email',
          hasPhone ? 'phone ✓' : 'no phone',
          hasLink ? 'link ✓' : 'no LinkedIn or portfolio',
        ].join(' · '),
        tip: contactPoints == 10
            ? null
            : 'Put your email, mobile number and a LinkedIn or portfolio link '
                'at the top.',
      ),
      AtsCheck(
        title: 'Measurable results',
        points: impactPoints,
        outOf: 15,
        detail: bullets.isEmpty
            ? 'No bullet points found.'
            : '$quantified of ${bullets.length} bullets have numbers; '
                '$actionLed start with a strong verb.',
        tip: impactPoints >= 15
            ? null
            : 'Start bullets with verbs like "Built" or "Improved" and add '
                'numbers where they\'re true: %, time saved, users, tickets.',
      ),
      AtsCheck(
        title: 'Length',
        points: lengthPoints,
        outOf: 10,
        detail: '$words words.',
        tip: lengthPoints == 10
            ? null
            : words < 300
                ? 'A bit short. Add detail to your most relevant roles and '
                    'projects.'
                : 'A bit long. Trim older or less relevant points to stay '
                    'within two pages.',
      ),
    ];

    return AtsReport(
      score: checks.fold(0, (sum, c) => sum + c.points).clamp(0, 100),
      checks: checks,
      matchedKeywords: matched,
      missingKeywords: missing,
      hasJobDetails: hasJobDetails,
    );
  }
}
