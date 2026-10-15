import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
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
  });

  final DiscoverController controller;
  final TextEditingController searchController;
  final bool Function(RankedListing ranked) isSaved;
  final ValueChanged<RankedListing> onOpenListing;
  final VoidCallback onEditProfile;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            controller.profile.isEmpty
                ? '${results.length} jobs for "${controller.keywords}"'
                : '${results.length} jobs for "${controller.keywords}" · '
                    'best matches first',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final ranked in results) ...[
          JobListingCard(
            ranked: ranked,
            isSaved: isSaved(ranked),
            onTap: () => onOpenListing(ranked),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Results come from job boards via JSearch and Jooble. Always '
            'check the original post before applying.',
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
    final details = [
      if (profile.targetRoles.isNotEmpty) profile.targetRoles.join(', '),
      profile.workSetup.label,
      if (profile.skills.isNotEmpty)
        '${profile.skills.length} skill${profile.skills.length == 1 ? '' : 's'}',
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
                      ? 'Add roles and skills to get match scores.'
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
