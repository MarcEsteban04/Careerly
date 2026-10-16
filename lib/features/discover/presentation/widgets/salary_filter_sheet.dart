import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pill_chip.dart';
import '../../data/discover_controller.dart';

/// "₱30K", "₱100K".
String pesoThousands(int amount) => '₱${amount ~/ 1000}K';

/// Minimum monthly pay and "Only jobs that show pay". Filters what's loaded
/// right away, without a new search.
Future<void> showSalaryFilterSheet(
  BuildContext context, {
  required DiscoverController controller,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final minimum = controller.minSalary;
          final shownOnly = controller.salaryShownOnly;
          void set({int? minimum, required bool shownOnly}) =>
              controller.setSalaryFilter(minimum: minimum, shownOnly: shownOnly);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Salary',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (controller.hasSalaryFilter)
                        TextButton(
                          onPressed: () => set(minimum: null, shownOnly: false),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Minimum per month. Pay in other currencies is converted '
                    'roughly to pesos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      PillChip(
                        label: 'Any',
                        selected: minimum == null,
                        onTap: () => set(minimum: null, shownOnly: shownOnly),
                      ),
                      for (final step in salaryFilterSteps)
                        PillChip(
                          label: '${pesoThousands(step)}+',
                          selected: minimum == step,
                          onTap: () => set(minimum: step, shownOnly: shownOnly),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only jobs that show pay'),
                    subtitle: const Text(
                      'Many Philippine posts leave salary out. Off keeps them '
                      'in the list.',
                    ),
                    value: shownOnly,
                    onChanged: (v) => set(minimum: minimum, shownOnly: v),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
