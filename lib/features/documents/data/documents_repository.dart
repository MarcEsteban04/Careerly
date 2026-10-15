import 'package:supabase_flutter/supabase_flutter.dart';

import 'career_document.dart';

class DocumentsRepository {
  DocumentsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'documents';

  /// All documents, newest first.
  Future<List<CareerDocument>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return rows.map(CareerDocument.fromJson).toList();
  }

  Future<CareerDocument?> fetch(String id) async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    return row == null ? null : CareerDocument.fromJson(row);
  }

  Future<CareerDocument> create({
    required DocumentKind kind,
    required String title,
    required String content,
    String? applicationId,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'kind': kind.dbValue,
          'title': title,
          'content': content,
          'application_id': ?applicationId,
        })
        .select()
        .single();
    return CareerDocument.fromJson(row);
  }

  Future<CareerDocument> update(String id, {String? title, String? content}) async {
    final row = await _client
        .from(_table)
        .update({'title': ?title, 'content': ?content})
        .eq('id', id)
        .select()
        .single();
    return CareerDocument.fromJson(row);
  }

  Future<void> delete(String id) => _client.from(_table).delete().eq('id', id);
}
