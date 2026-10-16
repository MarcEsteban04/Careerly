import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/apply/data/answer_library.dart';
import 'package:careerly/features/apply/data/applicant_details.dart';
import 'package:careerly/features/apply/data/application_email.dart';
import 'package:careerly/features/apply/data/form_field_info.dart';
import 'package:careerly/features/apply/data/form_filler.dart';
import 'package:careerly/features/apply/data/submission_check.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';

void main() {
  group('confirmation pages', () {
    test('recognizes thank-you text and URLs', () {
      expect(
        SubmissionCheck.looksSubmitted('Thank you for applying to Acme!', ''),
        isTrue,
      );
      expect(
        SubmissionCheck.looksSubmitted(
          "We've received your application and will be in touch.",
          '',
        ),
        isTrue,
      );
      expect(
        SubmissionCheck.looksSubmitted('', 'https://jobs.acme.com/apply/thank-you'),
        isTrue,
      );
    });

    test('ignores ordinary job pages', () {
      expect(
        SubmissionCheck.looksSubmitted(
          'Submit your application below. Applications close Friday.',
          'https://jobs.acme.com/apply',
        ),
        isFalse,
      );
    });
  });

  group('application emails', () {
    test('finds the address the post asks CVs to be sent to', () {
      expect(
        ApplicationEmail.find(
          description: 'Questions? info@acme.com. Interested applicants may '
              'send their CV to hr.recruit@acme.com.',
        ),
        'hr.recruit@acme.com',
      );
    });

    test('reads mailto: links and skips no-reply addresses', () {
      expect(ApplicationEmail.find(applyUrl: 'mailto:jobs@acme.ph'), 'jobs@acme.ph');
      expect(
        ApplicationEmail.find(description: 'Sent from noreply@acme.com'),
        isNull,
      );
      expect(ApplicationEmail.find(description: 'Apply on our site.'), isNull);
    });
  });

  group('answer library', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    const salary = FormFieldInfo(
      id: 'f0',
      kind: FormFieldKind.text,
      label: 'What are your salary expectations?',
    );
    const whyUs = FormFieldInfo(
      id: 'f1',
      kind: FormFieldKind.textarea,
      label: 'Why do you want to join us?',
    );

    test('remembers answers and reuses them on similar questions', () async {
      final library = AnswerLibrary();
      await library.remember(
        const [
          FieldAnswer(field: salary, value: '₱50,000 a month', source: AnswerSource.ai),
          FieldAnswer(
            field: whyUs,
            value: 'Acme builds tools I use every day.',
            source: AnswerSource.ai,
          ),
          FieldAnswer(
            field: FormFieldInfo(id: 'f2', kind: FormFieldKind.email, label: 'Email'),
            value: 'princess@example.com',
            source: AnswerSource.details,
          ),
        ],
        company: 'Acme',
      );
      final saved = await library.load();
      // Details aren't saved: they live in her application details.
      expect(saved.map((a) => a.question), [salary.label, whyUs.label]);
      expect(saved.last.company, 'Acme');

      const similar = FormFieldInfo(
        id: 'g0',
        kind: FormFieldKind.text,
        label: 'Salary expectations',
      );
      expect(AnswerLibrary.match(similar, saved, company: 'Globex')?.answer,
          '₱50,000 a month');
      // About Acme, so not reused for Globex, but fine on Acme's next page.
      expect(AnswerLibrary.match(whyUs, saved, company: 'Globex'), isNull);
      expect(AnswerLibrary.match(whyUs, saved, company: 'Acme'), isNotNull);
    });

    test('the filler uses saved answers before asking AI', () async {
      final ai = FakeAiProvider('Gemini', reply: '{"answers": []}');
      final answers = await FormFiller(AiChain([ai])).answer(
        fields: const [salary],
        applicant: const Applicant(
          name: 'Princess',
          email: null,
          details: ApplicantDetails(),
          profile: CareerProfile(),
        ),
        job: const JobContext(title: 'Developer', company: 'Globex'),
        saved: [
          SavedAnswer(
            question: 'Salary expectations',
            answer: '₱50,000 a month',
            updatedAt: DateTime(2026, 10, 1),
          ),
        ],
      );

      expect(answers.single.value, '₱50,000 a month');
      expect(answers.single.source, AnswerSource.library);
      expect(ai.requests, isEmpty);
    });
  });
}
