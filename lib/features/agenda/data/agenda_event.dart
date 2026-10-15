enum AgendaEventKind {
  interview('Interview'),
  followUp('Follow-up'),
  deadline('Deadline'),
  other('Reminder');

  const AgendaEventKind(this.label);

  final String label;

  /// Value stored in the `kind` column.
  String get dbValue => this == followUp ? 'follow_up' : name;

  static AgendaEventKind fromDbValue(String value) => values.firstWhere(
        (kind) => kind.dbValue == value,
        orElse: () => AgendaEventKind.other,
      );
}

/// An interview, follow-up, deadline or other reminder.
class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    this.isDone = false,
    this.applicationId,
    this.company,
  });

  factory AgendaEvent.fromJson(Map<String, dynamic> json) {
    final application = json['application'] as Map<String, dynamic>?;
    return AgendaEvent(
      id: json['id'] as String,
      kind: AgendaEventKind.fromDbValue(json['kind'] as String),
      title: json['title'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      isDone: json['is_done'] as bool? ?? false,
      applicationId: json['application_id'] as String?,
      company: application?['company'] as String?,
    );
  }

  final String id;
  final AgendaEventKind kind;
  final String title;
  final DateTime startsAt;
  final bool isDone;
  final String? applicationId;

  /// Company of the linked application, if any.
  final String? company;

  AgendaEvent copyWith({bool? isDone}) => AgendaEvent(
        id: id,
        kind: kind,
        title: title,
        startsAt: startsAt,
        isDone: isDone ?? this.isDone,
        applicationId: applicationId,
        company: company,
      );
}
