import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../messages/data/message_writer.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/widgets/generator_scaffold.dart';
import '../../studio/presentation/writer_error_message.dart';
import 'apply_browser_screen.dart';

/// Applies by email: drafts a short application email, then hands it to
/// her email app with the resume PDF attached. Resolves to true once she
/// has sent it on (so Careerly can ask whether she applied).
class EmailApplyScreen extends StatefulWidget {
  const EmailApplyScreen({
    super.key,
    required this.to,
    required this.job,
    required this.writer,
    required this.profile,
    this.senderName,
    this.resume,
  });

  /// The hiring email from the job post.
  final String to;
  final JobContext job;
  final MessageWriter writer;
  final CareerProfile profile;
  final String? senderName;

  /// The resume chosen in the application kit, as a PDF to attach.
  final ApplyAttachment? resume;

  @override
  State<EmailApplyScreen> createState() => _EmailApplyScreenState();
}

class _EmailApplyScreenState extends State<EmailApplyScreen> {
  final _details = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _draftKey = GlobalKey();

  bool _isWriting = false;
  bool _hasDraft = false;
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _write() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isWriting = true;
      _error = null;
    });
    try {
      final draft = await widget.writer.write(
        kind: MessageKind.application,
        job: widget.job,
        profile: widget.profile,
        senderName: widget.senderName,
        details: _details.text,
      );
      if (!mounted) return;
      setState(() {
        _subject.text = draft.subject;
        _body.text = draft.body;
        _hasDraft = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final draftContext = _draftKey.currentContext;
        if (draftContext != null) {
          Scrollable.ensureVisible(
            draftContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = writerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWriting = false);
    }
  }

  /// Copies the address (share sheets can't fill in "To"), then shares the
  /// email with the resume attached.
  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      await Clipboard.setData(ClipboardData(text: widget.to));
      final files = <XFile>[];
      final resume = widget.resume;
      if (resume != null) {
        final dir = await Directory.systemTemp.createTemp('careerly_');
        final file = File('${dir.path}/${resume.fileName}');
        await file.writeAsBytes(await resume.bytes());
        files.add(XFile(file.path, mimeType: 'application/pdf'));
      }
      if (mounted) {
        _showMessage('${widget.to} copied. Paste it in the "To" field.');
      }
      await SharePlus.instance.share(
        ShareParams(
          subject: _subject.text,
          text: _body.text,
          files: files.isEmpty ? null : files,
        ),
      );
      _sent = true;
    } catch (error) {
      debugPrint('Email apply share failed: $error');
      if (mounted) _showMessage("Couldn't open your email app. Copy the email instead.");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: 'To: ${widget.to}\nSubject: ${_subject.text}\n\n${_body.text}',
      ),
    );
    HapticFeedback.lightImpact();
    _showMessage('Email copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resume = widget.resume;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_sent);
      },
      child: GeneratorScaffold(
        title: 'Apply by email',
        headline: 'Email your **application**',
        subtitle: '${widget.job.label}. Careerly drafts it from your profile '
            'and attaches your resume.',
        actionLabel: _hasDraft ? 'Rewrite' : 'Write my email',
        onAction: _isWriting ? null : _write,
        isWorking: _isWriting,
        errorMessage: _error,
        workingMessages: const [
          'Matching your strengths to the role…',
          'Keeping it short and professional…',
          'Polishing the wording…',
        ],
        children: [
          AppCard(
            child: Row(
              children: [
                const IconBadge(icon: Icons.alternate_email_rounded, size: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        widget.to,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy address',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.to));
                    _showMessage('${widget.to} copied');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Anything to mention (optional)',
            child: TextField(
              controller: _details,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Available to start immediately',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ),
          if (_hasDraft && !_isWriting) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              key: _draftKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _subject,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(height: AppSpacing.lg),
                  TextField(
                    controller: _body,
                    minLines: 6,
                    maxLines: null,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      IconBadge(
                        icon: Icons.picture_as_pdf_outlined,
                        accent: resume == null ? Accent.amber : Accent.rose,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          resume?.fileName ??
                              'Attach your resume in your email app',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: resume == null ? 'Send' : 'Send with resume',
              icon: Icons.send_rounded,
              isLoading: _isSending,
              onPressed: _send,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy instead'),
            ),
          ],
        ],
      ),
    );
  }
}
