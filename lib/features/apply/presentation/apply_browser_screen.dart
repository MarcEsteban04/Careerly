import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../studio/data/career_writer.dart';
import '../../studio/presentation/writer_error_message.dart';
import '../data/form_filler.dart';
import '../data/form_scripts.dart';
import 'fill_review_sheet.dart';

/// How the application page was left.
enum ApplyPageExit {
  /// Closed in Careerly, so it can ask right away whether she applied.
  closed,

  /// Handed to the phone's browser; Careerly asks when she comes back.
  openedExternally,
}

/// A file Careerly can attach when the page asks for one.
class ApplyAttachment {
  const ApplyAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Future<Uint8List> Function() bytes;
}

/// The job's application page inside Careerly, with "Fill with Careerly":
/// it reads the form, proposes answers for review, and fills them in. She
/// always submits the page herself.
class ApplyBrowserScreen extends StatefulWidget {
  const ApplyBrowserScreen({
    super.key,
    required this.url,
    required this.job,
    required this.filler,
    required this.loadApplicant,
    required this.editDetails,
    required this.openExternally,
    this.companyBrief,
    this.resume,
  });

  final Uri url;
  final JobContext job;
  final FormFiller filler;
  final Future<Applicant> Function() loadApplicant;

  /// Opens the application details form; resolves when it closes.
  final Future<void> Function() editDetails;
  final Future<bool> Function(Uri url) openExternally;

  /// A saved brief on the employer, to ground written answers.
  final Future<String?> Function()? companyBrief;

  /// The resume chosen in the application kit, ready to attach.
  final ApplyAttachment? resume;

  @override
  State<ApplyBrowserScreen> createState() => _ApplyBrowserScreenState();
}

class _ApplyBrowserScreenState extends State<ApplyBrowserScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _status;
  late String _host = widget.url.host;

  /// Hosts of the hiring systems that embed their forms in a frame.
  static const _formHosts = [
    'greenhouse.io',
    'lever.co',
    'workable.com',
    'ashbyhq.com',
    'smartrecruiters.com',
    'jobvite.com',
    'myworkdayjobs.com',
    'bamboohr.com',
    'breezy.hr',
    'recruitee.com',
    'teamtailor.com',
    'icims.com',
    'zohorecruit',
    'jotform.com',
    'typeform.com',
    'docs.google.com/forms',
    'forms.office.com',
  ];

  bool get _busy => _status != null;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (url) {
            _controller.runJavaScript(FormScripts.keepInView);
            final host = Uri.tryParse(url)?.host;
            if (mounted && host != null && host.isNotEmpty) {
              setState(() => _host = host);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            // mailto:, tel: and app links go to the phone's own apps.
            if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
              widget.openExternally(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.url);

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector(_chooseFiles);
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// When the page asks for a file: her chosen resume, or any file.
  Future<List<String>> _chooseFiles(FileSelectorParams params) async {
    final resume = widget.resume;
    final choice = await showModalBottomSheet<String>(
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
              if (resume != null)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Attach my resume'),
                  subtitle: Text(resume.fileName),
                  onTap: () => Navigator.of(context).pop('resume'),
                ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('Choose a file'),
                onTap: () => Navigator.of(context).pop('pick'),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      if (choice == 'resume' && resume != null) {
        final dir = await Directory.systemTemp.createTemp('careerly_');
        final file = File('${dir.path}/${resume.fileName}');
        await file.writeAsBytes(await resume.bytes());
        return [Uri.file(file.path).toString()];
      }
      if (choice == 'pick') {
        final files = await FilePicker.pickFiles();
        return [for (final f in files) f.uri.toString()];
      }
    } catch (error) {
      debugPrint('Attaching a file failed: $error');
      if (mounted) _showMessage("Couldn't attach that file. Try another.");
    }
    return const [];
  }

  Future<void> _fill() async {
    if (_busy) return;
    setState(() => _status = 'Reading the form…');
    try {
      final raw = await _controller.runJavaScriptReturningResult(FormScripts.scan);
      final scan = FormScripts.parseScan(raw);
      if (scan.fields.isEmpty) {
        final embedded = scan.frames
            .where((src) => _formHosts.any(src.contains))
            .firstOrNull;
        if (embedded != null) {
          _showMessage('Opening the application form…');
          await _controller.loadRequest(Uri.parse(embedded));
        } else {
          _showMessage(
            'No form found here yet. Open the application form, then tap '
            'Fill with Careerly.',
          );
        }
        return;
      }

      setState(() => _status = 'Drafting answers…');
      final applicant = await widget.loadApplicant();
      final brief = await widget.companyBrief?.call();
      final answers = await widget.filler.answer(
        fields: scan.fields,
        applicant: applicant,
        job: widget.job,
        companyBrief: brief,
      );
      if (!mounted) return;
      setState(() => _status = null);
      if (answers.isEmpty) {
        _showMessage(
          applicant.details.isEmpty
              ? 'Add your application details so Careerly can fill this form.'
              : 'Nothing here Careerly can fill for you. Fill it in on the page.',
        );
        return;
      }

      final chosen = await showFillReviewSheet(
        context,
        answers: answers,
        leftForYou: scan.fields.length - answers.length,
        detailsMissing: applicant.details.isEmpty,
        onAddDetails: () async {
          Navigator.of(context).pop();
          await widget.editDetails();
          if (mounted) _fill();
        },
      );
      if (chosen == null || chosen.isEmpty || !mounted) return;

      final filled = await _controller.runJavaScriptReturningResult(
        FormScripts.fill({for (final a in chosen) a.field.id: a.value}),
      );
      final count = filled is num ? filled.toInt() : int.tryParse('$filled') ?? 0;
      _showMessage(
        count == 0
            ? "Couldn't fill this form. Fill it in on the page."
            : 'Filled $count ${count == 1 ? 'field' : 'fields'}. Check the '
                'page, then submit it yourself.',
      );
    } catch (error) {
      if (mounted) _showMessage(writerErrorMessage(error));
    } finally {
      if (mounted && _status != null) setState(() => _status = null);
    }
  }

  Future<void> _openInBrowser() async {
    final current = Uri.tryParse(await _controller.currentUrl() ?? '') ?? widget.url;
    final opened = await widget.openExternally(current);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop(ApplyPageExit.openedExternally);
    } else {
      _showMessage("Couldn't open your browser.");
    }
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop(ApplyPageExit.closed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(bottom: BorderSide(color: colorScheme.outline)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        size: 44,
                        onPressed: () =>
                            Navigator.of(context).pop(ApplyPageExit.closed),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.job.company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _host,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (value) async {
                          if (value == 'reload') await _controller.reload();
                          if (value == 'browser') await _openInBrowser();
                          if (value == 'details') await widget.editDetails();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'reload',
                            child: ListTile(
                              leading: Icon(Icons.refresh_rounded),
                              title: Text('Reload'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'browser',
                            child: ListTile(
                              leading: Icon(Icons.open_in_new_rounded),
                              title: Text('Open in my browser'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'details',
                            child: ListTile(
                              leading: Icon(Icons.badge_outlined),
                              title: Text('Application details'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 2,
              child: _progress < 100
                  ? LinearProgressIndicator(
                      value: _progress / 100,
                      color: AppColors.accent,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _fill,
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.ink,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.ink,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(_status ?? 'Fill with Careerly'),
        ),
      ),
    );
  }
}
