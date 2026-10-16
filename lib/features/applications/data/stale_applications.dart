import 'job_application.dart';

/// Applications that have gone quiet: applied with no news for 3 weeks, or
/// interviewing with no update for 2. A follow-up date in the future
/// ("wait a week") holds one back until then.
abstract final class StaleApplications {
  static const appliedQuietDays = 21;
  static const interviewQuietDays = 14;

  static List<JobApplication> find(
    Iterable<JobApplication> applications, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final stale = [
      for (final application in applications)
        if (_isStale(application, current, today)) application,
    ]..sort((a, b) => quietDays(b, now: current).compareTo(quietDays(a, now: current)));
    return stale;
  }

  /// Days since anything happened on [application].
  static int quietDays(JobApplication application, {DateTime? now}) {
    final applied = application.appliedOn;
    final last = applied != null && applied.isAfter(application.updatedAt)
        ? applied
        : application.updatedAt;
    return (now ?? DateTime.now()).difference(last).inDays;
  }

  static bool _isStale(JobApplication a, DateTime now, DateTime today) {
    final waitUntil = a.followUpOn;
    if (waitUntil != null && waitUntil.isAfter(today)) return false;
    final limit = switch (a.status) {
      ApplicationStatus.applied => appliedQuietDays,
      ApplicationStatus.interviewing => interviewQuietDays,
      _ => null,
    };
    return limit != null && quietDays(a, now: now) >= limit;
  }
}
