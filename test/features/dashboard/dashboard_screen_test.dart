import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/dashboard/data/dashboard_data.dart';

import 'dashboard_test_utils.dart';

void main() {
  testWidgets('empty account shows friendly empty states', (tester) async {
    await pumpDashboard(tester, applications: FakeApplicationsRepository());

    expect(find.textContaining(', Marc'), findsOneWidget);
    expect(find.text("Let's get your first application in this week."),
        findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No applications yet'), 300);
    expect(find.text('No applications yet'), findsOneWidget);
  });

  testWidgets('shows agenda, pipeline and goals from data', (tester) async {
    final sample = sampleDashboardData(DateTime.now());
    await pumpDashboard(
      tester,
      applications: FakeApplicationsRepository(sample.applications),
      agenda: FakeAgendaRepository(sample.agenda),
      goals: FakeGoalsRepository(sample.goals),
    );

    expect(find.text('Portfolio review'), findsOneWidget);
    expect(find.text('5'), findsWidgets); // active applications
    await tester.scrollUntilVisible(find.text('Apply to jobs'), 300);
    expect(find.text('3 of 5 · This week'), findsOneWidget);
  });

  testWidgets('logging goal progress updates it immediately', (tester) async {
    final sample = sampleDashboardData(DateTime.now());
    final goals = FakeGoalsRepository(sample.goals);
    await pumpDashboard(
      tester,
      applications: FakeApplicationsRepository(),
      goals: goals,
    );

    // Bring the goal on screen, clear of the floating Add button.
    await tester.ensureVisible(find.byTooltip('Log progress'));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Log progress'));
    await tester.pumpAndSettle();

    expect(find.text('4 of 5 · This week'), findsOneWidget);
    expect(goals.progress['g1'], 4);
  });

  testWidgets('explains the missing database setup', (tester) async {
    final applications = FakeApplicationsRepository()
      ..error = const PostgrestException(
        message: "Could not find the table 'public.applications'",
        code: 'PGRST205',
      );
    await pumpDashboard(tester, applications: applications);

    expect(find.text('One setup step left'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('weekly numbers', () {
    final now = DateTime(2026, 10, 16, 12); // Friday
    final sample = sampleDashboardData(now);
    final data = DashboardData(
      applications: sample.applications,
      upcoming: sample.agenda,
      goals: sample.goals,
    );

    expect(data.countWith(ApplicationStatus.applied), 2);
    expect(data.appliedThisWeek(now), 2); // today + yesterday
    expect(data.interviewsNextWeek(now), 1);
  });
}
