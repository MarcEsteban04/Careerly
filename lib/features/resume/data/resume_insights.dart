/// What AI pulled out of an uploaded resume. Kept compact because it lives
/// in the user's account metadata.
class ResumeInsights {
  const ResumeInsights({
    required this.fileName,
    required this.uploadedAt,
    this.headline,
    this.summary,
    this.roles = const [],
    this.skills = const [],
    this.yearsOfExperience,
    this.seniority,
    this.location,
  });

  factory ResumeInsights.fromJson(Map<String, dynamic> json) => ResumeInsights(
        fileName: json['file_name'] as String? ?? 'Resume.pdf',
        uploadedAt: DateTime.tryParse(json['uploaded_at'] as String? ?? '') ??
            DateTime.now(),
        headline: json['headline'] as String?,
        summary: json['summary'] as String?,
        roles: _strings(json['roles']),
        skills: _strings(json['skills']),
        yearsOfExperience: (json['years_of_experience'] as num?)?.round(),
        seniority: json['seniority'] as String?,
        location: json['location'] as String?,
      );

  final String fileName;
  final DateTime uploadedAt;

  /// e.g. "UI/UX designer with 4 years in fintech".
  final String? headline;

  /// A few sentences on experience and strengths.
  final String? summary;

  /// Job titles the resume fits, best first.
  final List<String> roles;
  final List<String> skills;
  final int? yearsOfExperience;

  /// e.g. "Junior", "Mid-level", "Senior".
  final String? seniority;
  final String? location;

  Map<String, dynamic> toJson() => {
        'file_name': fileName,
        'uploaded_at': uploadedAt.toIso8601String(),
        'headline': headline,
        'summary': summary,
        'roles': roles,
        'skills': skills,
        'years_of_experience': yearsOfExperience,
        'seniority': seniority,
        'location': location,
      };

  static List<String> _strings(Object? value) => value is List
      ? value
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList()
      : const [];
}
