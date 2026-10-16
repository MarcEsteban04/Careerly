import '../../profile/data/career_profile.dart';
import 'job_listing.dart';
import 'skill_vocabulary.dart';

/// How well a job's work setup fits what the profile wants.
enum SetupFit { good, okay, poor }

class JobMatch {
  const JobMatch({
    required this.score,
    required this.reasons,
    this.bestRole,
    this.rolePoints = 0,
    this.skillPoints = 0,
    this.setupPoints = 0,
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.setupFit = SetupFit.okay,
    this.setupNote,
    this.yearsAsked,
  });

  /// 0–100: [rolePoints] + [skillPoints] + [setupPoints].
  final int score;

  /// Short, human-readable reasons, best first.
  final List<String> reasons;

  /// The target role the job title fits best, if any fits.
  final String? bestRole;

  /// Out of [JobMatcher.roleWeight].
  final int rolePoints;

  /// Out of [JobMatcher.skillsWeight].
  final int skillPoints;

  /// Out of [JobMatcher.setupWeight].
  final int setupPoints;

  /// Profile skills the post mentions.
  final List<String> matchedSkills;

  /// Skills the post mentions that aren't on the profile.
  final List<String> missingSkills;

  final SetupFit setupFit;

  /// e.g. "Remote, as you prefer".
  final String? setupNote;

  /// Years of experience the post asks for, when it says.
  final int? yearsAsked;
}

/// Scores how well a job fits the career profile, from the role title,
/// skills mentioned in the posting, and work setup.
abstract final class JobMatcher {
  static const roleWeight = 45;
  static const skillsWeight = 35;
  static const setupWeight = 20;

  static JobMatch? match(JobListing job, CareerProfile profile) {
    if (profile.isEmpty) return null;
    final reasons = <String>[];

    // Title: best overlap between a target role's words and the job title.
    final titleWords = _words(job.title);
    var titleScore = 0.0;
    String? bestRole;
    for (final role in profile.effectiveRoles) {
      final roleWords = _words(role);
      if (roleWords.isEmpty) continue;
      final overlap = roleWords.where(titleWords.contains).length / roleWords.length;
      if (overlap > titleScore) {
        titleScore = overlap;
        bestRole = role;
      }
    }
    if (bestRole != null && titleScore >= 0.5) reasons.add('Fits “$bestRole”');

    // Skills mentioned anywhere in the posting.
    final text = job.searchableText;
    final matchedSkills = [
      for (final skill in profile.effectiveSkills)
        if (_mentions(text, skill)) skill,
    ];
    final skillsScore = profile.effectiveSkills.isEmpty
        ? 0.5
        : (matchedSkills.length / profile.effectiveSkills.length.clamp(1, 5))
            .clamp(0, 1);
    if (matchedSkills.isNotEmpty) {
      final shown = matchedSkills.take(3).join(', ');
      reasons.add(
        matchedSkills.length > 3
            ? 'Mentions $shown +${matchedSkills.length - 3}'
            : 'Mentions $shown',
      );
    }

    // Skills the post asks for that the profile doesn't list.
    final have = [
      for (final skill in profile.effectiveSkills)
        SkillVocabulary.normalize(skill),
    ];
    // "MS Excel" covers "Excel"; "Google Workspace" covers "Workspace".
    bool hasSkill(String skill) {
      final key = SkillVocabulary.normalize(skill);
      return have.any((h) => h == key || h.contains(key) || key.contains(h));
    }

    final missingSkills = [
      for (final skill in SkillVocabulary.skills)
        if (!hasSkill(skill) && _mentions(text, skill)) skill,
    ].take(8).toList();

    // Work setup. Boards don't always flag remote jobs, so the wording
    // counts too.
    final nearby = _isNearby(job, profile);
    final remote = looksRemote(job);
    final (setupScore, setupFit, setupNote) = switch (profile.workSetup) {
      WorkSetup.remote => remote
          ? (1.0, SetupFit.good, 'Remote, as you prefer')
          : (0.2, SetupFit.poor, "On-site, but you'd like remote"),
      WorkSetup.onsite => nearby
          ? (1.0, SetupFit.good, 'Near ${profile.effectiveLocation}')
          : (0.5, SetupFit.okay, 'Not near ${profile.effectiveLocation ?? 'you'}'),
      WorkSetup.any => (
          0.8,
          SetupFit.good,
          remote ? 'Remote' : 'On-site, and you\'re open to both',
        ),
    };
    if (profile.workSetup == WorkSetup.remote && remote) {
      reasons.add('Remote');
    } else if (profile.workSetup == WorkSetup.onsite && nearby) {
      reasons.add('Near ${profile.effectiveLocation}');
    }

    final rolePoints = (titleScore * roleWeight).round();
    final skillPoints = (skillsScore * skillsWeight).round();
    final setupPoints = (setupScore * setupWeight).round();
    return JobMatch(
      score: (rolePoints + skillPoints + setupPoints).clamp(0, 100),
      reasons: reasons,
      bestRole: titleScore > 0 ? bestRole : null,
      rolePoints: rolePoints,
      skillPoints: skillPoints,
      setupPoints: setupPoints,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      setupFit: setupFit,
      setupNote: setupNote,
      yearsAsked: yearsAsked(text),
    );
  }

  /// The fewest years of experience the post asks for, e.g. "3+ years of
  /// experience" or "2-4 years experience".
  static int? yearsAsked(String text) {
    final matches = RegExp(
      r'(\d{1,2})\s*(?:\+|plus)?\s*(?:(?:-|–|to)\s*\d{1,2}\s*)?\+?\s*'
      r'(?:years?|yrs?)(?:\s+of)?(?:\s+[a-z/&-]+){0,3}?\s+experience',
    ).allMatches(text.toLowerCase());
    int? fewest;
    for (final match in matches) {
      final years = int.parse(match.group(1)!);
      if (years > 0 && years <= 20 && (fewest == null || years < fewest)) {
        fewest = years;
      }
    }
    return fewest;
  }

  /// Remote by the board's flag, or by the post's own words ("Remote" in
  /// the title, "work from home", "fully remote", "remote basis"…).
  static bool looksRemote(JobListing job) {
    if (job.isRemote) return true;
    if (RegExp(r'\bremote\b', caseSensitive: false).hasMatch(job.title)) {
      return true;
    }
    return RegExp(
      r'\b(fully remote|100% remote|remote (basis|position|role|work|setup|'
      r'job|opportunity|first)|work from home|work-from-home|wfh)\b',
    ).hasMatch(job.searchableText);
  }

  static bool _isNearby(JobListing job, CareerProfile profile) {
    final city = profile.effectiveLocation?.toLowerCase().trim();
    if (city == null || city.isEmpty) return false;
    return (job.location ?? '').toLowerCase().contains(city);
  }

  /// Whether [text] mentions [skill] as a whole word, allowing for the
  /// usual JavaScript spellings: "React" also matches "ReactJS" and
  /// "React.js"; "Nextjs" also matches "Next.js".
  static bool _mentions(String text, String skill) {
    final needle = skill.toLowerCase().trim();
    if (needle.isEmpty) return false;
    final base = needle.endsWith('.js')
        ? needle.substring(0, needle.length - 3)
        : needle.endsWith('js') && needle.length > 4
            ? needle.substring(0, needle.length - 2)
            : needle;
    final spellings = {needle, '${base}js', '$base.js'};
    // Whole-word match so "Go" doesn't match "Google".
    return spellings.any(
      (s) => RegExp('(^|[^a-z0-9+#])${RegExp.escape(s)}(\$|[^a-z0-9+#])')
          .hasMatch(text),
    );
  }

  static Set<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9+#]+'))
      .where((w) => w.length > 1 && !_stopWords.contains(w))
      .toSet();

  static const _stopWords = {
    'and', 'or', 'the', 'of', 'for', 'to', 'in', 'a', 'an', 'with', 'at',
    'senior', 'junior', 'jr', 'sr', 'lead', 'remote', 'hybrid', 'mid',
  };
}
