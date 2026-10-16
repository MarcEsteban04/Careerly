import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../applications/data/job_application.dart';
import '../../profile/data/career_profile.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/widgets/generator_scaffold.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/negotiation_coach.dart';

/// Salary negotiation for one application: enter the offer, get a counter,
/// talking points, what else to ask for, and an email and call script.
class NegotiationScreen extends StatefulWidget {
  const NegotiationScreen({
    super.key,
    required this.application,
    required this.coach,
    required this.profile,
    required this.onSaveToNotes,
    this.comparableSalaries = const [],
    this.senderName,
  });

  final JobApplication application;
  final NegotiationCoach coach;
  final CareerProfile profile;

  /// Salaries seen for similar jobs, e.g. "UI Designer at Acme: ₱50K".
  final List<String> comparableSalaries;
  final String? senderName;

  /// Appends text to the application's notes; returns an error message.
  final Future<String?> Function(String note) onSaveToNotes;

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  late final _offer = TextEditingController(text: widget.application.salary);
  final _target = TextEditingController();
  final _benefits = TextEditingController();
  final _notes = TextEditingController();
  final _recipient = TextEditingController();
  final _subject = TextEditingController();
  final _email = TextEditingController();
  final _planKey = GlobalKey();

  NegotiationPlan? _plan;
  bool _isWorking = false;
  bool _savedToNotes = false;
  String? _error;

  @override
  void dispose() {
    _offer.dispose();
    _target.dispose();
    _benefits.dispose();
    _notes.dispose();
    _recipient.dispose();
    _subject.dispose();
    _email.dispose();
    super.dispose();
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _build() async {
    FocusScope.of(context).unfocus();
    if (_offer.text.trim().isEmpty) {
      setState(() => _error = 'Enter the salary they offered first.');
      return;
    }
    setState(() {
      _isWorking = true;
      _error = null;
    });
    final application = widget.application;
    try {
      final plan = await widget.coach.plan(
        job: JobContext(
          title: application.role,
          company: application.company,
          location: application.location,
          description: application.jobDescription,
          applicationId: application.id,
        ),
        offer: OfferDetails(
          offer: _offer.text,
          target: _target.text,
          benefits: _benefits.text,
          notes: _notes.text,
          recipient: _recipient.text,
        ),
        profile: widget.profile,
        comparableSalaries: widget.comparableSalaries,
        senderName: widget.senderName,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _savedToNotes = false;
        _subject.text = plan.emailSubject.isEmpty
            ? '${application.role} offer'
            : plan.emailSubject;
        _email.text = plan.email;
      });
      // Bring the plan into view once it's laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final planContext = _planKey.currentContext;
        if (planContext != null) {
          Scrollable.ensureVisible(
            planContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = writerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _showMessage('$what copied');
  }

  Future<void> _sendEmail() async {
    // Built by hand: Uri.queryParameters encodes spaces as "+", which mail
    // apps show literally.
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(_subject.text)}'
      '&body=${Uri.encodeComponent(_email.text)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('No email app found. Copy the email instead.');
    }
  }

  Future<void> _saveToNotes(NegotiationPlan plan) async {
    final error = await widget.onSaveToNotes(plan.toNote(DateTime.now()));
    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
    } else {
      setState(() => _savedToNotes = true);
      _showMessage('Saved to the application notes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final plan = _plan;

    return GeneratorScaffold(
      title: 'Negotiate',
      headline: 'Ask for **what you\'re worth**',
      subtitle: '${application.role} at ${application.company}'
          '${application.company.endsWith('.') ? '' : '.'} Enter the offer and '
          'Careerly suggests a fair counter and what to say.',
      actionLabel: plan == null ? 'Build my plan' : 'Rebuild plan',
      onAction: _isWorking ? null : _build,
      isWorking: _isWorking,
      errorMessage: _error,
      workingMessages: const [
        'Checking pay for similar roles…',
        'Weighing the offer…',
        'Writing what to say…',
      ],
      children: [
        LabeledField(
          label: 'Salary offered',
          child: TextField(
            controller: _offer,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. ₱45,000 a month',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'What you hoped for (optional)',
          child: TextField(
            controller: _target,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. ₱55,000',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'Rest of the offer (optional)',
          child: TextField(
            controller: _benefits,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. HMO, 13th month, hybrid 3 days',
              prefixIcon: Icon(Icons.card_giftcard_outlined),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'Anything else (optional)',
          child: TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Another offer at ₱50K, reply by Friday',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledField(
          label: 'Who to send it to (optional)',
          child: TextField(
            controller: _recipient,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: "Recruiter's or hiring manager's name",
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ),
        if (plan != null && !_isWorking) ...[
          const SizedBox(height: AppSpacing.lg),
          _CounterCard(key: _planKey, plan: plan),
          _ListCard(
            title: 'Talking points',
            icon: Icons.record_voice_over_rounded,
            accent: Accent.teal,
            items: plan.talkingPoints,
          ),
          _ListCard(
            title: 'Also ask for',
            icon: Icons.card_giftcard_rounded,
            accent: Accent.violet,
            items: plan.alsoAskFor,
          ),
          _ListCard(
            title: 'Avoid',
            icon: Icons.do_not_disturb_on_outlined,
            accent: Accent.rose,
            items: plan.avoid,
          ),
          const SizedBox(height: AppSpacing.md),
          _EmailCard(
            subject: _subject,
            body: _email,
            onCopy: () => _copy(
              'Subject: ${_subject.text}\n\n${_email.text}',
              'Email',
            ),
            onSend: _sendEmail,
          ),
          if (plan.callScript.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _ScriptCard(
              script: plan.callScript,
              onCopy: () => _copy(plan.callScript, 'Call script'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _savedToNotes ? null : () => _saveToNotes(plan),
            icon: Icon(
              _savedToNotes ? Icons.check_rounded : Icons.note_add_outlined,
              size: 18,
            ),
            label: Text(_savedToNotes ? 'Saved to notes' : 'Save plan to notes'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Suggested by ${plan.provider} from public pay data and what you '
            'entered. Treat the numbers as a guide, not a guarantee.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

/// The headline: the amount to ask for, how the offer looks, and the
/// lowest worth accepting.
class _CounterCard extends StatelessWidget {
  const _CounterCard({super.key, required this.plan});

  final NegotiationPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.handshake_rounded,
                accent: Accent.emerald,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Ask for',
                style: theme.textTheme.labelLarge?.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            plan.counterOffer,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (plan.verdict.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(plan.verdict, style: theme.textTheme.bodyMedium),
          ],
          if (plan.walkAway.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lowest worth accepting: ${plan.walkAway}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (plan.marketNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.marketNote,
              style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Accent accent;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, accent: accent, size: 32),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: accent.colorIn(theme.brightness),
                      ),
                    ),
                    Expanded(
                      child: Text(item, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The counter-offer email, editable, with copy and send.
class _EmailCard extends StatelessWidget {
  const _EmailCard({
    required this.subject,
    required this.body,
    required this.onCopy,
    required this.onSend,
  });

  final TextEditingController subject;
  final TextEditingController body;
  final VoidCallback onCopy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bare = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      contentPadding: EdgeInsets.zero,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: subject,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            decoration: bare.copyWith(labelText: 'Subject'),
          ),
          const Divider(height: AppSpacing.lg),
          TextField(
            controller: body,
            minLines: 5,
            maxLines: null,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            decoration: bare,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What to say if they call.
class _ScriptCard extends StatelessWidget {
  const _ScriptCard({required this.script, required this.onCopy});

  final String script;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'If they call',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Copy call script',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
          Text(script, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
