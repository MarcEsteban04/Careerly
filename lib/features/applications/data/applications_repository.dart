import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_utils.dart';
import 'job_application.dart';

/// Editable details of an application (everything but status and notes).
class ApplicationDetails {
  const ApplicationDetails({
    required this.company,
    required this.role,
    this.location,
    this.jobUrl,
    this.salary,
    this.appliedOn,
  });

  final String company;
  final String role;
  final String? location;
  final String? jobUrl;
  final String? salary;
  final DateTime? appliedOn;
}

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
    String? salary,
    DateTime? appliedOn,
    String? source,
    String? externalId,
    String? jobDescription,
    DateTime? followUpOn,
    String? resumeDocumentId,
    String? coverLetterDocumentId,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'company': company,
          'role': role,
          'status': status.name,
          'location': ?location,
          'job_url': ?jobUrl,
          'salary': ?salary,
          'applied_on': ?appliedOn?.toDateString(),
          'source': ?source,
          'external_id': ?externalId,
          'job_description': ?jobDescription,
          'follow_up_on': ?followUpOn?.toDateString(),
          'resume_document_id': ?resumeDocumentId,
          'cover_letter_document_id': ?coverLetterDocumentId,
        })
        .select()
        .single();
    return JobApplication.fromJson(row);
  }

  Future<JobApplication> updateDetails(String id, ApplicationDetails details) =>
      _update(id, {
        'company': details.company,
        'role': details.role,
        'location': details.location,
        'job_url': details.jobUrl,
        'salary': details.salary,
        'applied_on': details.appliedOn?.toDateString(),
      });

  /// Moves an application to [status]. Stamps today's date as "applied on"
  /// the first time it leaves "saved".
  Future<JobApplication> updateStatus(
    JobApplication application,
    ApplicationStatus status,
  ) =>
      _update(application.id, {
        'status': status.name,
        if (application.appliedOn == null && status != ApplicationStatus.saved)
          'applied_on': DateTime.now().toDateString(),
      });

  /// Records that the user applied, with the documents they sent.
  Future<JobApplication> markApplied(
    JobApplication application, {
    String? resumeDocumentId,
    String? coverLetterDocumentId,
    DateTime? followUpOn,
  }) =>
      _update(application.id, {
        if (application.status == ApplicationStatus.saved) 'status': 'applied',
        'applied_on': (application.appliedOn ?? DateTime.now()).toDateString(),
        'resume_document_id': ?resumeDocumentId,
        'cover_letter_document_id': ?coverLetterDocumentId,
        'follow_up_on': ?followUpOn?.toDateString(),
      });

  Future<JobApplication> setFollowUp(String id, DateTime? date) =>
      _update(id, {'follow_up_on': date?.toDateString()});

  Future<JobApplication> updateNotes(String id, String notes) =>
      _update(id, {'notes': notes.trim().isEmpty ? null : notes.trim()});

  Future<void> delete(String id) => _client.from(_table).delete().eq('id', id);

  Future<JobApplication> _update(String id, Map<String, dynamic> values) async {
    final row = await _client
        .from(_table)
        .update(values)
        .eq('id', id)
        .select()
        .single();
    return JobApplication.fromJson(row);
  }
}
