import '../../resume/data/resume_insights.dart';

enum WorkSetup {
  remote('Remote'),
  onsite('On-site'),
  any('Open to both');

  const WorkSetup(this.label);

  final String label;

  static WorkSetup fromName(String? name) => values.firstWhere(
        (setup) => setup.name == name,
        orElse: () => WorkSetup.any,
      );
}

/// What the user is looking for, plus what their resume says. Drives job
/// search suggestions and match scores.
class CareerProfile {
  const CareerProfile({
    this.targetRoles = const [],
    this.skills = const [],
    this.yearsOfExperience,
    this.location,
    this.workSetup = WorkSetup.any,
    this.resume,
  });

  factory CareerProfile.fromJson(Map<String, dynamic> json) {
    final resume = json['resume'];
    return CareerProfile(
      targetRoles: _strings(json['target_roles']),
      skills: _strings(json['skills']),
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      location: json['location'] as String?,
      workSetup: WorkSetup.fromName(json['work_setup'] as String?),
      resume: resume is Map<String, dynamic>
          ? ResumeInsights.fromJson(resume)
          : null,
    );
  }

  final List<String> targetRoles;
  final List<String> skills;
  final int? yearsOfExperience;

  /// City or region, e.g. "Manila".
  final String? location;
  final WorkSetup workSetup;
  final ResumeInsights? resume;

  bool get isEmpty => effectiveRoles.isEmpty && effectiveSkills.isEmpty;

  /// Roles the user chose, then ones suggested by the resume.
  List<String> get effectiveRoles =>
      _merge(targetRoles, resume?.roles ?? const []);

  /// Skills the user listed, then ones found in the resume.
  List<String> get effectiveSkills =>
      _merge(skills, resume?.skills ?? const []);

  int? get effectiveYears => yearsOfExperience ?? resume?.yearsOfExperience;

  String? get effectiveLocation => location ?? resume?.location;

  CareerProfile copyWith({
    List<String>? targetRoles,
    List<String>? skills,
    int? yearsOfExperience,
    String? location,
    WorkSetup? workSetup,
    ResumeInsights? resume,
    bool clearResume = false,
  }) =>
      CareerProfile(
        targetRoles: targetRoles ?? this.targetRoles,
        skills: skills ?? this.skills,
        yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
        location: location ?? this.location,
        workSetup: workSetup ?? this.workSetup,
        resume: clearResume ? null : resume ?? this.resume,
      );

  Map<String, dynamic> toJson() => {
        'target_roles': targetRoles,
        'skills': skills,
        'years_of_experience': yearsOfExperience,
        'location': location,
        'work_setup': workSetup.name,
        'resume': resume?.toJson(),
      };

  /// Stable fingerprint, used to know when AI rankings are out of date.
  String get fingerprint => [
        effectiveRoles.join(','),
        effectiveSkills.join(','),
        effectiveYears,
        effectiveLocation,
        workSetup.name,
        resume?.uploadedAt.toIso8601String(),
      ].join('|').toLowerCase();

  static List<String> _merge(List<String> first, List<String> second) {
    final seen = <String>{};
    return [
      for (final item in [...first, ...second])
        if (seen.add(item.toLowerCase().trim())) item,
    ];
  }

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
      : const [];
}
