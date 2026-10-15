import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_utils.dart';
import 'agenda_event.dart';

class AgendaRepository {
  AgendaRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'agenda_events';
  static const _select = '*, application:applications(company)';

  /// Open events from today onwards, soonest first.
  Future<List<AgendaEvent>> fetchUpcoming({int limit = 20}) async {
    final startOfToday = DateTime.now().dateOnly.toUtc().toIso8601String();
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('is_done', false)
        .gte('starts_at', startOfToday)
        .order('starts_at')
        .limit(limit);
    return rows.map(AgendaEvent.fromJson).toList();
  }

  Future<AgendaEvent> create({
    required AgendaEventKind kind,
    required String title,
    required DateTime startsAt,
    String? applicationId,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'kind': kind.dbValue,
          'title': title,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'application_id': ?applicationId,
        })
        .select(_select)
        .single();
    return AgendaEvent.fromJson(row);
  }

  Future<void> setDone(String id, {required bool isDone}) =>
      _client.from(_table).update({'is_done': isDone}).eq('id', id);
}
