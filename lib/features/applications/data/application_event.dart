import 'package:supabase_flutter/supabase_flutter.dart';

import 'job_application.dart';

enum ApplicationEventKind { created, statusChanged, note }

/// One entry on an application's timeline, recorded by the database.
class ApplicationEvent {
  const ApplicationEvent({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.fromStatus,
    this.toStatus,
    this.note,
  });

  factory ApplicationEvent.fromJson(Map<String, dynamic> json) =>
      ApplicationEvent(
        id: json['id'] as String,
        kind: switch (json['kind']) {
          'status_changed' => ApplicationEventKind.statusChanged,
          'note' => ApplicationEventKind.note,
          _ => ApplicationEventKind.created,
        },
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        fromStatus: json['from_status'] == null
            ? null
            : ApplicationStatus.fromName(json['from_status'] as String),
        toStatus: json['to_status'] == null
            ? null
            : ApplicationStatus.fromName(json['to_status'] as String),
        note: json['note'] as String?,
      );

  final String id;
  final ApplicationEventKind kind;
  final DateTime createdAt;
  final ApplicationStatus? fromStatus;
  final ApplicationStatus? toStatus;
  final String? note;

  String get description => switch (kind) {
        ApplicationEventKind.created =>
          'Added as ${toStatus?.label ?? 'Saved'}',
        ApplicationEventKind.statusChanged => fromStatus == null
            ? 'Moved to ${toStatus?.label}'
            : 'Moved from ${fromStatus!.label} to ${toStatus?.label}',
        ApplicationEventKind.note => note ?? 'Note',
      };
}

class ApplicationEventsRepository {
  ApplicationEventsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// The timeline for one application, newest first.
  Future<List<ApplicationEvent>> fetchFor(String applicationId) async {
    final rows = await _client
        .from('application_events')
        .select()
        .eq('application_id', applicationId)
        .order('created_at', ascending: false);
    return rows.map(ApplicationEvent.fromJson).toList();
  }
}
