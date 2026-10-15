import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_utils.dart';
import 'job_application.dart';

class ApplicationsRepository {
  ApplicationsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'applications';

  /// All applications, most recently updated first.
  Future<List<JobApplication>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('updated_at', ascending: false);
    return rows.map(JobApplication.fromJson).toList();
  }

  Future<JobApplication> create({
    required String company,
    required String role,
    required ApplicationStatus status,
    String? location,
    String? jobUrl,
    DateTime? appliedOn,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'company': company,
          'role': role,
          'status': status.name,
          'location': ?location,
          'job_url': ?jobUrl,
          'applied_on': ?appliedOn?.toDateString(),
        })
        .select()
        .single();
    return JobApplication.fromJson(row);
  }
}
