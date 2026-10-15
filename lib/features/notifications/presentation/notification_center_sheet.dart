import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../agenda/data/agenda_event.dart';
import '../../agenda/presentation/agenda_event_style.dart';
import '../../discover/data/search_preferences_repository.dart';

/// New jobs from alerts and what's coming up soon, behind the dashboard bell.
Future<void> showNotificationCenter(
  BuildContext context, {
  required List<(SavedSearch, int)> alerts,
  required List<AgendaEvent> upcoming,
  required ValueChanged<SavedSearch> onOpenSearch,
  required ValueChanged<AgendaEvent> onOpenEvent,
  required VoidCallback onOpenSettings,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _NotificationCenter(
        alerts: alerts,
        upcoming: upcoming,
        onOpenSearch: (search) {
          Navigator.of(context).pop();
          onOpenSearch(search);
        },
        onOpenEvent: (event) {
          Navigator.of(context).pop();
          onOpenEvent(event);
        },
        onOpenSettings: () {
          Navigator.of(context).pop();
          onOpenSettings();
        },
      ),
    );

class _NotificationCenter extends StatelessWidget {
  const _NotificationCenter({
    required this.alerts,
    required this.upcoming,
    required this.onOpenSearch,
    required this.onOpenEvent,
    required this.onOpenSettings,
  });

  final List<(SavedSearch, int)> alerts;
  final List<AgendaEvent> upcoming;
  final ValueChanged<SavedSearch> onOpenSearch;
  final ValueChanged<AgendaEvent> onOpenEvent;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEmpty = alerts.isEmpty && upcoming.isEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Notification settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
            if (isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "You're all caught up",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Save a job search to get alerts when new jobs appear.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _Label('New jobs'),
              for (final (search, count) in alerts)
                _Row(
                  icon: Icons.work_outline_rounded,
                  color: colorScheme.primary,
                  title: count == 1
                      ? '1 new job for ${search.keywords}'
                      : '$count new jobs for ${search.keywords}',
                  subtitle: '${search.scope.label} · tap to see them',
                  onTap: () => onOpenSearch(search),
                ),
            ],
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _Label('Coming up'),
              for (final event in upcoming)
                _Row(
                  icon: event.kind.icon,
                  color: event.kind == AgendaEventKind.interview
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  title: event.title,
                  subtitle: [
                    _when(event.startsAt),
                    ?event.company,
                  ].join(' · '),
                  onTap: () => onOpenEvent(event),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat.jm().format(at);
    return switch (day.difference(today).inDays) {
      0 => 'Today, $time',
      1 => 'Tomorrow, $time',
      _ => DateFormat('EEE, MMM d · h:mm a').format(at),
    };
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
