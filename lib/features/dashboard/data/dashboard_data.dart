import '../../../core/utils/date_utils.dart';
import '../../agenda/data/agenda_event.dart';
import '../../applications/data/job_application.dart';
import '../../goals/data/goal.dart';

/// Everything the dashboard shows, plus the numbers derived from it.
class DashboardData {
  const DashboardData({
    required this.applications,
    required this.upcoming,
    required this.goals,
  });

  final List<JobApplication> applications;
  final List<AgendaEvent> upcoming;
  final List<Goal> goals;

  bool get isEmpty => applications.isEmpty && upcoming.isEmpty && goals.isEmpty;

  int countWith(ApplicationStatus status) =>
      applications.where((a) => a.status == status).length;

  /// Applications sent since Monday.
  int appliedThisWeek([DateTime? now]) {
    final weekStart = (now ?? DateTime.now()).startOfWeek;
    return applications
        .where((a) => a.appliedOn != null && !a.appliedOn!.isBefore(weekStart))
        .length;
  }

  /// Interviews in the next 7 days.
  int interviewsNextWeek([DateTime? now]) {
    final until = (now ?? DateTime.now()).add(const Duration(days: 7));
    return upcoming
        .where(
          (e) => e.kind == AgendaEventKind.interview && e.startsAt.isBefore(until),
        )
        .length;
  }

  DashboardData copyWith({
    List<JobApplication>? applications,
    List<AgendaEvent>? upcoming,
    List<Goal>? goals,
  }) =>
      DashboardData(
        applications: applications ?? this.applications,
        upcoming: upcoming ?? this.upcoming,
        goals: goals ?? this.goals,
      );
}
