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
}
