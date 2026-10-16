import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/discover/data/scam_check.dart';

JobListing post(
  String description, {
  String title = 'Virtual Assistant',
  String company = 'Bright Co',
  String? salary,
}) =>
    JobListing(
      id: 'x',
      title: title,
      company: company,
      source: 'Facebook',
      applyUrl: 'https://example.com',
      salary: salary,
      description: description,
    );

void main() {
  test('a normal post is clear', () {
    final check = ScamCheck.of(
      post(
        'We invest in our people. Apply at careers.brightco.com. Two rounds '
        'of interviews. Requirements: 2 years of customer support.',
      ),
    );
    expect(check.risk, ScamRisk.none);
    expect(check.reasons, isEmpty);
  });

  test('fees, GCash payments, investing and task scams are high risk', () {
    for (final text in [
      'A refundable deposit of ₱1,500 is required before training.',
      'Pay the training fee to start.',
      'Send ₱500 via GCash to reserve your slot.',
      'Investment opportunity: earn from forex trading.',
      'Earn per task: like videos and rate products.',
    ]) {
      expect(ScamCheck.of(post(text)).risk, ScamRisk.high, reason: text);
    }
  });

  test('chat-only contact, personal email and no-interview hiring need a look',
      () {
    final check = ScamCheck.of(
      post(
        'Hiring on the spot, no interview! Message us on Telegram or email '
        'hr.brightco@gmail.com.',
      ),
    );
    expect(check.risk, ScamRisk.caution);
    expect(check.reasons, hasLength(3));
  });

  test('flags pay far above the role and unnamed companies', () {
    final check = ScamCheck.of(
      post(
        'Data entry, no experience needed.',
        company: 'Confidential',
        salary: '₱200,000/month',
      ),
    );
    expect(check.risk, ScamRisk.caution);
    expect(check.reasons, hasLength(2));
  });
}
