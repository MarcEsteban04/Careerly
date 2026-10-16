import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/document_pdf.dart';

/// The finished PDF, exactly as it will look when sent: pinch to zoom,
/// then download or share it.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key, required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isDownloading = false;

  void _showMessage(String message) => Island.show(context, message);

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final saved = await DocumentPdf.download(
        title: widget.title,
        bytes: widget.bytes,
      );
      if (saved) {
        HapticFeedback.lightImpact();
        _showMessage('Saved ${DocumentPdf.fileNameFor(widget.title)}');
      }
    } catch (error) {
      debugPrint('PDF download failed: $error');
      _showMessage("Couldn't save the PDF. Try again.");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    try {
      await DocumentPdf.share(title: widget.title, bytes: widget.bytes);
    } catch (error) {
      debugPrint('PDF share failed: $error');
      _showMessage("Couldn't share the PDF. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerHighest,
        body: Column(
          children: [
            HeroHeader(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PDF preview',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              DocumentPdf.fileNameFor(widget.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CircleIconButton(
                        icon: Icons.ios_share_rounded,
                        tooltip: 'Share',
                        onPressed: _share,
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: PdfViewer.data(
                widget.bytes,
                sourceName: widget.title,
                params: PdfViewerParams(
                  margin: AppSpacing.md,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  pageDropShadow: BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  loadingBannerBuilder: (
                    context,
                    bytesDownloaded,
                    totalBytes,
                  ) => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            Container(
              color: colorScheme.surface,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm + bottomInset,
              ),
              child: PrimaryButton(
                label: 'Download PDF',
                icon: Icons.download_rounded,
                isLoading: _isDownloading,
                onPressed: _download,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
