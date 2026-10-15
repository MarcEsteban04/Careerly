import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import 'auth_hero.dart';

/// Fades and lifts [child] in during the screen's intro, between [begin] and
/// [end] (fractions of the intro).
typedef AuthReveal = Widget Function(double begin, double end, Widget child);

/// Shared layout for auth screens: brand hero on top with the content on a
/// rounded panel overlapping it, or side by side on wide screens. Plays a
/// staggered intro unless the system asks to reduce motion.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.builder,
    this.onBack,
    this.heroHeightFactor = 0,
    this.compactHero = false,
  });

  final Widget Function(BuildContext context, AuthReveal reveal) builder;

  /// Shows a back button over the hero when set.
  final VoidCallback? onBack;

  /// Minimum hero height as a fraction of the screen (stacked layout only).
  final double heroHeightFactor;

  /// Always use the smaller hero, e.g. for longer forms.
  final bool compactHero;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  static const _wideBreakpoint = 840.0;
  static const _panelRadius = 32.0;

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  Widget _content() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: widget.builder(context, _reveal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Matches the panel so it appears to run to the bottom edge.
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= _wideBreakpoint
                      ? _buildWideLayout()
                      : _buildStackedLayout(),
            ),
            if (widget.onBack != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: widget.onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Hero on top, panel overlapping its bottom edge. Everything scrolls when
  /// space is tight (small phones, keyboard open).
  Widget _buildStackedLayout() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final heroMinHeight = keyboardOpen
        ? 0.0
        : MediaQuery.sizeOf(context).height * widget.heroHeightFactor +
            _panelRadius;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _reveal(
            0,
            0.6,
            AuthHero(
              compact: widget.compactHero || keyboardOpen,
              bottomInset: _panelRadius,
              minHeight: heroMinHeight,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -_panelRadius),
            child: _reveal(
              0.2,
              1,
              _Panel(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_panelRadius),
                ),
                child: _content(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          child: _reveal(0, 0.6, const SizedBox.expand(child: AuthHero())),
        ),
        SizedBox(
          width: 520,
          child: _reveal(
            0.2,
            1,
            _Panel(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(_panelRadius),
              ),
              child: Center(child: SingleChildScrollView(child: _content())),
            ),
          ),
        ),
      ],
    );
  }
}

/// The rounded surface the content sits on.
class _Panel extends StatelessWidget {
  const _Panel({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: child,
    );
  }
}
