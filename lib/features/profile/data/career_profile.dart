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

/// What the user is looking for; drives job search defaults and match scores.
class CareerProfile {
  const CareerProfile({
    this.targetRoles = const [],
    this.skills = const [],
    this.yearsOfExperience,
    this.location,
    this.workSetup = WorkSetup.any,
  });

  factory CareerProfile.fromJson(Map<String, dynamic> json) => CareerProfile(
        targetRoles: _strings(json['target_roles']),
        skills: _strings(json['skills']),
        yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
        location: json['location'] as String?,
        workSetup: WorkSetup.fromName(json['work_setup'] as String?),
      );

  final List<String> targetRoles;
  final List<String> skills;
  final int? yearsOfExperience;

  /// City or region, e.g. "Manila".
  final String? location;
  final WorkSetup workSetup;

  bool get isEmpty => targetRoles.isEmpty && skills.isEmpty;

  Map<String, dynamic> toJson() => {
        'target_roles': targetRoles,
        'skills': skills,
        'years_of_experience': yearsOfExperience,
        'location': location,
        'work_setup': workSetup.name,
      };

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
      : const [];
}
