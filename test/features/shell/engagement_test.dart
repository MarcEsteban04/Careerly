import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/company_research/data/company_researcher.dart';
import 'package:careerly/features/interview_prep/data/interview_coach.dart';
import 'package:careerly/features/job_import/data/job_post_reader.dart';
import 'package:careerly/features/messages/data/message_writer.dart';
import 'package:careerly/features/negotiation/data/negotiation_coach.dart';
import 'package:careerly/features/notifications/data/notifications.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/studio/data/career_writer.dart';

import '../../core/ai/fake_ai_provider.dart';
import '../interview_prep/interview_prep_fixtures.dart';
import '../negotiation/negotiation_coach_test.dart' show planReply;
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

      await tapVisible(tester, find.text('Product Designer').first);
      await tester.tap(find.text('Prepare for your interview'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Get ready for'), findsOneWidget);
      expect(find.text('Walk me through your design process.'), findsOneWidget);
      expect(find.text('- Redesigned onboarding after user tests'), findsNothing);
      expect(preps.saved.keys, ['a1']);
      expect(ai.requests.single.prompt, contains('Product Designer at Linear'));

      // Practice mode: answers stay hidden until asked for.
      final question = find.text('Tell me about a time you handled feedback.');
      // Mid-screen, clear of the top bar and the bottom action bar.
      await Scrollable.ensureVisible(tester.element(question), alignment: 0.3);
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

    testWidgets('mock interview scores an answer', (tester) async {
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
      await tapVisible(tester, find.text('Product Designer').first);
      await tester.tap(find.text('Prepare for your interview'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Practice a mock interview'));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Get feedback'), findsOneWidget);

      ai.reply = '{"score": 8, "verdict": "Strong and specific.", '
          '"strengths": ["Clear structure"], '
          '"improvements": ["Quantify the result"], '
          '"better_answer": "I led a redesign that..."}';
      await tester.enterText(
        find.byType(TextField),
        'I redesigned our onboarding after user testing showed confusion.',
      );
      await tester.pump();
      await tester.tap(find.text('Get feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Strong and specific.'), findsOneWidget);
      expect(find.text('Quantify the result'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
    });
  });

  group('job sharing', () {
    testWidgets('a shared link becomes a tracked job', (tester) async {
      final ai = FakeAiProvider(
        'Gemini',
        reply: '{"is_job": true, "role": "UX Writer", "company": "Kumu", '
            '"location": "Remote", "description": "Write product copy."}',
      );
      final applications = FakeApplicationsRepository();
      await pumpShell(
        tester,
        applications: applications,
        shareInbox: FakeJobShareInbox(
          'https://www.linkedin.com/jobs/view/42',
        ),
        jobPostReader: JobPostReader(
          AiChain([ai]),
          httpClient: MockClient((_) async => http.Response('', 404)),
        ),
      );

      expect(find.text('Track this job'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Kumu'), findsOneWidget);
      await tester.ensureVisible(find.text('Save application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save application'));
      await tester.pumpAndSettle();

      final created = applications.items.single;
      expect(created.role, 'UX Writer');
      expect(created.status, ApplicationStatus.saved);
      expect(created.source, 'LinkedIn');
      expect(created.jobDescription, 'Write product copy.');
      expect(find.text('Added UX Writer at Kumu'), findsOneWidget);
    });

    testWidgets('a post that can\'t be read still opens the form',
        (tester) async {
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        shareInbox: FakeJobShareInbox('https://example.com/job'),
        jobPostReader: JobPostReader(
          AiChain([FakeAiProvider('Gemini', reply: '{"is_job": false}')]),
          httpClient: MockClient((_) async => http.Response('', 404)),
        ),
      );

      expect(find.textContaining("doesn't look like a job post"), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'https://example.com/job'),
        findsOneWidget,
      );
    });
  });

  group('quiet applications', () {
    testWidgets('can be put on hold or closed from the dashboard',
        (tester) async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 30));
      final applications = FakeApplicationsRepository([
        JobApplication(
          id: 'q1',
          company: 'Globex',
          role: 'UI Designer',
          status: ApplicationStatus.applied,
          appliedOn: old,
          createdAt: old,
          updatedAt: old,
        ),
        JobApplication(
          id: 'q2',
          company: 'Initech',
          role: 'Web Designer',
          status: ApplicationStatus.applied,
          appliedOn: old,
          createdAt: old,
          updatedAt: old,
        ),
      ]);
      await pumpShell(tester, applications: applications);

      await tester.tap(find.text('2 applications have gone quiet'));
      await tester.pumpAndSettle();
      expect(find.text('Gone quiet'), findsOneWidget);

      await tester.tap(find.text('Wait a week').first);
      await tester.pumpAndSettle();
      expect(applications.followUps.keys, ['q1']);

      await tester.tap(find.text('Close it'));
      await tester.pumpAndSettle();
      expect(applications.notes['q2'], startsWith('Closed: no reply after'));
      expect(find.text('All sorted. Nice work!'), findsOneWidget);
    });
  });

  group('messages', () {
    testWidgets('drafts a follow-up for an application', (tester) async {
      final ai = FakeAiProvider(
        'Gemini',
        reply: '{"subject": "Following up", "body": "Hi, just checking in."}',
      );
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        messageWriter: MessageWriter(AiChain([ai])),
      );
      await tester.ensureVisible(find.text('Senior UI Designer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Senior UI Designer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write a message'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write my message'));
      await tester.pumpAndSettle();

      expect(find.text('Following up'), findsOneWidget);
      expect(find.text('Hi, just checking in.'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(ai.requests.single.prompt, contains('Senior UI Designer at Canva'));
      expect(ai.requests.single.prompt, contains('Marc Esteban'));
    });
  });

  group('offers and employers', () {
    Future<FakeApplicationsRepository> pumpWithOffer(
      WidgetTester tester, {
      NegotiationCoach? negotiationCoach,
      CompanyResearcher? companyResearcher,
    }) async {
      final sample = sampleDashboardData(DateTime.now());
      final applications = FakeApplicationsRepository(sample.applications);
      await pumpShell(
        tester,
        applications: applications,
        agenda: FakeAgendaRepository(sample.agenda),
        negotiationCoach: negotiationCoach,
        companyResearcher: companyResearcher,
      );
      // Design Engineer at Figma is at the offer stage.
      await tapVisible(tester, find.text('Design Engineer'));
      return applications;
    }

    testWidgets('negotiates an offer and saves the plan to notes', (
      tester,
    ) async {
      final ai = FakeAiProvider('Gemini', reply: planReply);
      final applications = await pumpWithOffer(
        tester,
        negotiationCoach: NegotiationCoach(AiChain([ai])),
      );

      await tapVisible(tester, find.text('Negotiate your offer'));
      // The offer comes from the tracked salary.
      expect(find.text(r'$6,500/month'), findsOneWidget);
      await tester.tap(find.text('Build my plan'));
      await tester.pumpAndSettle();

      expect(find.text('₱52,000 a month'), findsOneWidget);
      expect(find.text('Talking points'), findsOneWidget);
      expect(ai.requests.single.prompt, contains(r'$6,500/month'));
      expect(ai.requests.single.prompt, contains('Design Engineer at Figma'));

      await tapVisible(tester, find.text('Save plan to notes'));
      expect(applications.notes['a3'], contains('Counter: ₱52,000 a month'));
      expect(find.text('Saved to notes'), findsOneWidget);
    });

    testWidgets('researches the employer from a tracked job', (tester) async {
      final ai = FakeAiProvider(
        'Gemini',
        reply: '{"summary": "Figma makes a collaborative design tool.", '
            '"facts": ["Industry: Design software"], '
            '"good_signs": ["Well-known product"], '
            '"watch_outs": ["Remote roles are competitive"], '
            '"questions_to_ask": ["How do designers and engineers pair?"]}',
      );
      await pumpWithOffer(
        tester,
        companyResearcher: CompanyResearcher(AiChain([ai])),
      );

      expect(find.text('About Figma'), findsOneWidget);
      await tapVisible(tester, find.text('Research this company'));

      expect(find.text('Figma makes a collaborative design tool.'), findsOneWidget);
      expect(find.text('Industry: Design software'), findsOneWidget);
      expect(find.text('Worth checking'), findsOneWidget);
      expect(ai.requests.single.webSearch, isTrue);
      expect(find.byTooltip('Refresh research'), findsOneWidget);
    });
  });

  group('apply by email', () {
    testWidgets('drafts the application email for a mailto: job', (
      tester,
    ) async {
      final day = DateTime(2026, 10, 10);
      final ai = FakeAiProvider(
        'Gemini',
        reply: '{"subject": "Application: Web Developer", '
            '"body": "Hi Hiring Team,\\n\\nPlease find my resume attached."}',
      );
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository([
          JobApplication(
            id: 'm1',
            company: 'Acme',
            role: 'Web Developer',
            status: ApplicationStatus.saved,
            jobUrl: 'mailto:hr@acme.ph',
            createdAt: day,
            updatedAt: day,
          ),
        ]),
        messageWriter: MessageWriter(AiChain([ai])),
      );

      await tapVisible(tester, find.text('Web Developer'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // No web page to open: emailing is the way to apply.
      expect(find.text('Apply by email'), findsOneWidget);
      expect(find.text('Open application page'), findsNothing);
      await tapVisible(tester, find.text('Email your application'));

      expect(find.text('hr@acme.ph'), findsOneWidget);
      await tester.tap(find.text('Write my email'));
      await tester.pumpAndSettle();

      expect(find.text('Application: Web Developer'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(ai.requests.single.prompt, contains('Apply for the job by email'));

      // Leaving without sending doesn't ask "Did you apply?".
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Did you apply?'), findsNothing);
    });
  });
}
