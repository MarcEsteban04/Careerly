import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/interview_prep/data/interview_coach.dart';
import 'package:careerly/features/notifications/data/notifications.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';
import '../interview_prep/interview_prep_fixtures.dart';
import 'shell_test_utils.dart';

/// Get started, reminders, notification taps and interview prep, wired
/// through the app shell.
void main() {
  group('get started', () {
    Future<(FakeCareerProfileRepository, FakeNotifications)> pumpNewUser(
      WidgetTester tester,
    ) async {
      final profiles = FakeCareerProfileRepository()..onboarded = false;
      final notifications = FakeNotifications();
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(listings: sampleListings, profiles: profiles),
        notifications: notifications,
      );
      return (profiles, notifications);
    }

    testWidgets('sets up the career profile, then finds matches',
        (tester) async {
      final (profiles, notifications) = await pumpNewUser(tester);

      expect(find.text('Jobs picked for you'), findsOneWidget);
      await tester.tap(find.text("Let's set you up"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("I'll add it later"));
      await tester.pumpAndSettle();

      // Can't continue without a role.
      expect(find.text('Add a role to continue'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'UI Designer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'UI Designer'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'Manila');
      await tester.tap(find.text('Remote'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Job alerts'), findsOneWidget);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('all set', findRichText: true), findsOneWidget);
      expect(profiles.profile.targetRoles, ['UI Designer']);
      expect(profiles.profile.location, 'Manila');
      expect(profiles.profile.workSetup, WorkSetup.remote);
      expect(notifications.permissionRequests, 1);

      await tester.tap(find.text('See my job matches'));
      await tester.pumpAndSettle();

      expect(profiles.onboarded, isTrue);
      expect(find.textContaining('2 jobs for "UI Designer"'), findsOneWidget);
    });

    testWidgets('can be skipped', (tester) async {
      final (profiles, _) = await pumpNewUser(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(profiles.onboarded, isTrue);
      expect(profiles.profile.isEmpty, isTrue);
      expect(find.text('Marc Esteban'), findsOneWidget);
    });

    testWidgets('is not shown once a profile exists', (tester) async {
      final profiles = FakeCareerProfileRepository(
        const CareerProfile(targetRoles: ['UI Designer']),
      )..onboarded = false;
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(profiles: profiles),
      );

      expect(find.text("Let's set you up"), findsNothing);
      expect(find.text('Marc Esteban'), findsOneWidget);
    });
  });

  group('reminders', () {
    testWidgets('schedules reminders for the agenda', (tester) async {
      final notifications = FakeNotifications();
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: FakeAgendaRepository(sample.agenda),
        notifications: notifications,
      );

      // Follow-up tomorrow and a deadline in 3 days: both have reminders
      // still ahead, whatever the time of day.
      final titles =
          notifications.scheduled.values.map((s) => s.$1.title).toList();
      expect(titles, contains('Time to follow up'));
      expect(titles, contains('Due tomorrow'));
      for (final (_, at) in notifications.scheduled.values) {
        expect(at.isAfter(DateTime.now()), isTrue);
      }
    });

    testWidgets('tapping one opens its application', (tester) async {
      final notifications = FakeNotifications()
        ..launchPayload = const OpenApplicationRoute('a1').payload;
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: FakeAgendaRepository(sample.agenda),
        notifications: notifications,
      );

      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Prepare for your interview'), findsOneWidget);
    });

    testWidgets('the bell lists what is coming up', (tester) async {
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: FakeAgendaRepository(sample.agenda),
      );

      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Portfolio review'), findsWidgets);
      expect(find.text('COMING UP'), findsOneWidget);
    });
  });

  group('interview prep', () {
    testWidgets('builds a kit from the application and saves it',
        (tester) async {
      final ai = FakeAiProvider('Gemini', reply: sampleKitReply);
      final preps = FakeInterviewPrepRepository();
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: FakeAgendaRepository(sample.agenda),
        interviewCoach: InterviewCoach(AiChain([ai])),
        interviewPreps: preps,
      );

      await tester.tap(find.text('Product Designer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare for your interview'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Get ready for'), findsOneWidget);
      expect(find.text('Walk me through your design process.'), findsOneWidget);
      expect(find.text('- Redesigned onboarding after user tests'), findsNothing);
      expect(preps.saved.keys, ['a1']);
      expect(ai.requests.single.prompt, contains('Product Designer at Linear'));

      // Practice mode: answers stay hidden until asked for.
      final question = find.text('Tell me about a time you handled feedback.');
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(
        find.text('- Redesigned onboarding after user tests'),
        findsOneWidget,
      );
    });

    testWidgets('opens a saved kit without calling the AI', (tester) async {
      final ai = FakeAiProvider('Gemini', reply: sampleKitReply);
      final coach = InterviewCoach(AiChain([ai]));
      final preps = FakeInterviewPrepRepository();
      final sample = sampleDashboardData(DateTime.now());
      preps.saved['a1'] = await coach.prepare(
        job: const JobContext(title: 'Product Designer', company: 'Linear'),
        profile: const CareerProfile(),
      );
      ai.requests.clear();

      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: FakeAgendaRepository(sample.agenda),
        interviewCoach: coach,
        interviewPreps: preps,
      );
      await tester.tap(find.byTooltip('Studio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interview prep'));
      await tester.pumpAndSettle();
      // Interviews are listed first.
      await tester.tap(find.text('Linear · Interviewing'));
      await tester.pumpAndSettle();

      expect(find.text('Walk me through your design process.'), findsOneWidget);
      expect(ai.requests, isEmpty);
    });
  });
}
