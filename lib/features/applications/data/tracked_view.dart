import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/salary.dart';
import 'job_application.dart';

enum TrackedLayout { list, board }

enum TrackedSort {
  updated('Recently updated'),
  added('Newest added'),
  followUp('Follow-up date'),
  salary('Highest salary'),
  company('Company A–Z');

  const TrackedSort(this.label);

  final String label;
}

/// How the Tracked list is shown: list or board, sort, extra filters, and
/// which cards are selected for bulk actions. Layout and sort are
/// remembered on the device.
class TrackedViewController extends ChangeNotifier {
  TrackedViewController({this.prefs}) {
    _load();
  }

  /// Where layout and sort are remembered; null keeps them in memory only.
  final SharedPreferencesAsync? prefs;

  static const _layoutKey = 'tracked.layout';
  static const _sortKey = 'tracked.sort';

  TrackedLayout _layout = TrackedLayout.list;
  TrackedSort _sort = TrackedSort.updated;
  bool _remoteOnly = false;
  bool _followUpDue = false;
  bool _hideClosed = false;
  Set<String> _selected = const {};

  TrackedLayout get layout => _layout;
  TrackedSort get sort => _sort;
  bool get remoteOnly => _remoteOnly;
  bool get followUpDue => _followUpDue;
  bool get hideClosed => _hideClosed;

  int get activeFilterCount =>
      [_remoteOnly, _followUpDue, _hideClosed].where((on) => on).length;

  Set<String> get selected => _selected;
  bool get isSelecting => _selected.isNotEmpty;
  bool isSelected(String id) => _selected.contains(id);

  Future<void> _load() async {
    final prefs = this.prefs;
    if (prefs == null) return;
    try {
      final layout = await prefs.getString(_layoutKey);
      final sort = await prefs.getString(_sortKey);
      _layout = TrackedLayout.values
          .firstWhere((l) => l.name == layout, orElse: () => _layout);
      _sort = TrackedSort.values
          .firstWhere((s) => s.name == sort, orElse: () => _sort);
      notifyListeners();
    } catch (e) {
      debugPrint('Tracked view settings unavailable: $e');
    }
  }

  void _remember(String key, String value) {
    prefs?.setString(key, value).catchError((Object e) {
      debugPrint('Saving tracked view settings failed: $e');
    });
  }

  void setLayout(TrackedLayout layout) {
    if (layout == _layout) return;
    _layout = layout;
    // Selecting is a list-view thing.
    _selected = const {};
    notifyListeners();
    _remember(_layoutKey, layout.name);
  }

  void setSort(TrackedSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    notifyListeners();
    _remember(_sortKey, sort.name);
  }

  void setFilters({bool? remoteOnly, bool? followUpDue, bool? hideClosed}) {
    _remoteOnly = remoteOnly ?? _remoteOnly;
    _followUpDue = followUpDue ?? _followUpDue;
    _hideClosed = hideClosed ?? _hideClosed;
    notifyListeners();
  }

  void clearFilters() => setFilters(
        remoteOnly: false,
        followUpDue: false,
        hideClosed: false,
      );

  void toggleSelected(String id) {
    _selected = _selected.contains(id)
        ? ({..._selected}..remove(id))
        : {..._selected, id};
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selected = ids.toSet();
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected = const {};
    notifyListeners();
  }

  /// [applications] matching the search, stage and filters, sorted.
  List<JobApplication> apply(
    Iterable<JobApplication> applications, {
    ApplicationStatus? status,
    String query = '',
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final q = query.trim().toLowerCase();

    bool matches(JobApplication a) {
      if (status != null && a.status != status) return false;
      if (_hideClosed && a.status == ApplicationStatus.rejected) return false;
      if (_remoteOnly && !isRemote(a)) return false;
      if (_followUpDue) {
        final due = a.followUpOn;
        if (due == null || due.isAfter(today)) return false;
      }
      if (q.isEmpty) return true;
      return a.role.toLowerCase().contains(q) ||
          a.company.toLowerCase().contains(q) ||
          (a.location?.toLowerCase().contains(q) ?? false);
    }

    final result = applications.where(matches).toList();
    int byUpdated(JobApplication a, JobApplication b) =>
        b.updatedAt.compareTo(a.updatedAt);
    result.sort(switch (_sort) {
      TrackedSort.updated => byUpdated,
      TrackedSort.added => (a, b) => b.createdAt.compareTo(a.createdAt),
      // Soonest follow-up first; none at the end.
      TrackedSort.followUp => (a, b) {
          final x = a.followUpOn, y = b.followUpOn;
          if (x == null && y == null) return byUpdated(a, b);
          if (x == null) return 1;
          if (y == null) return -1;
          return x.compareTo(y);
        },
      // Highest pay first; unknown pay at the end.
      TrackedSort.salary => (a, b) {
          final x = monthlyPesos(a.salary), y = monthlyPesos(b.salary);
          if (x == null && y == null) return byUpdated(a, b);
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        },
      TrackedSort.company => (a, b) =>
          a.company.toLowerCase().compareTo(b.company.toLowerCase()),
    });
    return result;
  }

  static bool isRemote(JobApplication a) {
    final where = '${a.location ?? ''} ${a.role}'.toLowerCase();
    return where.contains('remote') ||
        where.contains('work from home') ||
        where.contains('wfh');
  }
}
