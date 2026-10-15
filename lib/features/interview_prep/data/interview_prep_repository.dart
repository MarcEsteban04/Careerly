import 'package:supabase_flutter/supabase_flutter.dart';

import 'interview_prep.dart';

/// One saved interview kit per application.
class InterviewPrepRepository {
  InterviewPrepRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'interview_preps';

  Future<InterviewPrep?> fetch(String applicationId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('application_id', applicationId)
        .maybeSingle();
    if (row == null) return null;
    return InterviewPrep.fromJson(
      row['content'] as Map<String, dynamic>,
      provider: row['provider'] as String? ?? 'AI',
      createdAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  Future<void> save(String applicationId, InterviewPrep prep) =>
      _client.from(_table).upsert(
        {
          'application_id': applicationId,
          'content': prep.toJson(),
          'provider': prep.provider,
          'updated_at': prep.createdAt.toUtc().toIso8601String(),
        },
        onConflict: 'user_id,application_id',
      );
}
