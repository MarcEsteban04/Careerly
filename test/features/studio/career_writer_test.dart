import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/documents/data/career_document.dart';
import 'package:careerly/features/documents/data/document_markup.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/resume/data/resume_insights.dart';
import 'package:careerly/features/studio/data/career_writer.dart';
import 'package:careerly/features/studio/data/studio_controller.dart';

import '../../core/ai/fake_ai_provider.dart';
import '../shell/shell_test_utils.dart';

void main() {
  const profile = CareerProfile(targetRoles: ['UI Designer']);

  group('CareerWriter', () {
    test('enhances a resume and lists changes', () async {
      final ai = FakeAiProvider(
        'Gemini',
        reply: '{"resume": "# Maria Santos\\n## Summary\\nUI designer.", '
            '"changes": ["Stronger summary", "Action verbs"]}',
      );

      final result = await CareerWriter(AiChain([ai])).enhanceResume(
        resumeText: 'Maria Santos, designer',
        profile: profile,
        targetRole: 'Product Designer',
      );

      expect(result.content, startsWith('# Maria Santos'));
      expect(result.changes, ['Stronger summary', 'Action verbs']);
      expect(result.provider, 'Gemini');
      expect(ai.requests.single.prompt, contains('Product Designer'));
      expect(ai.requests.single.prompt, contains('Maria Santos, designer'));
      expect(ai.requests.single.json, isTrue);
    });

    test('writes a cover letter for the job', () async {
      final ai = FakeAiProvider(
        'Groq',
        reply: '{"letter": "Dear Hiring Manager,\\n\\nHello."}',
      );

      final letter = await CareerWriter(AiChain([ai])).writeCoverLetter(
        resumeText: 'resume',
        profile: profile,
        job: const JobContext(
          title: 'UI Designer',
          company: 'Acme',
          description: 'Figma required',
        ),
        tone: LetterTone.warm,
        length: LetterLength.short,
      );

      expect(letter.content, startsWith('Dear Hiring Manager'));
      final prompt = ai.requests.single.prompt;
      expect(prompt, contains('UI Designer at Acme'));
      expect(prompt, contains('Figma required'));
      expect(prompt, contains('warm'));
      expect(prompt, contains('150-200 words'));
    });

    test('rejects replies without the document', () async {
      final writer = CareerWriter(
        AiChain([FakeAiProvider('Gemini', reply: '{"oops": true}')]),
      );

      await expectLater(
        writer.enhanceResume(resumeText: 'x', profile: profile),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('StudioController', () {
    final resumeProfile = CareerProfile(
      resume: ResumeInsights(
        fileName: 'cv.pdf',
        uploadedAt: DateTime(2026, 10, 1),
        textDocumentId: 'orig',
      ),
    );

    test('reads the original resume text and hides it from the list',
        () async {
      final docs = FakeDocumentsRepository([
        CareerDocument(
          id: 'orig',
          kind: DocumentKind.resume,
          title: '${CareerDocument.originalResumePrefix} · cv.pdf',
          content: 'Original text',
          createdAt: DateTime(2026, 10, 1),
        ),
      ]);
      final studio = fakeStudio(profile: resumeProfile, documents: docs);

      await studio.load();

      expect(studio.items, isEmpty);
      expect(studio.hasResumeText, isTrue);
      expect(await studio.resumeText(), 'Original text');
    });

    test('asks for a resume when there is none', () async {
      final studio = fakeStudio();

      await expectLater(
        studio.resumeText(),
        throwsA(isA<MissingResumeException>()),
      );
    });
  });

  test('markup parses titles, sections, bullets and bold', () {
    final blocks = parseMarkup(
      '# Maria\nmaria@x.com\n\n## Experience\n**Designer** · Acme\n- Built **3** apps',
    );

    expect(blocks.first, isA<TitleBlock>());
    expect(blocks.whereType<HeadingBlock>().single.text, 'Experience');
    final bullet = blocks.whereType<BulletBlock>().single;
    expect(bullet.spans.map((s) => s.bold), [false, true, false]);
    expect(markupToPlainText('## Skills\n- **Figma**'), 'Skills\n• Figma');
  });
}
