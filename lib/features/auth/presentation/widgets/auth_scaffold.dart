import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/emphasis_text.dart';
import '../../../../core/widgets/header_wash.dart';

/// Fades and lifts [child] in during the screen's intro, between [begin] and
/// [end] (fractions of the intro).
typedef AuthReveal = Widget Function(double begin, double end, Widget child);

/// Shared layout for auth screens: logo and a bold headline on a soft wash,
/// with the form on a white sheet below. On wide screens the whole thing
/// becomes a centered card. Plays a staggered intro unless the system asks
/// to reduce motion.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.headline,
    required this.builder,
    this.subtitle,
    this.onBack,
  });

  /// Headline; wrap words in `**` to make them bold.
  final String headline;
  final String? subtitle;
  final Widget Function(BuildContext context, AuthReveal reveal) builder;

  /// Shows a back button when set.
  final VoidCallback? onBack;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  static const _wideBreakpoint = 840.0;
  static const _sheetRadius = 28.0;
  static const _logoAsset = 'assets/icons/careerly_logo.png';

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (_intro.isDismissed) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _reveal(double begin, double end, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Matches the sheet so it appears to run to the bottom edge.
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= _wideBreakpoint
                  ? _buildWide()
                  : _buildStacked(),
        ),
      ),
    );
  }

  Widget _buildStacked() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeaderWash(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl + _sheetRadius,
                ),
                child: _reveal(0, 0.6, _buildHeader()),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -_sheetRadius),
            child: _reveal(
              0.15,
              0.9,
              _Sheet(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetRadius),
                ),
                child: widget.builder(context, _reveal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWide() {
    return HeaderWash(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _reveal(0, 0.6, _buildHeader()),
                const SizedBox(height: AppSpacing.xl),
                _reveal(
                  0.15,
                  0.9,
                  _Sheet(
                    borderRadius: BorderRadius.circular(_sheetRadius),
                    topBorderOnly: false,
                    child: widget.builder(context, _reveal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.onBack != null) ...[
              CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: widget.onBack,
              ),
              const Spacer(),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                _logoAsset,
                width: 36,
                height: 36,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'Careerly logo',
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Careerly',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            if (widget.onBack != null) const Spacer(),
            if (widget.onBack != null) const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        EmphasisText(
          widget.headline,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.subtitle!,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// The white surface the form sits on.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.borderRadius,
    required this.child,
    this.topBorderOnly = true,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// Stacked layout: only the top edge is outlined, so the sheet blends
  /// into the page below it.
  final bool topBorderOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: borderRadius,
        border: topBorderOnly
            ? Border(top: BorderSide(color: colorScheme.outline))
            : Border.all(color: colorScheme.outline),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: child,
        ),
      ),
    );
  }
}
