import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/shell/data/workspace_data.dart';

import 'shell_test_utils.dart';

void main() {
  Future<FakeGoalsRepository> pumpWithSample(WidgetTester tester) async {
    final sample = sampleDashboardData(DateTime.now());
    final goals = FakeGoalsRepository(sample.goals);
    await pumpShell(
      tester,
      applications: FakeApplicationsRepository(sample.applications),
      agenda: FakeAgendaRepository(sample.agenda),
      goals: goals,
    );
    return goals;
  }

  group('dashboard', () {
    testWidgets('empty account shows friendly empty states', (tester) async {
      await pumpShell(tester, applications: FakeApplicationsRepository());

      expect(find.textContaining(', Marc'), findsOneWidget);
      expect(find.text("Let's get your first application in this week."),
          findsOneWidget);
      expect(find.text("You're all clear"), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No applications yet'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No applications yet'), findsOneWidget);
    });

    testWidgets('spotlights the next event and shows goals', (tester) async {
      await pumpWithSample(tester);

      expect(find.text('Portfolio review'), findsOneWidget);
      expect(find.textContaining('NEXT UP'), findsOneWidget);
      expect(find.text('Apply to jobs'), findsOneWidget);
      expect(find.text('3 of 5 · This week'), findsOneWidget);
    });

    testWidgets('logging goal progress updates it immediately',
        (tester) async {
      final goals = await pumpWithSample(tester);

      final button = find.byTooltip('Log progress').first;
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('4 of 5 · This week'), findsWidgets);
      expect(goals.progress['g1'], 4);
    });

    testWidgets('explains the missing database setup', (tester) async {
      final applications = FakeApplicationsRepository()
        ..error = const PostgrestException(
          message: "Could not find the table 'public.applications'",
          code: 'PGRST205',
        );
      await pumpShell(tester, applications: applications);

      expect(find.text('One setup step left'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tabs switch screens', (tester) async {
      await pumpWithSample(tester);

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(find.text('6 roles tracked'), findsOneWidget);

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('3 things coming up'), findsOneWidget);

      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 complete'), findsOneWidget);
    });

    testWidgets('pipeline stage opens Jobs filtered to it', (tester) async {
      await pumpWithSample(tester);

      final offerStage = find.bySemanticsLabel(RegExp(r'^1 Offer\.'));
      await tester.ensureVisible(offerStage);
      await tester.pumpAndSettle();
      await tester.tap(offerStage);
      await tester.pumpAndSettle();

      expect(find.text('6 roles tracked'), findsOneWidget);
      expect(find.text('Design Engineer'), findsOneWidget);
      expect(find.text('Senior UI Designer'), findsNothing);
    });

    testWidgets('+ on the Jobs tab opens the application form',
        (tester) async {
      await pumpWithSample(tester);

      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New application'));
      await tester.pumpAndSettle();

      expect(find.text('New application'), findsWidgets);
      expect(find.text('Save application'), findsOneWidget);
    });

    testWidgets('+ on Home offers what to add', (tester) async {
      await pumpWithSample(tester);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Interview or reminder'), findsOneWidget);
    });
  });

  test('workspace numbers', () {
    final now = DateTime(2026, 10, 16, 12); // Friday
    final sample = sampleDashboardData(now);
    final data = WorkspaceData(
      applications: sample.applications,
      upcoming: sample.agenda,
      goals: sample.goals,
    );

    expect(data.countWith(ApplicationStatus.applied), 2);
    expect(data.appliedThisWeek(now), 2); // today + yesterday
    expect(data.appliedPerWeekday(now), [0, 0, 0, 1, 1, 0, 0]);
    expect(data.interviewsNextWeek(now), 1);
    expect(data.nextEvent?.title, 'Portfolio review');
  });
}
