import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/search_pill.dart';
import '../../profile/data/career_profile.dart';
import '../data/discover_controller.dart';
import '../data/job_search_query.dart';
import 'widgets/job_listing_card.dart';

/// Header for the Discover section: profile summary, search and filters.
class DiscoverHeader extends StatelessWidget {
  const DiscoverHeader({
    super.key,
    required this.controller,
    required this.searchController,
    required this.onEditProfile,
  });

  final DiscoverController controller;
  final TextEditingController searchController;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSummary(profile: controller.profile, onEdit: onEditProfile),
        const SizedBox(height: AppSpacing.md),
        SearchPill(
          hint: controller.suggestedKeywords.isEmpty
              ? 'Search a role, e.g. UI Designer'
              : 'Search a role or skill',
          controller: searchController,
          onSubmitted: controller.search,
        ),
        if (controller.savedSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _SavedSearches(controller: controller, searchController: searchController),
        ],
        if (controller.suggestions.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _Suggestions(
            suggestions: controller.suggestions,
            onTap: (role) {
              searchController.text = role;
              controller.search(role);
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final scope in SearchScope.values) ...[
                PillChip(
                  label: scope.label,
                  leading: Icon(switch (scope) {
                    SearchScope.philippines => Icons.flag_outlined,
                    SearchScope.remote => Icons.public_rounded,
                    SearchScope.anywhere => Icons.travel_explore_rounded,
                  }),
                  selected: controller.scope == scope,
                  onTap: () => controller.setScope(scope),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              _PostedWithinButton(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

/// Results area for the Discover section.
class DiscoverResults extends StatelessWidget {
  const DiscoverResults({
    super.key,
    required this.controller,
    required this.searchController,
    required this.isSaved,
    required this.onOpenListing,
    required this.onEditProfile,
    required this.onDismiss,
    required this.onToggleSaveSearch,
  });

  final DiscoverController controller;
  final TextEditingController searchController;
  final bool Function(RankedListing ranked) isSaved;
  final ValueChanged<RankedListing> onOpenListing;
  final VoidCallback onEditProfile;

  /// "Not interested" (swipe left).
  final ValueChanged<RankedListing> onDismiss;
  final VoidCallback onToggleSaveSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = controller.results;
    final error = controller.error;

    if (controller.isLoading) return const _LoadingCards();

    if (error != null) {
      return _card(
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Search didn\'t work',
          message: error,
          actionLabel: 'Try again',
          actionIcon: Icons.refresh_rounded,
          onAction: () => controller.search(searchController.text),
        ),
      );
    }

    if (results == null) {
      final suggestion = controller.suggestedKeywords;
      return _card(
        EmptyState(
          icon: Icons.travel_explore_rounded,
          title: 'Find jobs that fit you',
          message: 'Searches LinkedIn, Indeed, JobStreet and more, then ranks '
              'every job by how well it matches your profile.',
          actionLabel: suggestion.isEmpty ? 'Set up profile' : 'Search "$suggestion"',
          actionIcon: suggestion.isEmpty
              ? Icons.person_outline_rounded
              : Icons.search_rounded,
          onAction: suggestion.isEmpty
              ? onEditProfile
              : () => controller.search(searchController.text),
        ),
      );
    }

    if (results.isEmpty) {
      return _card(
        EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No jobs found',
          message: 'Try a broader role, another location, or a longer time '
              'range.',
        ),
      );
    }

    final aiProvider = results
        .map((r) => r.match?.aiProvider)
        .firstWhere((p) => p != null, orElse: () => null);
    final summary = controller.profile.isEmpty
        ? '${results.length} jobs for "${controller.keywords}"'
        : aiProvider != null
            ? '${results.length} jobs · ranked for you by $aiProvider'
            : '${results.length} jobs for "${controller.keywords}" · best '
                'matches first';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.notice != null) ...[
          FormBanner(message: controller.notice!, tone: FormBannerTone.info),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  controller.isRanking ? 'Ranking with AI…' : summary,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (controller.isRanking)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (controller.preferences != null)
                IconButton(
                  tooltip: controller.isCurrentSearchSaved
                      ? 'Remove saved search'
                      : 'Save this search',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleSaveSearch,
                  icon: Icon(
                    controller.isCurrentSearchSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        for (final ranked in results) ...[
          // Swipe left for "Not interested".
          Dismissible(
            key: ValueKey(ranked.listing.dedupeKey),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onDismiss(ranked),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thumb_down_alt_outlined,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Not interested',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            child: JobListingCard(
              ranked: ranked,
              isSaved: isSaved(ranked),
              onTap: () => onOpenListing(ranked),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Swipe a job left if you\'re not interested.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Results come from job boards via JSearch and Jooble, with AI web '
            'search as a backup. Always check the original post before '
            'applying.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) => AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: child,
      );
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.onEdit});

  final CareerProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final empty = profile.isEmpty;
    final skills = profile.effectiveSkills.length;
    final details = [
      if (profile.effectiveRoles.isNotEmpty)
        profile.effectiveRoles.take(2).join(', '),
      profile.workSetup.label,
      if (skills > 0) '$skills skill${skills == 1 ? '' : 's'}',
      if (profile.resume != null) 'Resume added',
    ].join(' · ');

    return AppCard(
      onTap: onEdit,
      color: empty ? colorScheme.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              empty ? Icons.person_add_alt_rounded : Icons.badge_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty ? 'Set up your career profile' : 'Looking for',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  empty
                      ? 'Upload your resume or add roles to get tailored '
                          'matches.'
                      : details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(
            empty ? Icons.chevron_right_rounded : Icons.edit_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Bookmarked searches: tap to run, long-press to remove.
class _SavedSearches extends StatelessWidget {
  const _SavedSearches({
    required this.controller,
    required this.searchController,
  });

  final DiscoverController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Icon(Icons.bookmark_rounded, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Saved',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          for (final search in controller.savedSearches) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: 'Long-press to remove',
              child: GestureDetector(
                onLongPress: () => controller.deleteSavedSearch(search),
                child: ActionChip(
                  label: Text(search.label),
                  onPressed: () {
                    searchController.text = search.keywords;
                    controller.runSavedSearch(search);
                  },
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: colorScheme.outline),
                  backgroundColor: colorScheme.surface,
                  labelStyle: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tailored searches from the profile and resume, e.g. "For you: UI
/// Designer · Product Designer".
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'For you',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontSize: 13,
            ),
          ),
          for (final role in suggestions) ...[
            const SizedBox(width: AppSpacing.xs),
            ActionChip(
              label: Text(role),
              onPressed: () => onTap(role),
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
              backgroundColor: colorScheme.primary.withValues(alpha: 0.06),
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostedWithinButton extends StatelessWidget {
  const _PostedWithinButton({required this.controller});

  final DiscoverController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PostedWithin>(
      tooltip: 'Posted within',
      initialValue: controller.postedWithin,
      onSelected: controller.setPostedWithin,
      itemBuilder: (context) => [
        for (final value in PostedWithin.values)
          PopupMenuItem(value: value, child: Text(value.label)),
      ],
      child: IgnorePointer(
        child: PillChip(
          label: controller.postedWithin.label,
          leading: const Icon(Icons.schedule_rounded),
          selected: false,
          onTap: () {},
        ),
      ),
    );
  }
}

class _LoadingCards extends StatefulWidget {
  const _LoadingCards();

  @override
  State<_LoadingCards> createState() => _LoadingCardsState();
}

class _LoadingCardsState extends State<_LoadingCards>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Semantics(
      label: 'Searching job boards',
      child: FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
