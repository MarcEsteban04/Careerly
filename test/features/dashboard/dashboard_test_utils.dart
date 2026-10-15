import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/core/theme/app_theme.dart';
import 'package:careerly/features/agenda/data/agenda_event.dart';
import 'package:careerly/features/agenda/data/agenda_repository.dart';
import 'package:careerly/features/applications/data/applications_repository.dart';
import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/auth/data/app_lock_repository.dart';
import 'package:careerly/features/dashboard/presentation/dashboard_screen.dart';
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
  }) {
    final date = now.subtract(Duration(days: daysAgo));
    return JobApplication(
      id: id,
      company: company,
      role: role,
      status: status,
      location: location,
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
          daysAgo: 9, location: 'Remote'),
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

Future<void> pumpDashboard(
  WidgetTester tester, {
  required FakeApplicationsRepository applications,
  FakeAgendaRepository? agenda,
  FakeGoalsRepository? goals,
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
      home: DashboardScreen(
        authRepository: FakeDashboardAuth(),
        appLock: FakeAppLock(),
        applications: applications,
        agenda: agenda ?? FakeAgendaRepository(),
        goals: goals ?? FakeGoalsRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
