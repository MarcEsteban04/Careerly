import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/bottom_action_bar.dart';
import '../../../../core/widgets/emphasis_text.dart';
import '../../../../core/widgets/form_banner.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/hero_top_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/scroll_aware_status_bar.dart';

/// Shared layout for the AI generator pages: back button, bold headline,
/// form fields, an error banner, a "working…" card, and the main action.
class GeneratorScaffold extends StatelessWidget {
  const GeneratorScaffold({
    super.key,
    required this.title,
    required this.headline,
    required this.subtitle,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    required this.isWorking,
    required this.workingMessages,
    this.errorMessage,
  });

  final String title;

  /// Bold words wrapped in `**`.
  final String headline;
  final String subtitle;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool isWorking;

  /// Rotating status lines shown while the AI works.
  final List<String> workingMessages;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: ScrollAwareStatusBar(
        threshold: 120,
        child: ListView(
          padding: EdgeInsets.only(bottom: 120 + bottomInset),
          children: [
            HeroHeader(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg + 4,
              ),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HeroTopBar(title: title),
                      const SizedBox(height: AppSpacing.lg),
                      EmphasisText(
                        headline,
                        emphasisColor: theme.colorScheme.secondary,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    FormBanner(message: errorMessage!),
                  ],
                  if (isWorking) ...[
                    const SizedBox(height: AppSpacing.md),
                    _WorkingCard(messages: workingMessages),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: BottomActionBar(
        child: PrimaryButton(
          label: actionLabel,
          icon: Icons.auto_awesome_rounded,
          isLoading: isWorking,
          onPressed: onAction,
        ),
      ),
    );
  }
}

class _WorkingCard extends StatefulWidget {
  const _WorkingCard({required this.messages});

  final List<String> messages;

  @override
  State<_WorkingCard> createState() => _WorkingCardState();
}

class _WorkingCardState extends State<_WorkingCard> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % widget.messages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  widget.messages[_index],
                  key: ValueKey(_index),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
