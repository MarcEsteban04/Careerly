import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/applications/data/stale_applications.dart';

void main() {
  final now = DateTime(2026, 10, 30, 12);

  JobApplication app(
    String id,
    ApplicationStatus status, {
    required int quietFor,
    DateTime? followUpOn,
  }) {
    final last = now.subtract(Duration(days: quietFor));
    return JobApplication(
      id: id,
      company: 'Acme',
      role: 'Designer',
      status: status,
      appliedOn: last,
      followUpOn: followUpOn,
      createdAt: last,
      updatedAt: last,
    );
  }

  test('applied for 3 weeks or interviewing for 2 has gone quiet', () {
    final stale = StaleApplications.find(
      [
        app('fresh', ApplicationStatus.applied, quietFor: 10),
        app('applied', ApplicationStatus.applied, quietFor: 25),
        app('interview', ApplicationStatus.interviewing, quietFor: 15),
        app('saved', ApplicationStatus.saved, quietFor: 60),
        app('offer', ApplicationStatus.offer, quietFor: 60),
      ],
      now: now,
    );

    // Quietest first.
    expect(stale.map((a) => a.id), ['applied', 'interview']);
  });

  test('"wait a week" holds one back until the date', () {
    final waiting = app(
      'a',
      ApplicationStatus.applied,
      quietFor: 30,
      followUpOn: DateTime(2026, 11, 2),
    );

    expect(StaleApplications.find([waiting], now: now), isEmpty);
    expect(
      StaleApplications.find([waiting], now: DateTime(2026, 11, 2, 9)),
      hasLength(1),
    );
  });

  test('counts days since the last activity', () {
    expect(
      StaleApplications.quietDays(
        app('a', ApplicationStatus.applied, quietFor: 22),
        now: now,
      ),
      22,
    );
  });
}
