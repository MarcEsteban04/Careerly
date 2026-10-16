import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/discover/data/job_matcher.dart';
import 'package:careerly/features/profile/data/career_profile.dart';

void main() {
  JobListing job({
    required String title,
    String description = '',
    bool isRemote = false,
    String? location,
  }) =>
      JobListing(
        id: title,
        title: title,
        company: 'Co',
        source: 'Test',
        applyUrl: 'https://example.com',
        description: description,
        isRemote: isRemote,
        location: location,
      );

  const designer = CareerProfile(
    targetRoles: ['UI Designer'],
    skills: ['Figma', 'User research', 'Go'],
    workSetup: WorkSetup.remote,
  );

  test('no profile, no score', () {
    expect(JobMatcher.match(job(title: 'UI Designer'), const CareerProfile()),
        isNull);
  });

  test('right role, skills and setup scores high with reasons', () {
    final match = JobMatcher.match(
      job(
        title: 'Senior UI Designer',
        description: 'Daily Figma work and user research.',
        isRemote: true,
      ),
      designer,
    )!;

    expect(match.score, greaterThanOrEqualTo(75));
    expect(match.reasons, contains('Fits “UI Designer”'));
    expect(match.reasons.any((r) => r.contains('Figma')), isTrue);
    expect(match.reasons, contains('Remote'));
  });

  test('unrelated role scores low', () {
    final match = JobMatcher.match(
      job(title: 'Accountant', description: 'Ledgers and audits.'),
      designer,
    )!;

    expect(match.score, lessThan(40));
  });

  test('skills match whole words only', () {
    final match = JobMatcher.match(
      job(title: 'Designer', description: 'Experience with Google Ads.'),
      designer,
    )!;

    // "Go" must not match inside "Google".
    expect(match.reasons.any((r) => r.contains('Go')), isFalse);
  });

  group('breakdown', () {
    const developer = CareerProfile(
      targetRoles: ['Full Stack Developer'],
      skills: ['React', 'Nextjs', 'MS Excel', 'MySQL'],
      workSetup: WorkSetup.remote,
    );

    JobListing fullStack({bool isRemote = true}) => job(
          title: 'Full Stack Developer',
          isRemote: isRemote,
          description: 'Build with ReactJS and Next.js, PostgreSQL and '
              'Docker. Reports in Excel. 3+ years of professional experience.',
        );

    test('splits the score into role, skills and setup', () {
      final match = JobMatcher.match(fullStack(), developer)!;

      expect(match.bestRole, 'Full Stack Developer');
      expect(match.rolePoints, JobMatcher.roleWeight);
      expect(match.setupPoints, JobMatcher.setupWeight);
      expect(match.setupFit, SetupFit.good);
      expect(
        match.score,
        match.rolePoints + match.skillPoints + match.setupPoints,
      );
    });

    test('matches skills however they are written', () {
      final match = JobMatcher.match(fullStack(), developer)!;

      // React = ReactJS, Nextjs = Next.js.
      expect(match.matchedSkills, containsAll(['React', 'Nextjs']));
    });

    test('lists skills the post wants that the profile lacks', () {
      final match = JobMatcher.match(fullStack(), developer)!;

      // Excel is covered by "MS Excel".
      expect(match.missingSkills, ['PostgreSQL', 'Docker']);
    });

    test('reads how many years of experience a post asks for', () {
      expect(JobMatcher.match(fullStack(), developer)!.yearsAsked, 3);
      expect(JobMatcher.yearsAsked('2-4 years of relevant work experience'), 2);
      expect(JobMatcher.yearsAsked('at least 5 yrs experience'), 5);
      expect(JobMatcher.yearsAsked('Founded 10 years ago'), isNull);
    });

    test('a post that says it is remote counts as remote', () {
      for (final listing in [
        job(title: 'Web Developer (Remote)'),
        job(
          title: 'Web Developer',
          description: 'Join our team on a part-time, remote basis.',
        ),
        job(title: 'Web Developer', description: 'Work from home, flexible.'),
      ]) {
        expect(JobMatcher.looksRemote(listing), isTrue, reason: listing.title);
        expect(JobMatcher.match(listing, developer)!.setupFit, SetupFit.good);
      }
      expect(
        JobMatcher.looksRemote(
          job(title: 'Web Developer', description: 'Onsite in Makati.'),
        ),
        isFalse,
      );
    });

    test('an on-site job is a poor fit for someone who wants remote', () {
      final match =
          JobMatcher.match(fullStack(isRemote: false), developer)!;
      expect(match.setupFit, SetupFit.poor);
      expect(match.setupNote, contains('remote'));
    });
  });
}
