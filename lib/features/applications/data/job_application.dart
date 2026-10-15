enum ApplicationStatus {
  saved('Saved'),
  applied('Applied'),
  interviewing('Interviewing', shortLabel: 'Interview'),
  offer('Offer'),
  rejected('Rejected');

  const ApplicationStatus(this.label, {String? shortLabel})
      : shortLabel = shortLabel ?? label;

  final String label;

  /// For tight spaces such as the pipeline columns.
  final String shortLabel;

  static ApplicationStatus fromName(String name) => values.firstWhere(
        (status) => status.name == name,
        orElse: () => ApplicationStatus.saved,
      );
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.company,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.jobUrl,
    this.salary,
    this.notes,
    this.appliedOn,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
        id: json['id'] as String,
        company: json['company'] as String,
        role: json['role'] as String,
        status: ApplicationStatus.fromName(json['status'] as String),
        location: json['location'] as String?,
        jobUrl: json['job_url'] as String?,
        salary: json['salary'] as String?,
        notes: json['notes'] as String?,
        appliedOn: json['applied_on'] == null
            ? null
            : DateTime.parse(json['applied_on'] as String),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  final String id;
  final String company;
  final String role;
  final ApplicationStatus status;
  final String? location;
  final String? jobUrl;
  final String? salary;
  final String? notes;

  /// Calendar date the application was sent (no time component).
  final DateTime? appliedOn;
  final DateTime createdAt;
  final DateTime updatedAt;
}
