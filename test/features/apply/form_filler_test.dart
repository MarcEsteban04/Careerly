import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/apply/data/applicant_details.dart';
import 'package:careerly/features/apply/data/form_field_info.dart';
import 'package:careerly/features/apply/data/form_filler.dart';
import 'package:careerly/features/apply/data/form_scripts.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';

void main() {
  const applicant = Applicant(
    name: 'Princess Mae D. Elfa',
    email: 'princess@example.com',
    details: ApplicantDetails(
      phone: '0917 123 4567',
      linkedin: 'linkedin.com/in/princess',
      birthday: '2003-05-12',
      school: 'Bulacan State University',
    ),
    profile: CareerProfile(targetRoles: ['Frontend Developer']),
    resumeText: 'Built 6 client sites in React.',
  );
  const job = JobContext(title: 'Frontend Developer', company: 'Acme');

  const fields = [
    FormFieldInfo(id: 'f0', kind: FormFieldKind.text, label: 'First name'),
    FormFieldInfo(id: 'f1', kind: FormFieldKind.text, label: 'Last name'),
    FormFieldInfo(id: 'f2', kind: FormFieldKind.email, label: 'Email address'),
    FormFieldInfo(id: 'f3', kind: FormFieldKind.tel, label: 'Mobile'),
    FormFieldInfo(id: 'f4', kind: FormFieldKind.url, label: 'LinkedIn profile'),
    FormFieldInfo(id: 'f5', kind: FormFieldKind.date, label: 'Date of birth'),
    FormFieldInfo(
      id: 'f6',
      kind: FormFieldKind.select,
      label: 'Highest education',
      options: ["High school", "Bachelor's degree", "Master's degree"],
    ),
    FormFieldInfo(
      id: 'f7',
      kind: FormFieldKind.textarea,
      label: 'Why do you want to join Acme?',
      maxLength: 500,
    ),
    FormFieldInfo(id: 'f8', kind: FormFieldKind.text, label: 'SSS number'),
  ];

  test('fills basics from her details and drafts the rest with AI', () async {
    final ai = FakeAiProvider(
      'Gemini',
      reply: jsonEncode({
        'answers': [
          {'id': 'f6', 'value': "bachelor's degree"},
          {'id': 'f7', 'value': 'I build React apps for clients 【1†L2】.'},
          {'id': 'f8', 'value': ''},
        ],
      }),
    );
    final answers = await FormFiller(AiChain([ai])).answer(
      fields: fields,
      applicant: applicant,
      job: job,
    );
    final byId = {for (final a in answers) a.field.id: a};

    expect(byId['f0']?.value, 'Princess Mae');
    expect(byId['f1']?.value, 'Elfa');
    expect(byId['f2']?.value, 'princess@example.com');
    expect(byId['f3']?.value, '0917 123 4567');
    expect(byId['f4']?.value, 'linkedin.com/in/princess');
    expect(byId['f5']?.value, '2003-05-12');
    expect(byId['f0']?.source, AnswerSource.details);
    // Matched to the exact option text, citations stripped, unknowns left.
    expect(byId['f6']?.value, "Bachelor's degree");
    expect(byId['f7']?.value, 'I build React apps for clients.');
    expect(byId['f7']?.source, AnswerSource.ai);
    expect(byId.containsKey('f8'), isFalse);
    expect(answers.map((a) => a.field.id), ['f0', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7']);

    // Only the open questions go to AI.
    final prompt = ai.requests.single.prompt;
    expect(prompt, contains('Why do you want to join Acme?'));
    expect(prompt, isNot(contains('"First name"')));
    expect(prompt, contains('School: Bulacan State University'));
  });

  test('skips AI when her details cover every field', () async {
    final ai = FakeAiProvider('Gemini', reply: '{}');
    final answers = await FormFiller(AiChain([ai])).answer(
      fields: fields.take(4).toList(),
      applicant: applicant,
      job: job,
    );

    expect(answers, hasLength(4));
    expect(ai.requests, isEmpty);
  });

  test("leaves what she's already typed", () {
    const typed = FormFieldInfo(
      id: 'f0',
      kind: FormFieldKind.email,
      label: 'Email',
      currentValue: 'other@example.com',
    );
    expect(
      FormFiller(AiChain([])).answer(fields: [typed], applicant: applicant, job: job),
      completion(isEmpty),
    );
  });

  test('tidies labels and knows whose name a field wants', () {
    expect(FormFieldInfo.cleanLabel('Customer name:'), 'Customer name');
    expect(FormFieldInfo.cleanLabel('Email *'), 'Email');
    expect(FormFieldInfo.cleanLabel('Skills'), 'Skills');

    String? fill(String label) => FormFiller.matchFromDetails(
          FormFieldInfo(id: 'x', kind: FormFieldKind.text, label: label),
          applicant,
        );
    expect(fill('Name'), 'Princess Mae D. Elfa');
    expect(fill('Applicant name'), 'Princess Mae D. Elfa');
    expect(fill('Company name'), isNull);
    expect(fill('Emergency contact name'), isNull);
  });

  test('splits names with a middle initial', () {
    expect(applicant.nameParts, (first: 'Princess Mae', middle: 'D.', last: 'Elfa'));
    const single = Applicant(
      name: 'Princess',
      email: null,
      details: ApplicantDetails(),
      profile: CareerProfile(),
    );
    expect(single.nameParts, (first: 'Princess', middle: '', last: ''));
  });

  test('reads the page scan, even when the web view double-encodes it', () {
    final scan = jsonEncode({
      'fields': [
        {'id': 'f0', 'kind': 'email', 'label': 'Email', 'maxLength': -1},
        {
          'id': 'radio:remote',
          'kind': 'radio',
          'label': 'Open to remote?',
          'options': ['Yes', 'No'],
        },
      ],
      'frames': ['https://boards.greenhouse.io/acme/jobs/1'],
    });

    final parsed = FormScripts.parseScan(jsonEncode(scan));
    expect(parsed.fields.map((f) => f.id), ['f0', 'radio:remote']);
    expect(parsed.fields.first.kind, FormFieldKind.email);
    expect(parsed.fields.first.maxLength, isNull);
    expect(parsed.fields.last.optionFor('yes'), 'Yes');
    expect(parsed.frames.single, contains('greenhouse'));
    expect(FormScripts.parseScan('not json').fields, isEmpty);
  });

  test('application details are saved on the device', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = ApplicantDetailsStore();
    expect((await store.load()).isEmpty, isTrue);

    await store.save(const ApplicantDetails(phone: '0917', city: 'Malolos'));
    final loaded = await store.load();
    expect(loaded.phone, '0917');
    expect(loaded.filledCount, 2);
    expect(loaded.lines, ['Mobile number: 0917', 'City: Malolos']);
  });
}
