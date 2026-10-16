import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../documents/data/career_document.dart';
import '../../documents/data/document_markup.dart';
import '../../documents/data/document_pdf.dart';
import '../../documents/presentation/pdf_preview_screen.dart';
import '../../documents/presentation/widgets/markup_view.dart';
import '../data/studio_controller.dart';

/// A resume or cover letter: preview or edit, then copy, view or download
/// as PDF, save (for new drafts) or delete (for saved ones).
class DocumentScreen extends StatefulWidget {
  /// A freshly generated draft that hasn't been saved yet.
  const DocumentScreen.draft({
    super.key,
    required this.studio,
    required this.kind,
    required this.title,
    required String this.content,
    this.applicationId,
    this.changes = const [],
    this.provider,
  }) : document = null;

  /// A saved document.
  DocumentScreen.saved({
    super.key,
    required this.studio,
    required CareerDocument this.document,
  })  : kind = document.kind,
        title = document.title,
        content = document.content,
        applicationId = document.applicationId,
        changes = const [],
        provider = null;

  final StudioController studio;
  final CareerDocument? document;
  final DocumentKind kind;
  final String title;
  final String? content;
  final String? applicationId;

  /// What the AI improved, shown above an enhanced resume.
  final List<String> changes;

  /// Which AI wrote the draft.
  final String? provider;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  late final _editor = TextEditingController(text: widget.content);
  late CareerDocument? _saved = widget.document;
  int _mode = 0;
  bool _isSaving = false;
  bool _isSharing = false;

  bool get _isDirty => _editor.text != (_saved?.content ?? widget.content);

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = _saved;
      _saved = saved == null
          ? await widget.studio.save(
              kind: widget.kind,
              title: widget.title,
              content: _editor.text,
              applicationId: widget.applicationId,
            )
          : await widget.studio.update(saved, _editor.text);
      HapticFeedback.lightImpact();
      _showMessage(saved == null ? 'Saved to Studio' : 'Changes saved');
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// "View PDF" or "Download PDF".
  Future<void> _pdfOptions() async {
    final action = await showModalBottomSheet<_PdfAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View PDF'),
                subtitle: const Text('See it exactly as it will be sent'),
                onTap: () => Navigator.of(context).pop(_PdfAction.view),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download PDF'),
                subtitle: const Text('Save it to your phone'),
                onTap: () => Navigator.of(context).pop(_PdfAction.download),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    setState(() => _isSharing = true);
    try {
      final bytes = await DocumentPdf.build(_editor.text);
      if (!mounted) return;
      switch (action) {
        case _PdfAction.view:
          await pdfrxFlutterInitialize();
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PdfPreviewScreen(title: widget.title, bytes: bytes),
            ),
          );
        case _PdfAction.download:
          if (await DocumentPdf.download(title: widget.title, bytes: bytes)) {
            HapticFeedback.lightImpact();
            _showMessage('Saved ${DocumentPdf.fileNameFor(widget.title)}');
          }
      }
    } catch (error) {
      debugPrint('PDF failed: $error');
      _showMessage("Couldn't create the PDF. Try again.");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: markupToPlainText(_editor.text)));
    _showMessage('Copied to clipboard');
  }

  Future<void> _delete() async {
    final saved = _saved;
    if (saved == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.kind.label.toLowerCase()}?'),
        content: Text('"${widget.title}" will be removed from Studio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.studio.delete(saved);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showMessage(friendlyErrorMessage(error));
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_saved != null && !_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_saved == null ? 'Discard this draft?' : 'Discard changes?'),
        content: const Text("You can save it to Studio so it isn't lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final unsaved = _saved == null || _isDirty;

    return PopScope(
      canPop: !unsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.kind.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Copy text',
                      onPressed: _copy,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    120 + bottomInset,
                  ),
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (widget.provider != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Drafted by ${widget.provider}. Review before sending.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (widget.changes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ChangesCard(changes: widget.changes),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    SegmentedTabs(
                      labels: const ['Preview', 'Edit'],
                      selectedIndex: _mode,
                      onSelected: (i) {
                        FocusScope.of(context).unfocus();
                        setState(() => _mode = i);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_mode == 0)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md + 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: colorScheme.outline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: MarkupView(content: _editor.text),
                      )
                    else ...[
                      TextField(
                        controller: _editor,
                        minLines: 16,
                        maxLines: null,
                        onChanged: (_) => setState(() {}),
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Write here…',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Formatting: "# Name", "## Section", "- bullet", '
                        '**bold**.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (_saved != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                          ),
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text('Delete ${widget.kind.label.toLowerCase()}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomSheet: Container(
          color: colorScheme.surface,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm + bottomInset,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : _pdfOptions,
                  icon: _isSharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: _saved == null
                      ? 'Save to Studio'
                      : _isDirty
                          ? 'Save changes'
                          : 'Saved',
                  icon: _saved != null && !_isDirty
                      ? Icons.check_rounded
                      : Icons.bookmark_add_outlined,
                  isLoading: _isSaving,
                  onPressed: unsaved ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangesCard extends StatelessWidget {
  const _ChangesCard({required this.changes});

  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'What changed',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      change,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _PdfAction { view, download }
