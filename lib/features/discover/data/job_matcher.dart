import '../../profile/data/career_profile.dart';
import 'job_listing.dart';

class JobMatch {
  const JobMatch({required this.score, required this.reasons});

  /// 0–100.
  final int score;

  /// Short, human-readable reasons, best first.
  final List<String> reasons;
}

/// Scores how well a job fits the career profile, from the role title,
/// skills mentioned in the posting, and work setup.
abstract final class JobMatcher {
  static const _titleWeight = 45;
  static const _skillsWeight = 35;
  static const _setupWeight = 20;

  static JobMatch? match(JobListing job, CareerProfile profile) {
    if (profile.isEmpty) return null;
    final reasons = <String>[];

    // Title: best overlap between a target role's words and the job title.
    final titleWords = _words(job.title);
    var titleScore = 0.0;
    String? bestRole;
    for (final role in profile.targetRoles) {
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
      for (final skill in profile.skills)
        if (_mentions(text, skill)) skill,
    ];
    final skillsScore = profile.skills.isEmpty
        ? 0.5
        : (matchedSkills.length / profile.skills.length.clamp(1, 5)).clamp(0, 1);
    if (matchedSkills.isNotEmpty) {
      final shown = matchedSkills.take(3).join(', ');
      reasons.add(
        matchedSkills.length > 3
            ? 'Mentions $shown +${matchedSkills.length - 3}'
            : 'Mentions $shown',
      );
    }

    // Work setup.
    final setupScore = switch (profile.workSetup) {
      WorkSetup.remote => job.isRemote ? 1.0 : 0.2,
      WorkSetup.onsite => _isNearby(job, profile) ? 1.0 : 0.5,
      WorkSetup.any => 0.8,
    };
    if (profile.workSetup == WorkSetup.remote && job.isRemote) {
      reasons.add('Remote');
    } else if (profile.workSetup == WorkSetup.onsite && _isNearby(job, profile)) {
      reasons.add('Near ${profile.location}');
    }

    final score = (titleScore * _titleWeight +
            skillsScore * _skillsWeight +
            setupScore * _setupWeight)
        .round()
        .clamp(0, 100);
    return JobMatch(score: score, reasons: reasons);
  }

  static bool _isNearby(JobListing job, CareerProfile profile) {
    final city = profile.location?.toLowerCase().trim();
    if (city == null || city.isEmpty) return false;
    return (job.location ?? '').toLowerCase().contains(city);
  }

  static bool _mentions(String text, String skill) {
    final needle = skill.toLowerCase().trim();
    if (needle.isEmpty) return false;
    // Whole-word match so "Go" doesn't match "Google".
    return RegExp('(^|[^a-z0-9+#])${RegExp.escape(needle)}(\$|[^a-z0-9+#])')
        .hasMatch(text);
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
