import 'package:supabase_flutter/supabase_flutter.dart';

import 'goal.dart';

class GoalsRepository {
  GoalsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'goals';

  Future<List<Goal>> fetchAll() async {
    final rows = await _client.from(_table).select().order('created_at');
    return rows.map(Goal.fromJson).toList();
  }

  Future<Goal> create({
    required String title,
    required int target,
    required GoalPeriod period,
  }) async {
    final row = await _client
        .from(_table)
        .insert({'title': title, 'target': target, 'period': period.name})
        .select()
        .single();
    return Goal.fromJson(row);
  }

  Future<void> setProgress(String id, int progress) =>
      _client.from(_table).update({'progress': progress}).eq('id', id);
}
