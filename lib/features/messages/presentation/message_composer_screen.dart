import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../applications/data/job_application.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/widgets/generator_scaffold.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/message_writer.dart';

/// Drafts a follow-up, thank-you or offer reply for one application. The
/// draft stays editable, then goes out by email, copy or share.
class MessageComposerScreen extends StatefulWidget {
  const MessageComposerScreen({
    super.key,
    required this.application,
    required this.writer,
    required this.profile,
    this.senderName,
    this.initialKind,
  });

  final JobApplication application;
  final MessageWriter writer;
  final CareerProfile profile;
  final String? senderName;
  final MessageKind? initialKind;

  @override
  State<MessageComposerScreen> createState() => _MessageComposerScreenState();
}

class _MessageComposerScreenState extends State<MessageComposerScreen> {
  late MessageKind _kind = widget.initialKind ??
      MessageKind.suggestedFor(widget.application.status);
  final _recipient = TextEditingController();
  final _details = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _draftKey = GlobalKey();

  bool _isWriting = false;
  bool _hasDraft = false;
  String? _provider;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
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
    final application = widget.application;
    try {
      final draft = await widget.writer.write(
        kind: _kind,
        job: JobContext(
          title: application.role,
          company: application.company,
          location: application.location,
          applicationId: application.id,
        ),
        profile: widget.profile,
        senderName: widget.senderName,
        recipientName: _recipient.text,
        details: _details.text,
      );
      if (!mounted) return;
      setState(() {
        _subject.text = draft.subject;
        _body.text = draft.body;
        _provider = draft.provider;
        _hasDraft = true;
      });
      // Bring the draft into view once it's laid out.
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

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: 'Subject: ${_subject.text}\n\n${_body.text}'),
    );
    HapticFeedback.lightImpact();
    _showMessage('Copied. Paste it into your email or chat.');
  }

  Future<void> _email() async {
    // Built by hand: Uri.queryParameters encodes spaces as "+", which mail
    // apps show literally.
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(_subject.text)}'
      '&body=${Uri.encodeComponent(_body.text)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('No email app found. Copy the message instead.');
    }
  }

  Future<void> _share() => SharePlus.instance.share(
        ShareParams(text: _body.text, subject: _subject.text),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final application = widget.application;

    return GeneratorScaffold(
      title: 'Message',
      headline: 'Say the **right thing**',
      subtitle: '${application.role} at ${application.company}. Pick a '
          'message, add a detail or two, and Careerly drafts it.',
      actionLabel: _hasDraft ? 'Rewrite' : 'Write my message',
      onAction: _isWriting ? null : _write,
      isWorking: _isWriting,
      errorMessage: _error,
      workingMessages: const [
        'Finding the right tone…',
        'Keeping it short and warm…',
        'Polishing the wording…',
      ],
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final kind in MessageKind.values)
              PillChip(
                label: kind.label,
                selected: kind == _kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _kind.when,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'To (optional)',
          child: TextField(
            controller: _recipient,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: "Recruiter's or interviewer's name",
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
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
              hintText: 'e.g. We talked about their new mobile app',
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
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Written by $_provider. Tap the text to edit it.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Action(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  onTap: _email,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _Action(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: _copy,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _Action(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: _share,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
      );
}
