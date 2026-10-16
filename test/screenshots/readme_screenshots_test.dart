// Renders the README screenshots from demo data, with the app's real fonts.
// Skipped in normal test runs. To regenerate docs/screenshots:
//
//   flutter test test/screenshots --update-goldens --dart-define=README_SCREENSHOTS=true

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/core/theme/app_theme.dart';
import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/career_coach/data/career_coach.dart';
import 'package:careerly/features/company_research/data/company_researcher.dart';
import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/documents/data/career_document.dart';
import 'package:careerly/features/goals/data/goal.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/resume/data/resume_insights.dart';

import '../core/ai/fake_ai_provider.dart';
import '../features/auth/auth_test_utils.dart';
import '../features/shell/shell_test_utils.dart';

const _enabled = bool.fromEnvironment('README_SCREENSHOTS');

class _DemoAuth extends FakeAuthRepository {
  @override
  String? get currentUserName => 'Alex Rivera';

  @override
  String? get currentUserEmail => 'alex@example.com';
}

final _now = DateTime.now();

/// [days] from today at [hour], so times read naturally.
DateTime _at(int days, int hour) =>
    DateTime(_now.year, _now.month, _now.day + days, hour);

JobApplication _job(
  String id,
  String company,
  String role,
  ApplicationStatus status, {
  int daysAgo = 0,
  String? location,
  String? salary,
}) {
  final date = _now.subtract(Duration(days: daysAgo));
  return JobApplication(
    id: id,
    company: company,
    role: role,
    status: status,
    location: location,
    salary: salary,
    appliedOn: status == ApplicationStatus.saved ? null : date,
    createdAt: date,
    updatedAt: date,
  );
}

final _applications = [
  _job('a1', 'Northwind Digital', 'Product Designer',
      ApplicationStatus.interviewing,
      daysAgo: 4, location: 'Remote', salary: '₱85,000/month'),
  _job('a2', 'Sampaguita Studio', 'UI/UX Designer', ApplicationStatus.applied,
      daysAgo: 1, location: 'Makati'),
  _job('a3', 'Bluepeak Analytics', 'Product Designer', ApplicationStatus.offer,
      daysAgo: 9, location: 'Remote', salary: '₱95,000/month'),
  _job('a4', 'Harbor & Pine', 'UX Researcher', ApplicationStatus.saved,
      daysAgo: 2, location: 'BGC, Taguig'),
  _job('a5', 'Kalye Commerce', 'Design Lead', ApplicationStatus.applied,
      daysAgo: 6, location: 'Hybrid · Pasig'),
  _job('a6', 'Lumen Health', 'Visual Designer', ApplicationStatus.rejected,
      daysAgo: 20),
];

final _agenda = [
  AgendaEvent(
    id: 'e1',
    kind: AgendaEventKind.interview,
    title: 'Portfolio review',
    startsAt: _at(1, 10),
    applicationId: 'a1',
    company: 'Northwind Digital',
  ),
  AgendaEvent(
    id: 'e2',
    kind: AgendaEventKind.followUp,
    title: 'Follow up with the recruiter',
    startsAt: _at(2, 9),
    applicationId: 'a2',
    company: 'Sampaguita Studio',
  ),
  AgendaEvent(
    id: 'e3',
    kind: AgendaEventKind.deadline,
    title: 'Reply to the offer',
    startsAt: _at(4, 17),
    applicationId: 'a3',
    company: 'Bluepeak Analytics',
  ),
];

const _goals = [
  Goal(
    id: 'g1',
    title: 'Apply to jobs',
    target: 5,
    progress: 3,
    period: GoalPeriod.weekly,
  ),
  Goal(
    id: 'g2',
    title: 'Practice interviews',
    target: 2,
    progress: 2,
    period: GoalPeriod.weekly,
  ),
  Goal(
    id: 'g3',
    title: 'Reach out to my network',
    target: 8,
    progress: 2,
    period: GoalPeriod.monthly,
  ),
];

final _profile = CareerProfile(
  targetRoles: const ['Product Designer'],
  skills: const ['Figma', 'User research', 'Prototyping', 'Design systems'],
  yearsOfExperience: 3,
  resume: ResumeInsights(
    fileName: 'Alex Rivera - Resume.pdf',
    uploadedAt: _now.subtract(const Duration(days: 3)),
    headline: 'Product designer with 3 years in fintech and e-commerce',
    textDocumentId: 'resume-text',
  ),
);

const _listings = [
  JobListing(
    id: 'j1',
    title: 'Product Designer',
    company: 'Tidewater Labs',
    source: 'LinkedIn',
    applyUrl: 'https://example.com/tidewater',
    location: 'Makati, Metro Manila',
    employmentType: 'Full-time',
    salary: '₱70K–₱90K/month',
    postedLabel: '2 days ago',
    description: 'Own end-to-end product design in Figma: user research, '
        'prototyping and a shared design system for our payments app.',
  ),
  JobListing(
    id: 'j2',
    title: 'Senior Product Designer',
    company: 'Coralbay Software',
    source: 'JobStreet',
    applyUrl: 'https://example.com/coralbay',
    isRemote: true,
    employmentType: 'Full-time',
    salary: '₱110K/month',
    postedLabel: 'Today',
    description: 'Lead design for a remote team. Figma, prototyping and '
        'design systems; user research a plus.',
  ),
  JobListing(
    id: 'j3',
    title: 'UX Designer',
    company: 'Mabini Outsourcing',
    source: 'Indeed',
    applyUrl: 'https://example.com/mabini',
    location: 'Cebu City',
    employmentType: 'Contract',
    postedLabel: '1 week ago',
    description: 'Design flows for client apps. Figma required.',
  ),
];

const _coachReply = '''
{"reply": "Here's where I'd put your energy this week:\\n\\n- **Prepare for Northwind Digital.** Your portfolio review is tomorrow. Pick two case studies that show research and a measurable result.\\n- **Answer Bluepeak Analytics.** Their ₱95,000 offer is in, and the reply is due in 4 days. Decide on your counter first.\\n- **Follow up with Sampaguita Studio** in two days with a short note.\\n\\nYou're at **3 of 5** applications for this week, so two more strong fits would get you there.", "suggestions": ["Help me plan my counter-offer", "Which case studies should I show?"]}''';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/inter/Inter-$weight.ttf'));
  }
  await inter.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _pumpDemo(
  WidgetTester tester, {
  ThemeData? theme,
  AiChain? coachAi,
}) async {
  await pumpShell(
    tester,
    auth: _DemoAuth(),
    theme: theme,
    applications: FakeApplicationsRepository(_applications),
    agenda: FakeAgendaRepository(_agenda),
    goals: FakeGoalsRepository(_goals),
    discover: fakeDiscover(listings: _listings, profile: _profile),
    studio: fakeStudio(
      profile: _profile,
      documents: FakeDocumentsRepository([
        CareerDocument(
          id: 'resume-text',
          kind: DocumentKind.resume,
          title: '${CareerDocument.originalResumePrefix} · Alex Rivera - Resume.pdf',
          content: 'Alex Rivera\nProduct designer',
          createdAt: _now.subtract(const Duration(days: 3)),
        ),
      ]),
    ),
    careerCoach: coachAi == null ? null : CareerCoach(coachAi),
    // Configured, so "Research this company" shows as available.
    companyResearcher: CompanyResearcher(AiChain([FakeAiProvider('Gemini')])),
  );
  // Phone-sized at 2x keeps the images sharp but small.
  tester.view
    ..physicalSize = const Size(780, 1688)
    ..devicePixelRatio = 2;
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip(name));
  await tester.pumpAndSettle();
}

Future<void> _shoot(String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );

/// A screenshot test with soft shadows, as on a phone. Tests draw them as
/// hard outlines by default.
void _screenshot(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(_loadFonts);

  group('README screenshots', skip: !_enabled, () {
    _screenshot('home', (tester) async {
      await _pumpDemo(tester);
      await _shoot('home');
    });

    _screenshot('home, dark', (tester) async {
      await _pumpDemo(tester, theme: AppTheme.dark);
      await _shoot('home_dark');
    });

    _screenshot('jobs', (tester) async {
      await _pumpDemo(tester);
      await _openTab(tester, 'Jobs');
      await _shoot('jobs');
    });

    _screenshot('discover', (tester) async {
      await _pumpDemo(tester);
      await _openTab(tester, 'Jobs');
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Search "Product Designer"'));
      // Start the shot at the Tracked / Discover switch.
      final tabs = tester.element(find.text('Tracked'));
      await Scrollable.ensureVisible(tabs);
      final list = Scrollable.of(tabs).position;
      list.jumpTo(list.pixels - 24);
      await tester.pumpAndSettle();
      await _shoot('discover');

      await tester.tap(find.text('Senior Product Designer'));
      await tester.pumpAndSettle();
      await _shoot('job_detail');
    });

    _screenshot('agenda', (tester) async {
      await _pumpDemo(tester);
      await _openTab(tester, 'Agenda');
      await _shoot('agenda');
    });

    _screenshot('goals', (tester) async {
      await _pumpDemo(tester);
      await _openTab(tester, 'Goals');
      await _shoot('goals');
    });

    _screenshot('studio', (tester) async {
      await _pumpDemo(tester);
      await _openTab(tester, 'Studio');
      await _shoot('studio');
    });

    _screenshot('career coach', (tester) async {
      await _pumpDemo(
        tester,
        coachAi: AiChain([FakeAiProvider('Gemini', reply: _coachReply)]),
      );
      await _openTab(tester, 'Studio');
      await tester.tap(find.text('Ask your career coach'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'What should I focus on this week?',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      // Show the whole reply, from the question down.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _shoot('career_coach');
    });
  });
}
