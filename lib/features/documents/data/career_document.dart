enum DocumentKind {
  resume('Resume'),
  coverLetter('Cover letter');

  const DocumentKind(this.label);

  final String label;

  String get dbValue => this == coverLetter ? 'cover_letter' : 'resume';

  static DocumentKind fromDbValue(String value) =>
      value == 'cover_letter' ? coverLetter : resume;
}

/// A resume or cover letter. Content is light Markdown: `# name`,
/// `## section`, `- bullet` and `**bold**`.
class CareerDocument {
  const CareerDocument({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.createdAt,
    this.applicationId,
  });

  factory CareerDocument.fromJson(Map<String, dynamic> json) => CareerDocument(
        id: json['id'] as String,
        kind: DocumentKind.fromDbValue(json['kind'] as String),
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        applicationId: json['application_id'] as String?,
      );

  /// Title prefix for the text of the uploaded resume, kept as the source
  /// for enhancements and cover letters.
  static const originalResumePrefix = 'Original resume';

  final String id;
  final DocumentKind kind;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? applicationId;

  bool get isOriginalResume =>
      kind == DocumentKind.resume && title.startsWith(originalResumePrefix);

  CareerDocument copyWith({String? title, String? content}) => CareerDocument(
        id: id,
        kind: kind,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        applicationId: applicationId,
      );
}
