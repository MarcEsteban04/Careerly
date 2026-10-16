import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/job_search_query.dart';

/// Picks a country to search jobs in abroad.
Future<JobCountry?> showCountryPicker(
  BuildContext context, {
  JobCountry? selected,
}) =>
    showModalBottomSheet<JobCountry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CountryPicker(selected: selected),
    );

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected});

  final JobCountry? selected;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = _filter.trim().toLowerCase();
    final countries = [
      for (final country in JobCountry.all)
        if (query.isEmpty || country.name.toLowerCase().contains(query))
          country,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        // Keep the search field above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search jobs abroad',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Jobs posted in that country. Check each post for visa '
                      'sponsorship before applying.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      onChanged: (value) => setState(() => _filter = value),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Find a country',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: countries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No match. Try "Anywhere" to search every country.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          0,
                          AppSpacing.sm,
                          AppSpacing.md,
                        ),
                        children: [
                          for (final country in countries)
                            ListTile(
                              leading: Text(
                                country.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(country.name),
                              trailing: country.code == widget.selected?.code
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(country),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
