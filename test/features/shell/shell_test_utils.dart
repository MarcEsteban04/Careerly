import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/theme/app_theme.dart';
import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/agenda/data/agenda_repository.dart';
import 'package:careerly/features/applications/data/applications_repository.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/auth/data/app_lock_repository.dart';
import 'package:careerly/core/ai/ai_chain.dart';
import 'package:careerly/features/discover/data/discover_controller.dart';
import 'package:careerly/features/documents/data/career_document.dart';
import 'package:careerly/features/documents/data/documents_repository.dart';
import 'package:careerly/features/studio/data/career_writer.dart';
import 'package:careerly/features/studio/data/studio_controller.dart';
import 'package:careerly/features/discover/data/job_listing.dart';
import 'package:careerly/features/discover/data/job_search_query.dart';
import 'package:careerly/features/discover/data/jooble_client.dart';
import 'package:careerly/features/discover/data/jsearch_client.dart';
import 'package:careerly/features/profile/data/career_profile.dart';
import 'package:careerly/features/profile/data/career_profile_repository.dart';
import 'package:careerly/features/shell/presentation/app_shell.dart';
import 'package:careerly/features/goals/data/goal.dart';
import 'package:careerly/features/goals/data/goals_repository.dart';

import '../auth/auth_test_utils.dart';

class FakeApplicationsRepository implements ApplicationsRepository {
  FakeApplicationsRepository([this.items = const []]);

  List<JobApplication> items;
  Object? error;

  @override
  Future<List<JobApplication>> fetchAll() async {
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<JobApplication> updateStatus(
    JobApplication application,
    ApplicationStatus status,
  ) async =>
      JobApplication(
        id: application.id,
        company: application.company,
        role: application.role,
        status: status,
        location: application.location,
        appliedOn: application.appliedOn ?? DateTime.now(),
        createdAt: application.createdAt,
        updatedAt: DateTime.now(),
      );

  final deleted = <String>[];

  @override
  Future<JobApplication> create({
    required String company,
    required String role,
    required ApplicationStatus status,
    String? location,
    String? jobUrl,
    String? salary,
    DateTime? appliedOn,
  }) async {
    final created = JobApplication(
      id: 'new-${items.length}',
      company: company,
      role: role,
      status: status,
      location: location,
      jobUrl: jobUrl,
      salary: salary,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    items = [created, ...items];
    return created;
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAgendaRepository implements AgendaRepository {
  FakeAgendaRepository([this.items = const []]);

  List<AgendaEvent> items;
  final done = <String>{};

  @override
  Future<List<AgendaEvent>> fetchUpcoming({int limit = 20}) async => items;

  @override
  Future<void> setDone(String id, {required bool isDone}) async =>
      isDone ? done.add(id) : done.remove(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoalsRepository implements GoalsRepository {
  FakeGoalsRepository([this.items = const []]);

  List<Goal> items;
  final progress = <String, int>{};

  @override
  Future<List<Goal>> fetchAll() async => items;

  @override
  Future<void> setProgress(String id, int value) async => progress[id] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAppLock implements AppLockRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDashboardAuth extends FakeAuthRepository {
  @override
  String? get currentUserName => 'Marc Esteban';

  @override
  String? get currentUserEmail => 'me@careerly.app';
}

/// Realistic sample data, relative to [now].
({
  List<JobApplication> applications,
  List<AgendaEvent> agenda,
  List<Goal> goals,
}) sampleDashboardData(DateTime now) {
  JobApplication app(
    String id,
    String company,
    String role,
    ApplicationStatus status, {
    int daysAgo = 0,
    String? location,
    String? salary,
  }) {
    final date = now.subtract(Duration(days: daysAgo));
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

  return (
    applications: [
      app('a1', 'Linear', 'Product Designer', ApplicationStatus.interviewing,
          location: 'Remote'),
      app('a2', 'Canva', 'Senior UI Designer', ApplicationStatus.applied,
          daysAgo: 1, location: 'Manila'),
      app('a3', 'Figma', 'Design Engineer', ApplicationStatus.offer,
          daysAgo: 9, location: 'Remote', salary: r'$6,500/month'),
      app('a4', 'Notion', 'UX Designer', ApplicationStatus.saved, daysAgo: 2),
      app('a5', 'Stripe', 'Product Designer', ApplicationStatus.applied,
          daysAgo: 12),
      app('a6', 'Airbnb', 'Design Systems', ApplicationStatus.rejected,
          daysAgo: 20),
    ],
    agenda: [
      AgendaEvent(
        id: 'e1',
        kind: AgendaEventKind.interview,
        title: 'Portfolio review',
        startsAt: DateTime(now.year, now.month, now.day, 23, 30),
        applicationId: 'a1',
        company: 'Linear',
      ),
      AgendaEvent(
        id: 'e2',
        kind: AgendaEventKind.followUp,
        title: 'Email the recruiter',
        startsAt: now.add(const Duration(days: 1)),
        company: 'Canva',
      ),
      AgendaEvent(
        id: 'e3',
        kind: AgendaEventKind.deadline,
        title: 'Submit take-home task',
        startsAt: now.add(const Duration(days: 3)),
      ),
    ],
    goals: const [
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
    ],
  );
}

Future<void> pumpShell(
  WidgetTester tester, {
  required FakeApplicationsRepository applications,
  FakeAgendaRepository? agenda,
  FakeGoalsRepository? goals,
  DiscoverController? discover,
  StudioController? studio,
  ThemeData? theme,
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: AppShell(
        authRepository: FakeDashboardAuth(),
        appLock: FakeAppLock(),
        applications: applications,
        agenda: agenda ?? FakeAgendaRepository(),
        goals: goals ?? FakeGoalsRepository(),
        discover: discover ?? fakeDiscover(),
        studio: studio ?? fakeStudio(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class FakeJSearchClient extends JSearchClient {
  FakeJSearchClient([this.listings = const []]) : super(apiKey: 'test');

  final List<JobListing> listings;
  final queries = <JobSearchQuery>[];

  @override
  Future<List<JobListing>> search(JobSearchQuery query) async {
    queries.add(query);
    return listings;
  }
}

class FakeCareerProfileRepository implements CareerProfileRepository {
  FakeCareerProfileRepository([this.profile = const CareerProfile()]);

  CareerProfile profile;

  @override
  CareerProfile read() => profile;

  @override
  Future<CareerProfile> save(CareerProfile profile) async =>
      this.profile = profile;
}

DiscoverController fakeDiscover({
  List<JobListing> listings = const [],
  CareerProfile profile = const CareerProfile(),
}) =>
    DiscoverController(
      jsearch: FakeJSearchClient(listings),
      jooble: JoobleClient(apiKey: ''),
      profiles: FakeCareerProfileRepository(profile),
    );

const sampleListings = [
  JobListing(
    id: 'j1',
    title: 'UI/UX Designer',
    company: 'Acme PH',
    source: 'LinkedIn',
    applyUrl: 'https://example.com/acme',
    location: 'Makati, Metro Manila',
    employmentType: 'Full-time',
    salary: '₱50K/month',
    description: 'We need a designer fluent in Figma and user research.',
  ),
  JobListing(
    id: 'j2',
    title: 'Backend Engineer',
    company: 'Globex',
    source: 'Indeed',
    applyUrl: 'https://example.com/globex',
    isRemote: true,
    description: 'Go and Postgres services.',
  ),
];

class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository([List<CareerDocument>? docs]) : docs = docs ?? [];

  final List<CareerDocument> docs;

  @override
  Future<List<CareerDocument>> fetchAll() async => List.of(docs);

  @override
  Future<CareerDocument?> fetch(String id) async {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<CareerDocument> create({
    required DocumentKind kind,
    required String title,
    required String content,
    String? applicationId,
  }) async {
    final doc = CareerDocument(
      id: 'doc-${docs.length}',
      kind: kind,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      applicationId: applicationId,
    );
    docs.insert(0, doc);
    return doc;
  }

  @override
  Future<CareerDocument> update(String id, {String? title, String? content}) async {
    final i = docs.indexWhere((d) => d.id == id);
    return docs[i] = docs[i].copyWith(title: title, content: content);
  }

  @override
  Future<void> delete(String id) async => docs.removeWhere((d) => d.id == id);
}

StudioController fakeStudio({
  CareerProfile profile = const CareerProfile(),
  FakeDocumentsRepository? documents,
  AiChain? ai,
}) =>
    StudioController(
      documents: documents ?? FakeDocumentsRepository(),
      writer: CareerWriter(ai ?? AiChain([])),
      profile: () => profile,
    );
