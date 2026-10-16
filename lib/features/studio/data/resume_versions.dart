import '../../applications/data/job_application.dart';
import '../../documents/data/career_document.dart';
import '../../resume/data/resume_insights.dart';

/// One resume she can send: the original upload or a saved (enhanced or
/// tailored) version, with how it has done.
class ResumeVersion {
  const ResumeVersion({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.sent,
    required this.interviews,
    this.document,
  });

  /// The document id, as stored on applications.
  final String id;
  final String title;
  final DateTime createdAt;

  /// The saved document; null for the original upload.
  final CareerDocument? document;

  /// Applications sent with this version.
  final int sent;

  /// Of those, how many reached an interview or offer.
  final int interviews;

  bool get isOriginal => document == null;

  /// Share of sends that led to an interview, 0–1.
  double get interviewRate => sent == 0 ? 0 : interviews / sent;

  /// Original first, then newest saved versions, each with its stats.
  /// The upload's text document id ties applications to it.
  static List<ResumeVersion> build({
    required ResumeInsights? original,
    required Iterable<CareerDocument> documents,
    required Iterable<JobApplication> applications,
  }) {
    ResumeVersion version(
      String id,
      String title,
      DateTime createdAt, [
      CareerDocument? document,
    ]) {
      var sent = 0;
      var interviews = 0;
      for (final a in applications) {
        if (a.resumeDocumentId != id) continue;
        sent++;
        if (a.status == ApplicationStatus.interviewing ||
            a.status == ApplicationStatus.offer) {
          interviews++;
        }
      }
      return ResumeVersion(
        id: id,
        title: title,
        createdAt: createdAt,
        sent: sent,
        interviews: interviews,
        document: document,
      );
    }

    final originalId = original?.textDocumentId;
    return [
      if (original != null && originalId != null)
        version(originalId, original.fileName, original.uploadedAt),
      for (final doc in documents)
        if (doc.kind == DocumentKind.resume && !doc.isOriginalResume)
          version(doc.id, doc.title, doc.createdAt, doc),
    ];
  }

  /// The version with the best interview rate, once one has led to an
  /// interview. Ties go to the one sent more.
  static ResumeVersion? best(List<ResumeVersion> versions) {
    ResumeVersion? top;
    for (final v in versions) {
      if (v.interviews == 0) continue;
      if (top == null ||
          v.interviewRate > top.interviewRate ||
          (v.interviewRate == top.interviewRate && v.sent > top.sent)) {
        top = v;
      }
    }
    return top;
  }
}
