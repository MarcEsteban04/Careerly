/// A job posting from an external job board, normalized across sources.
class JobListing {
  const JobListing({
    required this.id,
    required this.title,
    required this.company,
    required this.source,
    required this.applyUrl,
    this.companyLogoUrl,
    this.location,
    this.isRemote = false,
    this.employmentType,
    this.salary,
    this.postedAt,
    this.postedLabel,
    this.description = '',
    this.qualifications = const [],
    this.responsibilities = const [],
    this.benefits = const [],
    this.foundByAi,
  });

  final String id;
  final String title;
  final String company;

  /// Where it was published, e.g. "LinkedIn" or "Indeed".
  final String source;
  final String applyUrl;
  final String? companyLogoUrl;
  final String? location;
  final bool isRemote;

  /// e.g. "Full-time".
  final String? employmentType;

  /// Display string, e.g. "₱40K–60K/month".
  final String? salary;
  final DateTime? postedAt;

  /// Source-provided age, e.g. "4 days ago", used when [postedAt] is unknown.
  final String? postedLabel;
  final String description;
  final List<String> qualifications;
  final List<String> responsibilities;
  final List<String> benefits;

  /// Set when the job came from AI web search (the provider name), which is
  /// only used when the job APIs are unavailable.
  final String? foundByAi;

  /// Key for spotting the same job from two sources.
  String get dedupeKey =>
      '${title.toLowerCase().trim()}|${company.toLowerCase().trim()}';

  /// All text that can mention skills, for matching.
  String get searchableText => [
        title,
        description,
        ...qualifications,
        ...responsibilities,
      ].join('\n').toLowerCase();
}
