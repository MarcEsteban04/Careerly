import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/documents/data/career_document.dart';
import 'package:careerly/features/resume/data/resume_insights.dart';
import 'package:careerly/features/studio/data/resume_versions.dart';

void main() {
  final day = DateTime(2026, 10, 1);

  CareerDocument doc(String id, {DocumentKind kind = DocumentKind.resume}) =>
      CareerDocument(
        id: id,
        kind: kind,
        title: 'Resume $id',
        content: '# Name',
        createdAt: day,
      );

  JobApplication sent(String id, String resumeId, ApplicationStatus status) =>
      JobApplication(
        id: id,
        company: 'Co',
        role: 'Dev',
        status: status,
        resumeDocumentId: resumeId,
        createdAt: day,
        updatedAt: day,
      );

  final original = ResumeInsights(
    fileName: 'cv.pdf',
    uploadedAt: day,
    textDocumentId: 'orig',
  );

  test('counts sends and interviews per version, original first', () {
    final versions = ResumeVersion.build(
      original: original,
      documents: [doc('a'), doc('b'), doc('letter', kind: DocumentKind.coverLetter)],
      applications: [
        sent('1', 'orig', ApplicationStatus.applied),
        sent('2', 'orig', ApplicationStatus.rejected),
        sent('3', 'a', ApplicationStatus.interviewing),
        sent('4', 'a', ApplicationStatus.applied),
        sent('5', 'b', ApplicationStatus.offer),
      ],
    );

    expect(versions.map((v) => v.id), ['orig', 'a', 'b']);
    expect(versions.first.isOriginal, isTrue);
    expect((versions[0].sent, versions[0].interviews), (2, 0));
    expect((versions[1].sent, versions[1].interviews), (2, 1));
    expect((versions[2].sent, versions[2].interviews), (1, 1));
  });

  test('the best performer has the highest interview rate', () {
    final versions = ResumeVersion.build(
      original: original,
      documents: [doc('a'), doc('b')],
      applications: [
        sent('1', 'a', ApplicationStatus.interviewing),
        sent('2', 'a', ApplicationStatus.applied),
        sent('3', 'b', ApplicationStatus.offer),
      ],
    );

    expect(ResumeVersion.best(versions)?.id, 'b');
  });

  test('no interviews yet means no best performer', () {
    final versions = ResumeVersion.build(
      original: original,
      documents: [doc('a')],
      applications: [sent('1', 'a', ApplicationStatus.applied)],
    );

    expect(ResumeVersion.best(versions), isNull);
  });
}
