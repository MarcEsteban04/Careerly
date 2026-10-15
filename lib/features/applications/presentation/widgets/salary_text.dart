import 'package:flutter/material.dart';

/// "$4,000/month" with the amount bold and the period muted.
class SalaryText extends StatelessWidget {
  const SalaryText(this.salary, {super.key, this.maxWidth = 120});

  final String salary;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slash = salary.indexOf('/');
    final amount = slash == -1 ? salary : salary.substring(0, slash);
    final period = slash == -1 ? '' : salary.substring(slash);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: amount,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (period.isNotEmpty)
              TextSpan(
                text: period,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}
