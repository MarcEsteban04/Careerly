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

  static ApplicationStatus fromName(String? name) => values.firstWhere(
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
    this.source,
    this.externalId,
    this.jobDescription,
    this.followUpOn,
    this.resumeDocumentId,
    this.coverLetterDocumentId,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
        id: json['id'] as String,
        company: json['company'] as String,
        role: json['role'] as String,
        status: ApplicationStatus.fromName(json['status'] as String?),
        location: json['location'] as String?,
        jobUrl: json['job_url'] as String?,
        salary: json['salary'] as String?,
        notes: json['notes'] as String?,
        appliedOn: _date(json['applied_on']),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        source: json['source'] as String?,
        externalId: json['external_id'] as String?,
        jobDescription: json['job_description'] as String?,
        followUpOn: _date(json['follow_up_on']),
        resumeDocumentId: json['resume_document_id'] as String?,
        coverLetterDocumentId: json['cover_letter_document_id'] as String?,
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

  /// Job board it came from, e.g. "LinkedIn".
  final String? source;

  /// Listing id from job discovery, to recognize the same posting later.
  final String? externalId;

  /// The posting's text, kept for tailoring documents.
  final String? jobDescription;
  final DateTime? followUpOn;

  /// Documents sent with the application.
  final String? resumeDocumentId;
  final String? coverLetterDocumentId;

  bool get isApplied => status != ApplicationStatus.saved;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
