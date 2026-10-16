import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/hero_top_bar.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/document_pdf.dart';
import '../data/resume_design.dart';

/// Pick how resumes look as PDF, previewing each design with the real
/// resume. Resolves to the chosen design, or null if left unchanged.
class ResumeDesignScreen extends StatefulWidget {
  const ResumeDesignScreen({
    super.key,
    required this.content,
    required this.store,
  });

  /// The resume to preview, as markup.
  final String content;
  final ResumeDesignStore store;

  @override
  State<ResumeDesignScreen> createState() => _ResumeDesignScreenState();
}

class _ResumeDesignScreenState extends State<ResumeDesignScreen> {
  ResumeDesign? _saved;
  ResumeDesign _design = ResumeDesign.classic;
  final _previews = <ResumeDesign, Future<Uint8List>>{};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await pdfrxFlutterInitialize();
    final saved = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _design = saved;
      _ready = true;
    });
  }

  Future<Uint8List> _preview(ResumeDesign design) => _previews.putIfAbsent(
        design,
        () => DocumentPdf.build(widget.content, design: design),
      );

  Future<void> _use() async {
    await widget.store.save(_design);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(_design);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: Column(
        children: [
          ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: HeroHeader(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HeroTopBar(title: 'Resume design'),
                  const SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (final (i, design) in ResumeDesign.values.indexed) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.xs),
                          PillChip(
                            label: design.label,
                            leading: design == _saved
                                ? const Icon(Icons.check_rounded)
                                : null,
                            selected: design == _design,
                            onTap: () => setState(() => _design = design),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _design.description,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<Uint8List>(
                    key: ValueKey(_design),
                    future: _preview(_design),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: FormBanner(
                            message: "Couldn't preview this design. Try "
                                'another one.',
                          ),
                        );
                      }
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return PdfViewer.data(
                        bytes,
                        sourceName: 'design-${_design.name}',
                        params: PdfViewerParams(
                          margin: AppSpacing.md,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          pageDropShadow: BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _design == _saved
              ? 'Keep ${_design.label}'
              : 'Use ${_design.label}',
          icon: Icons.check_rounded,
          onPressed: _ready ? _use : null,
        ),
      ),
    );
  }
}
