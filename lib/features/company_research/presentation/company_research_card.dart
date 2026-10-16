import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/tag_pill.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/company_research.dart';
import '../data/company_researcher.dart';

/// "About this company": offers an AI brief, then shows what they do, key
/// facts, good signs, things worth checking and questions to ask. Shows a
/// saved brief straight away.
class CompanyResearchCard extends StatefulWidget {
  const CompanyResearchCard({
    super.key,
    required this.researcher,
    required this.job,
  });

  final CompanyResearcher researcher;
  final JobContext job;

  @override
  State<CompanyResearchCard> createState() => _CompanyResearchCardState();
}

class _CompanyResearchCardState extends State<CompanyResearchCard> {
  CompanyResearch? _research;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await widget.researcher.cached(widget.job.company);
    if (mounted && saved != null) setState(() => _research = saved);
  }

  Future<void> _lookUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final research = await widget.researcher.research(widget.job);
      if (mounted) setState(() => _research = research);
    } catch (error) {
      if (mounted) setState(() => _error = writerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final research = _research;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.apartment_rounded,
                accent: Accent.blue,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About ${widget.job.company}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      research == null
                          ? 'Company research with AI'
                          : 'Researched ${DateFormat('MMM d').format(research.createdAt)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (research != null && !_loading)
                IconButton(
                  tooltip: 'Refresh research',
                  onPressed: _lookUp,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Looking up ${widget.job.company}…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else if (research == null) ...[
            Text(
              'What they do, good signs, things worth checking and smart '
              'questions to ask them.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: widget.researcher.isConfigured ? _lookUp : null,
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('Research this company'),
            ),
          ] else
            _Brief(research: research),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            FormBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _Brief extends StatelessWidget {
  const _Brief({required this.research});

  final CompanyResearch research;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!research.foundReliableInfo) ...[
          const FormBanner(
            tone: FormBannerTone.info,
            message: "Careerly couldn't find much reliable information about "
                'this company online. Look them up yourself before sharing '
                'personal documents.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (research.summary.isNotEmpty)
          Text(research.summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        if (research.facts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [for (final fact in research.facts) TagPill(label: fact)],
          ),
        ],
        _Section(
          title: 'Good signs',
          items: research.goodSigns,
          icon: Icons.check_circle_rounded,
          color: Accent.emerald.colorIn(brightness),
        ),
        _Section(
          title: 'Worth checking',
          items: research.watchOuts,
          icon: Icons.error_outline_rounded,
          color: Accent.amber.colorIn(brightness),
        ),
        _Section(
          title: 'Questions to ask them',
          items: research.questionsToAsk,
          icon: Icons.help_outline_rounded,
          color: Accent.teal.colorIn(brightness),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AI summary from the web by ${research.provider}. Double-check '
          'anything important.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
