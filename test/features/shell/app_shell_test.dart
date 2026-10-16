import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/core/widgets/pill_chip.dart';
import 'package:careerly/core/widgets/user_avatar.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/applications/data/application_event.dart';
import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/documents/data/career_document.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/resume/data/resume_insights.dart';
import 'package:careerly/features/shell/data/workspace_data.dart';

import '../../core/ai/fake_ai_provider.dart';
import 'shell_test_utils.dart';

void main() {
  Future<({FakeApplicationsRepository applications, FakeGoalsRepository goals})>
  pumpWithSample(WidgetTester tester) async {
    final sample = sampleDashboardData(DateTime.now());
    final applications = FakeApplicationsRepository(sample.applications);
    final goals = FakeGoalsRepository(sample.goals);
    await pumpShell(
      tester,
      applications: applications,
      agenda: FakeAgendaRepository(sample.agenda),
      goals: goals,
    );
    return (applications: applications, goals: goals);
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(PillChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip(name));
    await tester.pumpAndSettle();
  }

  group('dashboard', () {
    testWidgets('empty account shows friendly empty states', (tester) async {
      await pumpShell(tester, applications: FakeApplicationsRepository());

      expect(find.text('Marc Esteban'), findsOneWidget);
      expect(find.textContaining('big move'), findsOneWidget);
      expect(find.text("You're all clear"), findsOneWidget);
      expect(find.text('No applications yet'), findsOneWidget);
    });

    testWidgets('spotlights the next event and lists applications', (
      tester,
    ) async {
      await pumpWithSample(tester);

      expect(find.text('Portfolio review'), findsOneWidget);
      expect(find.textContaining('NEXT UP'), findsOneWidget);
      expect(find.text('Product Designer'), findsWidgets);
      // The interview linked to Linear is flagged on its card.
      expect(find.textContaining('INTERVIEW · TODAY'), findsOneWidget);
    });

    testWidgets('category chips filter the list', (tester) async {
      await pumpWithSample(tester);

      await tapChip(tester, 'Offer');

      expect(find.text('Design Engineer'), findsOneWidget);
      expect(find.text('Senior UI Designer'), findsNothing);
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

      await openTab(tester, 'Jobs');
      expect(find.text('6 roles tracked'), findsOneWidget);

      await openTab(tester, 'Agenda');
      expect(find.text('3 things coming up'), findsOneWidget);

      await openTab(tester, 'Goals');
      expect(find.text('1 of 2 complete'), findsOneWidget);
    });

    testWidgets('search on the Jobs tab filters by text', (tester) async {
      await pumpWithSample(tester);
      await openTab(tester, 'Jobs');

      await tester.enterText(find.byType(TextField), 'figma');
      await tester.pumpAndSettle();

      expect(find.text('Design Engineer'), findsOneWidget);
      expect(find.text('Senior UI Designer'), findsNothing);
    });

    testWidgets('+ on the Jobs tab opens the application form', (tester) async {
      await pumpWithSample(tester);
      await openTab(tester, 'Jobs');

      await tester.tap(find.byTooltip('New application'));
      await tester.pumpAndSettle();

      expect(find.text('Save application'), findsOneWidget);
    });

    testWidgets('+ on Home offers what to add', (tester) async {
      await pumpWithSample(tester);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Interview or reminder'), findsOneWidget);
    });
  });

  group('goals', () {
    testWidgets('logging progress updates it immediately', (tester) async {
      final fakes = await pumpWithSample(tester);
      await openTab(tester, 'Goals');

      await tester.tap(find.byTooltip('Log progress'));
      await tester.pumpAndSettle();

      expect(find.text('4 of 5 · This week'), findsOneWidget);
      expect(fakes.goals.progress['g1'], 4);
    });
  });

  group('application detail', () {
    Future<void> openFigma(WidgetTester tester) async {
      await tapChip(tester, 'Offer');
      await tester.tap(find.text('Design Engineer'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the role with progress and details', (tester) async {
      await pumpWithSample(tester);
      await openFigma(tester);

      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text(r'$6,500/month'), findsWidgets);
      expect(find.text('Update status'), findsOneWidget);
    });

    testWidgets('updates the status', (tester) async {
      await pumpWithSample(tester);
      await openFigma(tester);

      await tester.tap(find.text('Update status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rejected').last);
      await tester.pumpAndSettle();

      expect(find.text('Moved to Rejected'), findsOneWidget);
      expect(find.text('This application is closed.'), findsOneWidget);
    });

    testWidgets('deletes after confirmation', (tester) async {
      final fakes = await pumpWithSample(tester);
      await openFigma(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fakes.applications.deleted, ['a3']);
      expect(find.text('Application'), findsNothing);
      expect(find.text('Deleted Design Engineer'), findsOneWidget);
    });
  });

  group('discover', () {
    Future<FakeApplicationsRepository> pumpDiscover(
      WidgetTester tester, {
      CareerProfile profile = const CareerProfile(
        targetRoles: ['UI Designer'],
        skills: ['Figma', 'User research'],
      ),
    }) async {
      final applications = FakeApplicationsRepository();
      await pumpShell(
        tester,
        applications: applications,
        discover: fakeDiscover(listings: sampleListings, profile: profile),
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      return applications;
    }

    testWidgets('searches the profile role and ranks by match', (tester) async {
      await pumpDiscover(tester);

      expect(find.text('Find jobs that fit you'), findsOneWidget);
      await tapVisible(tester, find.text('Search "UI Designer"'));

      expect(find.textContaining('2 jobs for "UI Designer"'), findsOneWidget);
      final designer = tester.getTopLeft(find.text('UI/UX Designer')).dy;
      final backend = tester.getTopLeft(find.text('Backend Engineer')).dy;
      expect(designer, lessThan(backend));
      expect(find.textContaining('% MATCH'), findsNWidgets(2));
    });

    testWidgets('explains the match and warns about scams', (tester) async {
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(
          listings: [
            ...sampleListings,
            const JobListing(
              id: 'scam',
              title: 'Online Encoder',
              company: 'Quick Hire',
              source: 'Facebook',
              applyUrl: 'https://example.com/scam',
              description: 'Pay the registration fee via GCash to start.',
            ),
          ],
          profile: const CareerProfile(
            targetRoles: ['UI Designer'],
            skills: ['Figma'],
          ),
        ),
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Search "UI Designer"'));

      expect(find.text('Possible scam'), findsOneWidget);
      expect(find.textContaining('Fits “UI Designer”'), findsOneWidget);

      await tapVisible(tester, find.text('UI/UX Designer'));
      await tester.tap(find.text('Match'));
      await tester.pumpAndSettle();
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('45 / 45'), findsOneWidget);
      expect(find.text('Work setup'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await Scrollable.ensureVisible(
        tester.element(find.text('Online Encoder')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online Encoder'));
      await tester.pumpAndSettle();
      expect(find.text('This post has signs of a scam'), findsOneWidget);
    });

    testWidgets('searches a country abroad', (tester) async {
      final discover = fakeDiscover(
        listings: sampleListings,
        profile: const CareerProfile(targetRoles: ['UI Designer']),
      );
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: discover,
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tapChip(tester, 'Abroad');
      expect(find.text('Search jobs abroad'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'jap');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Japan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Japan'), findsOneWidget);
      await tapVisible(tester, find.text('Search "UI Designer"'));
      final query = (discover.jsearch as FakeJSearchClient).queries.last;
      expect(query.scope.country?.code, 'jp');
    });

    testWidgets('asks for a profile when there is none', (tester) async {
      await pumpDiscover(tester, profile: const CareerProfile());

      expect(find.text('Set up your career profile'), findsOneWidget);
      await tapVisible(tester, find.text('Set up profile'));
      expect(find.text('Career profile'), findsOneWidget);
    });

    testWidgets('saves a job to the tracker from its detail page', (
      tester,
    ) async {
      final applications = await pumpDiscover(tester);
      await tapVisible(tester, find.text('Search "UI Designer"'));

      await tapVisible(tester, find.text('UI/UX Designer'));
      expect(find.text('Job Detail'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cover letter'), findsOneWidget);

      await tester.tap(find.byTooltip('Save to tracker'));
      await tester.pumpAndSettle();

      expect(applications.items.single.role, 'UI/UX Designer');
      expect(applications.items.single.status, ApplicationStatus.saved);
      expect(find.byTooltip('Saved to tracker'), findsOneWidget);
    });
  });

  group('studio', () {
    testWidgets('asks for a resume before writing', (tester) async {
      await pumpShell(tester, applications: FakeApplicationsRepository());
      await openTab(tester, 'Studio');

      expect(find.text('Add your resume'), findsOneWidget);
      await tester.tap(find.text('Enhance resume'));
      await tester.pumpAndSettle();
      expect(find.text('Upload your resume first'), findsOneWidget);
    });

    testWidgets('enhances the resume and saves it to Studio', (tester) async {
      final profile = CareerProfile(
        targetRoles: const ['UI Designer'],
        resume: ResumeInsights(
          fileName: 'cv.pdf',
          uploadedAt: DateTime(2026, 10, 1),
          textDocumentId: 'orig',
        ),
      );
      final documents = FakeDocumentsRepository([
        CareerDocument(
          id: 'orig',
          kind: DocumentKind.resume,
          title: '${CareerDocument.originalResumePrefix} · cv.pdf',
          content: 'Maria Santos — designer',
          createdAt: DateTime(2026, 10, 1),
        ),
      ]);
      final ai = FakeAiProvider(
        'Gemini',
        reply:
            '{"resume": "# Maria Santos\\n## Summary\\nUI designer who '
            'ships.", "changes": ["Sharper summary"]}',
      );
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(profile: profile),
        studio: fakeStudio(
          profile: profile,
          documents: documents,
          ai: AiChain([ai]),
        ),
      );
      await openTab(tester, 'Studio');
      // On the resume card and as the original version.
      expect(find.text('cv.pdf'), findsNWidgets(2));

      await tester.tap(find.text('Enhance resume'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enhance with AI'));
      await tester.pumpAndSettle();

      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Sharper summary'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);

      await tester.tap(find.text('Save to Studio'));
      await tester.pumpAndSettle();
      expect(documents.docs.first.title, 'Resume · UI Designer');

      // The PDF button offers viewing in the app or downloading. (Wait for
      // the "Saved" snackbar over the button to go.)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      expect(find.text('View PDF'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Resume · UI Designer'), findsOneWidget);
    });

    testWidgets('resume versions show results and run an ATS check', (
      tester,
    ) async {
      final day = DateTime(2026, 10, 1);
      final profile = CareerProfile(
        targetRoles: const ['UI Designer'],
        resume: ResumeInsights(
          fileName: 'cv.pdf',
          uploadedAt: day,
          textDocumentId: 'orig',
        ),
      );
      final documents = FakeDocumentsRepository([
        CareerDocument(
          id: 'orig',
          kind: DocumentKind.resume,
          title: '${CareerDocument.originalResumePrefix} · cv.pdf',
          content: '# Maria Santos\n## Experience\n- Designed 4 apps in Figma.',
          createdAt: day,
        ),
      ]);
      final applications = FakeApplicationsRepository([
        JobApplication(
          id: 'a1',
          company: 'Globex',
          role: 'UI Designer',
          status: ApplicationStatus.interviewing,
          resumeDocumentId: 'orig',
          createdAt: day,
          updatedAt: day,
        ),
      ]);
      await pumpShell(
        tester,
        applications: applications,
        discover: fakeDiscover(profile: profile),
        studio: fakeStudio(profile: profile, documents: documents),
      );
      await openTab(tester, 'Studio');

      final stats = find.text('Original upload · Sent once · 1 interview');
      await Scrollable.ensureVisible(tester.element(stats), alignment: 0.4);
      await tester.pumpAndSettle();
      expect(find.text('Best performer'), findsOneWidget);

      await tester.tap(stats);
      await tester.pumpAndSettle();
      expect(find.text('Check against which job?'), findsOneWidget);
      await tester.tap(find.text('UI Designer').last);
      await tester.pumpAndSettle();

      expect(find.text('ATS check'), findsOneWidget);
      expect(find.text('Standard sections'), findsOneWidget);
      expect(find.text('Tailor a version with AI'), findsOneWidget);
    });
  });

  group('apply flow', () {
    testWidgets('applies to a discovered job and sets a follow-up', (
      tester,
    ) async {
      final applications = FakeApplicationsRepository();
      final agenda = FakeAgendaRepository();
      Uri? opened;
      await pumpShell(
        tester,
        applications: applications,
        agenda: agenda,
        discover: fakeDiscover(
          listings: sampleListings,
          profile: const CareerProfile(targetRoles: ['UI Designer']),
        ),
        openUrl: (url) async {
          opened = url;
          return true;
        },
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Search "UI Designer"'));
      await tapVisible(tester, find.text('UI/UX Designer'));

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Your application kit'), findsOneWidget);
      await tester.tap(find.text('Open application page'));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://example.com/acme');

      // Coming back to the app asks whether they applied.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Did you apply?'), findsOneWidget);
      await tester.tap(find.text('Yes, I applied'));
      await tester.pumpAndSettle();

      final applied = applications.items.single;
      expect(applied.status, ApplicationStatus.applied);
      expect(applied.source, 'LinkedIn');
      expect(applied.externalId, 'j1');
      expect(applied.followUpOn, isNotNull);
      expect(agenda.created.single.kind, AgendaEventKind.followUp);
      expect(agenda.created.single.applicationId, applied.id);
    });

    testWidgets('"Not yet" leaves the job untracked', (tester) async {
      final applications = FakeApplicationsRepository();
      await pumpShell(
        tester,
        applications: applications,
        discover: fakeDiscover(
          listings: sampleListings,
          profile: const CareerProfile(targetRoles: ['UI Designer']),
        ),
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Search "UI Designer"'));
      await tapVisible(tester, find.text('UI/UX Designer'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open application page'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();

      expect(applications.items, isEmpty);
    });
  });

  group('job finding', () {
    Future<FakePreferencesRepository> searchDesigner(
      WidgetTester tester,
    ) async {
      final preferences = FakePreferencesRepository();
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(
          listings: sampleListings,
          profile: const CareerProfile(targetRoles: ['UI Designer']),
          preferences: preferences,
        ),
      );
      await openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Search "UI Designer"'));
      return preferences;
    }

    testWidgets('saves the current search', (tester) async {
      final preferences = await searchDesigner(tester);

      await tester.tap(find.byTooltip('Save this search'));
      await tester.pumpAndSettle();

      expect(preferences.saved.single.keywords, 'UI Designer');
      expect(find.byTooltip('Remove saved search'), findsOneWidget);
    });

    testWidgets('swiping hides a job, with undo', (tester) async {
      final preferences = await searchDesigner(tester);

      await Scrollable.ensureVisible(
        tester.element(find.text('Backend Engineer')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Backend Engineer'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Backend Engineer'), findsNothing);
      expect(preferences.dismissed, isNotEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Backend Engineer'), findsOneWidget);
      expect(preferences.dismissed, isEmpty);
    });
  });

  group('tracked board and bulk actions', () {
    Future<FakeApplicationsRepository> openTracked(WidgetTester tester) async {
      final fakes = await pumpWithSample(tester);
      await openTab(tester, 'Jobs');
      return fakes.applications;
    }

    testWidgets('the board moves a job with its move button, with undo', (
      tester,
    ) async {
      final applications = await openTracked(tester);
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();

      expect(find.text('Saved'), findsWidgets);
      await tester.tap(find.byTooltip('Move UX Designer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interviewing').last);
      await tester.pumpAndSettle();

      expect(applications.statusChanges.last, (
        'a4',
        ApplicationStatus.interviewing,
      ));
      expect(find.text('UX Designer moved to Interviewing'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(applications.statusChanges.last, ('a4', ApplicationStatus.saved));
    });

    testWidgets('the board moves a job by drag and drop', (tester) async {
      final applications = await openTracked(tester);
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();

      final card = find.text('UX Designer');
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      // Into the Applied column, the second one: it starts after the first
      // column (264 wide) and a 12 gap, inside the 24 page padding. Stay
      // clear of the right edge, where the board auto-scrolls.
      final appliedHeader = tester.getTopLeft(find.text('Applied').first);
      await gesture.moveTo(Offset(320, appliedHeader.dy + 60));
      await tester.pump();
      await gesture.moveTo(Offset(322, appliedHeader.dy + 64));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(applications.statusChanges.single, (
        'a4',
        ApplicationStatus.applied,
      ));
    });

    testWidgets('long-press selects jobs to move or delete together', (
      tester,
    ) async {
      final applications = await openTracked(tester);

      await Scrollable.ensureVisible(
        tester.element(find.text('Design Engineer')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Design Engineer'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('UX Designer')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('UX Designer'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Move to…'));
      await tester.pumpAndSettle();
      expect(find.text('Move 2 to…'), findsOneWidget);
      await tester.tap(find.text('Rejected').last);
      await tester.pumpAndSettle();
      expect(
        applications.statusChanges,
        unorderedEquals([
          ('a3', ApplicationStatus.rejected),
          ('a4', ApplicationStatus.rejected),
        ]),
      );
      expect(find.text('Moved 2 to Rejected'), findsOneWidget);

      await Scrollable.ensureVisible(
        tester.element(find.text('Design Engineer')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Design Engineer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 1 application?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(applications.deleted, ['a3']);
    });

    testWidgets('sort and filter', (tester) async {
      await openTracked(tester);

      await tester.ensureVisible(find.text('Recently updated'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recently updated'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Company A–Z'));
      await tester.pumpAndSettle();
      final airbnb = tester.getTopLeft(find.text('Design Systems')).dy;
      final stripe = tester.getTopLeft(find.text('Product Designer').last).dy;
      expect(airbnb, lessThan(stripe));

      await tester.ensureVisible(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remote only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Filter · 1'), findsOneWidget);
      expect(find.text('Design Engineer'), findsOneWidget);
      expect(find.text('Senior UI Designer'), findsNothing);
    });
  });

  group('tracking', () {
    testWidgets('timeline shows status history', (tester) async {
      final sample = sampleDashboardData(DateTime.now());
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        events: FakeEventsRepository([
          ApplicationEvent(
            id: 'e2',
            kind: ApplicationEventKind.statusChanged,
            fromStatus: ApplicationStatus.applied,
            toStatus: ApplicationStatus.offer,
            createdAt: DateTime(2026, 10, 10),
          ),
          ApplicationEvent(
            id: 'e1',
            kind: ApplicationEventKind.created,
            toStatus: ApplicationStatus.applied,
            createdAt: DateTime(2026, 10, 1),
          ),
        ]),
      );
      await tapChip(tester, 'Offer');
      await tester.tap(find.text('Design Engineer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Moved from Applied to Offer'), findsOneWidget);
      expect(find.text('Added as Applied'), findsOneWidget);
    });

    testWidgets('swiping an agenda item deletes it after confirming', (
      tester,
    ) async {
      final sample = sampleDashboardData(DateTime.now());
      final agenda = FakeAgendaRepository(sample.agenda);
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(sample.applications),
        agenda: agenda,
      );
      await openTab(tester, 'Agenda');

      await tester.drag(
        find.text('Email the recruiter'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(agenda.deleted, ['e2']);
      expect(find.text('Email the recruiter'), findsNothing);
    });
  });

  group('profile', () {
    Future<void> openProfile(WidgetTester tester, CareerProfile profile) async {
      await pumpShell(
        tester,
        applications: FakeApplicationsRepository(),
        discover: fakeDiscover(profile: profile),
      );
      await tester.tap(find.byType(UserAvatar).first);
      await tester.pumpAndSettle();
    }

    testWidgets('prompts to set up the career profile', (tester) async {
      await openProfile(tester, const CareerProfile());

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('me@careerly.app'), findsOneWidget);
      expect(find.text('No resume yet'), findsOneWidget);
      expect(find.text('Biometric unlock'), findsOneWidget);

      await tester.tap(find.text('Set up your career profile'));
      await tester.pumpAndSettle();
      expect(find.text('Career profile'), findsWidgets);
    });

    testWidgets('summarizes a filled-in profile', (tester) async {
      await openProfile(
        tester,
        const CareerProfile(
          targetRoles: ['UI Designer'],
          skills: ['Figma'],
          yearsOfExperience: 3,
          location: 'Manila',
          workSetup: WorkSetup.remote,
        ),
      );

      expect(find.text('UI Designer'), findsOneWidget);
      expect(find.text('Figma'), findsOneWidget);
      expect(find.text('3 years'), findsOneWidget);
      expect(find.text('Manila'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows every skill on request', (tester) async {
      await openProfile(
        tester,
        CareerProfile(
          targetRoles: const ['Web Developer'],
          skills: [for (var i = 1; i <= 15; i++) 'Skill $i'],
        ),
      );

      expect(find.text('Skill 15'), findsNothing);
      await tester.tap(find.text('+3 more'));
      await tester.pumpAndSettle();

      expect(find.text('Skill 15'), findsOneWidget);
      // Expanding doesn't open the editor.
      expect(find.text('Career profile'), findsOneWidget);
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Skill 15'), findsNothing);
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
    expect(data.interviewsNextWeek(now), 1);
    expect(data.nextEvent?.title, 'Portfolio review');
    expect(data.nextEventFor('a1')?.title, 'Portfolio review');
    expect(data.nextEventFor('a2'), isNull);
  });
}
