import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/error_message.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../applications/data/applications_repository.dart';
import '../../goals/data/goal.dart';
import '../../goals/data/goals_repository.dart';
import 'workspace_data.dart';

/// Loads and holds the user's applications, agenda and goals so every tab
/// shows the same, up-to-date data.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.applications,
    required this.agenda,
    required this.goals,
  });

  final ApplicationsRepository applications;
  final AgendaRepository agenda;
  final GoalsRepository goals;

  WorkspaceData? _data;
  Object? _error;

  WorkspaceData? get data => _data;

  /// Set when the last load failed and there's no data to show.
  Object? get error => _error;

  Future<void> load() async {
    try {
      final (applicationList, upcoming, goalList) = await (
        applications.fetchAll(),
        agenda.fetchUpcoming(),
        goals.fetchAll(),
      ).wait;
      _data = WorkspaceData(
        applications: applicationList,
        upcoming: upcoming,
        goals: goalList,
      );
      _error = null;
    } on ParallelWaitError<dynamic, dynamic> catch (e) {
      final errors = e.errors as (AsyncError?, AsyncError?, AsyncError?);
      _error = (errors.$1 ?? errors.$2 ?? errors.$3)?.error ?? e;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  /// Clears a load error so the UI shows loading again, then retries.
  Future<void> retry() {
    _error = null;
    notifyListeners();
    return load();
  }

  /// Optimistically marks an agenda item done. Returns an error message if
  /// saving failed (the change is rolled back).
  Future<String?> setEventDone(String id, {required bool isDone}) async {
    final before = _data;
    if (before == null) return null;
    _data = before.copyWith(
      upcoming: [
        for (final e in before.upcoming)
          e.id == id ? e.copyWith(isDone: isDone) : e,
      ],
    );
    notifyListeners();
    try {
      await agenda.setDone(id, isDone: isDone);
      return null;
    } catch (error) {
      _data = before;
      notifyListeners();
      return friendlyErrorMessage(error);
    }
  }

  /// Optimistically adds one to a goal. Returns an error message if saving
  /// failed (the change is rolled back).
  Future<String?> incrementGoal(Goal goal) async {
    final before = _data;
    if (before == null) return null;
    final updated = goal.copyWith(progress: goal.progress + 1);
    _data = before.copyWith(
      goals: [for (final g in before.goals) g.id == goal.id ? updated : g],
    );
    notifyListeners();
    try {
      await goals.setProgress(goal.id, updated.progress);
      return null;
    } catch (error) {
      _data = before;
      notifyListeners();
      return friendlyErrorMessage(error);
    }
  }
}
