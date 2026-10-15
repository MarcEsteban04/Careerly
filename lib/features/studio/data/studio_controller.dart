import 'package:flutter/foundation.dart';

import '../../documents/data/career_document.dart';
import '../../documents/data/documents_repository.dart';
import '../../profile/data/career_profile.dart';
import 'career_writer.dart';

/// Saved resumes and cover letters, plus access to the uploaded resume's
/// text and the AI writer.
class StudioController extends ChangeNotifier {
  StudioController({
    required this.documents,
    required this.writer,
    required this.profile,
  });

  final DocumentsRepository documents;
  final CareerWriter writer;

  /// Current career profile (owned by job discovery).
  final CareerProfile Function() profile;

  List<CareerDocument>? _items;
  Object? _error;
  final _textCache = <String, String>{};

  /// Saved documents, newest first, excluding the original resume text.
  List<CareerDocument>? get items => _items;
  Object? get error => _error;

  bool get hasResume => profile().resume != null;

  /// Whether the resume's text is available to enhance or quote from.
  bool get hasResumeText => profile().resume?.textDocumentId != null;

  Future<void> load() async {
    try {
      final all = await documents.fetchAll();
      for (final doc in all.where((d) => d.isOriginalResume)) {
        _textCache[doc.id] = doc.content;
      }
      _items = all.where((d) => !d.isOriginalResume).toList();
      _error = null;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  /// The uploaded resume's full text.
  Future<String> resumeText() async {
    final id = profile().resume?.textDocumentId;
    if (id == null) throw const MissingResumeException();
    final cached = _textCache[id];
    if (cached != null) return cached;
    final doc = await documents.fetch(id);
    if (doc == null) throw const MissingResumeException();
    return _textCache[id] = doc.content;
  }

  /// Saves the text of a newly uploaded resume; returns its document id.
  Future<String> saveResumeText(String fileName, String text) async {
    final doc = await documents.create(
      kind: DocumentKind.resume,
      title: '${CareerDocument.originalResumePrefix} · $fileName',
      content: text,
    );
    _textCache[doc.id] = text;
    return doc.id;
  }

  Future<EnhancedResume> enhanceResume({String? targetRole, JobContext? job}) async =>
      writer.enhanceResume(
        resumeText: await resumeText(),
        profile: profile(),
        targetRole: targetRole,
        job: job,
      );

  Future<CoverLetter> writeCoverLetter({
    required JobContext job,
    required LetterTone tone,
    required LetterLength length,
  }) async =>
      writer.writeCoverLetter(
        resumeText: await resumeText(),
        profile: profile(),
        job: job,
        tone: tone,
        length: length,
      );

  Future<CareerDocument> save({
    required DocumentKind kind,
    required String title,
    required String content,
    String? applicationId,
  }) async {
    final doc = await documents.create(
      kind: kind,
      title: title,
      content: content,
      applicationId: applicationId,
    );
    _items = [doc, ...?_items];
    notifyListeners();
    return doc;
  }

  Future<CareerDocument> update(CareerDocument doc, String content) async {
    final updated = await documents.update(doc.id, content: content);
    _items = [
      for (final d in _items ?? const <CareerDocument>[])
        d.id == doc.id ? updated : d,
    ];
    notifyListeners();
    return updated;
  }

  Future<void> delete(CareerDocument doc) async {
    await documents.delete(doc.id);
    _items = [
      for (final d in _items ?? const <CareerDocument>[])
        if (d.id != doc.id) d,
    ];
    notifyListeners();
  }
}

/// No uploaded resume text to work from.
class MissingResumeException implements Exception {
  const MissingResumeException();

  @override
  String toString() => 'Upload your resume first';
}
