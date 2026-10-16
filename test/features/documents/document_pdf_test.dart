import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/documents/data/document_pdf.dart';
import 'package:careerly/features/documents/data/resume_design.dart';

/// A resume long enough to run onto a second page.
final _resume = [
  '# Princess Mae D. Elfa',
  'Bulacan · princess@example.com · 0917 123 4567',
  '',
  '## Summary',
  'Full Stack Developer with 2 years of experience building web apps.',
  '',
  '## Experience',
  for (var job = 1; job <= 6; job++) ...[
    '**Developer $job** · Company $job · 2020 – 2026',
    for (var i = 1; i <= 6; i++)
      '- Built feature $i for client $job, cutting load time by ${i * 5}%.',
    '',
  ],
  '## Skills',
  'React, Next.js, TypeScript, Supabase, MySQL, Tailwind',
  '',
  '## Education',
  '**BS Information Technology** · Bulacan State University · 2026',
].join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final design in ResumeDesign.values) {
    test('renders the ${design.label} design', () async {
      final bytes = await DocumentPdf.build(_resume, design: design);

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  }

  test('renders a cover letter with no sections', () async {
    final bytes = await DocumentPdf.build(
      'Dear Hiring Team,\n\nI would love to join Acme.\n\nPrincess',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
