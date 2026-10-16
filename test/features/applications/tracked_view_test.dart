import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/applications/data/job_application.dart';
import 'package:careerly/features/applications/data/tracked_view.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);

  JobApplication app(
    String id, {
    String company = 'Acme',
    ApplicationStatus status = ApplicationStatus.applied,
    String? location,
    String? salary,
    DateTime? followUpOn,
    int updatedDaysAgo = 0,
    int createdDaysAgo = 0,
  }) =>
      JobApplication(
        id: id,
        company: company,
        role: 'Developer',
        status: status,
        location: location,
        salary: salary,
        followUpOn: followUpOn,
        createdAt: now.subtract(Duration(days: createdDaysAgo)),
        updatedAt: now.subtract(Duration(days: updatedDaysAgo)),
      );

  final apps = [
    app('a', company: 'Zeta', salary: '₱30,000/month', updatedDaysAgo: 1,
        createdDaysAgo: 9),
    app('b', company: 'alpha', salary: r'$2,000/month', location: 'Remote',
        updatedDaysAgo: 5, createdDaysAgo: 1, followUpOn: DateTime(2026, 10, 25)),
    app('c', company: 'Mid', updatedDaysAgo: 3, createdDaysAgo: 5,
        followUpOn: DateTime(2026, 10, 19), status: ApplicationStatus.rejected),
  ];

  List<String> ids(TrackedViewController view, {ApplicationStatus? status}) =>
      view.apply(apps, status: status, now: now).map((a) => a.id).toList();

  test('sorts five ways', () {
    final view = TrackedViewController();
    expect(ids(view), ['a', 'c', 'b']);

    view.setSort(TrackedSort.added);
    expect(ids(view), ['b', 'c', 'a']);

    view.setSort(TrackedSort.followUp);
    expect(ids(view), ['c', 'b', 'a']);

    view.setSort(TrackedSort.salary);
    // $2,000 ≈ ₱114,000 beats ₱30,000; no salary last.
    expect(ids(view), ['b', 'a', 'c']);

    view.setSort(TrackedSort.company);
    expect(ids(view), ['b', 'c', 'a']);
  });

  test('filters remote, follow-up due and closed', () {
    final view = TrackedViewController()..setFilters(remoteOnly: true);
    expect(ids(view), ['b']);
    expect(view.activeFilterCount, 1);

    view
      ..clearFilters()
      ..setFilters(followUpDue: true);
    expect(ids(view), ['c']);

    view
      ..clearFilters()
      ..setFilters(hideClosed: true);
    expect(ids(view), ['a', 'b']);
    expect(ids(view, status: ApplicationStatus.applied), ['a', 'b']);
  });

  test('selection toggles and clears when switching to the board', () {
    final view = TrackedViewController()
      ..toggleSelected('a')
      ..toggleSelected('b')
      ..toggleSelected('a');
    expect(view.selected, {'b'});
    expect(view.isSelecting, isTrue);

    view.setLayout(TrackedLayout.board);
    expect(view.isSelecting, isFalse);
  });
}
