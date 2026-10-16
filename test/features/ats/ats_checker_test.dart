import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/ats/data/ats_checker.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

const _strongResume = '''
# Princess Mae D. Elfa
Bulacan · princess@example.com · +63 917 123 4567 · https://princess.vercel.app

## Summary
Full Stack Developer with 2 years of experience building web apps in React,
Next.js, TypeScript and MySQL.

## Experience
**Full Stack Developer** · Freelance · 2024 – 2026
- Built an AI support app that cut response time by 30%.
- Developed 6 client sites in React and Next.js with Tailwind.
- Improved page load speed by 40% through caching and image optimization.
- Integrated Supabase auth and MySQL reporting for 3 clients.

**IT Intern** · DENR · 2025 – 2026
- Digitized 2,000 land records, raising retrieval speed by 15%.
- Supported 40 staff with troubleshooting and system setup.

## Skills
React, Next.js, TypeScript, JavaScript, MySQL, Supabase, Tailwind, Git

## Education
**BS Information Technology** · Bulacan State University · 2022 – 2026
- Cum Laude; capstone on an AI clinic support system.
''';

void main() {
  const job = JobContext(
    title: 'Full Stack Developer',
    company: 'Acme',
    description: 'We need a Full Stack Developer skilled in React, Next.js, '
        'TypeScript, Node.js, PostgreSQL and Docker. You will build and '
        'maintain customer dashboards with our product team, write tests and '
        'ship features every sprint.',
  );

  test('scores each part, and the total adds up', () {
    final report = AtsChecker.check(resume: _strongResume, job: job);
    int points(String title) =>
        report.checks.firstWhere((c) => c.title == title).points;

    // 3 of the 6 skills the post names.
    expect(points('Keywords from the job'), 20);
    expect(points('Measurable results'), 15);
    // This sample is short (~150 words): one to two pages is the target.
    expect(points('Length'), 2);
    expect(
      report.score,
      report.checks.fold<int>(0, (sum, c) => sum + c.points),
    );
    expect(report.matchedKeywords, containsAll(['React', 'Next.js', 'TypeScript']));
    expect(report.missingKeywords, containsAll(['Node.js', 'PostgreSQL', 'Docker']));
    expect(report.checks.firstWhere((c) => c.title == 'Job title').passed, isTrue);
    expect(
      report.checks.firstWhere((c) => c.title == 'Standard sections').passed,
      isTrue,
    );
    expect(
      report.checks.firstWhere((c) => c.title == 'Contact details').passed,
      isTrue,
    );
  });

  test('a thin resume scores low, with a tip for each gap', () {
    final report = AtsChecker.check(
      resume: 'Princess Elfa\nI like computers and want a job.',
      job: job,
    );

    expect(report.score, lessThan(30));
    for (final check in report.checks.where((c) => !c.passed)) {
      expect(check.tip, isNotNull, reason: check.title);
    }
    expect(
      report.checks.firstWhere((c) => c.title == 'Standard sections').detail,
      contains('Experience'),
    );
  });

  test('says when there is no job description to compare', () {
    final report = AtsChecker.check(
      resume: _strongResume,
      job: const JobContext(title: 'Web Developer', company: 'Acme'),
    );

    expect(report.hasJobDetails, isFalse);
    expect(report.missingKeywords, isEmpty);
  });
}
