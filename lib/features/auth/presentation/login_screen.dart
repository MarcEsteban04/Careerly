import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_error_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/shake_effect.dart';
import '../data/auth_error_message.dart';
import '../data/auth_repository.dart';
import '../data/last_email_store.dart';
import 'widgets/account_chip.dart';
import 'widgets/login_hero.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({
    super.key,
    required this.authRepository,
    LastEmailStore? lastEmailStore,
  }) : lastEmailStore = lastEmailStore ?? LastEmailStore();

  final AuthRepository authRepository;
  final LastEmailStore lastEmailStore;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _wideBreakpoint = 840.0;
  static const _panelRadius = 32.0;

  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeEffectState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  String? _rememberedEmail;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

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
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await widget.lastEmailStore.read();
    if (!mounted || email == null || email.isEmpty) return;
    setState(() {
      _rememberedEmail = email;
      _emailController.text = email;
    });
  }

  void _forgetRememberedEmail() {
    setState(() {
      _rememberedEmail = null;
      _emailController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    try {
      await widget.authRepository.signIn(
        email: email,
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();
      await widget.lastEmailStore.save(email);
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _shakeKey.currentState?.shake();
      setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  static String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password' : null;

  /// Fades and lifts a child in during the intro, between [begin] and [end].
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Matches the panel so it appears to run to the bottom edge.
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= _wideBreakpoint
                  ? _buildWideLayout()
                  : _buildStackedLayout(),
        ),
      ),
    );
  }

  /// Hero on top, form panel overlapping its bottom edge. The scaffold shares
  /// the panel's color, so the panel appears to run to the bottom of the
  /// screen however tall it is, and everything scrolls when space is tight
  /// (small phones, keyboard open).
  Widget _buildStackedLayout() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _reveal(
            0,
            0.6,
            LoginHero(
              compact: keyboardOpen,
              bottomInset: _panelRadius,
              minHeight: keyboardOpen
                  ? 0
                  : MediaQuery.sizeOf(context).height * 0.4 + _panelRadius,
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
                child: _buildForm(),
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
        Expanded(child: _reveal(0, 0.6, const SizedBox.expand(child: LoginHero()))),
        SizedBox(
          width: 520,
          child: _reveal(
            0.2,
            1,
            _Panel(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(_panelRadius),
              ),
              child: Center(child: SingleChildScrollView(child: _buildForm())),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final rememberedEmail = _rememberedEmail;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _reveal(
                  0.35,
                  0.85,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(DateTime.now()),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        rememberedEmail == null
                            ? 'Sign in to continue to your workspace.'
                            : 'Welcome back. Enter your password to continue.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _reveal(
                  0.45,
                  0.95,
                  ShakeEffect(
                    key: _shakeKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: rememberedEmail != null
                              ? AccountChip(
                                  key: const ValueKey('account'),
                                  email: rememberedEmail,
                                  enabled: !_isSubmitting,
                                  onChange: _forgetRememberedEmail,
                                )
                              : _buildEmailField(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildPasswordField(),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _errorMessage == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: FormErrorBanner(message: _errorMessage!),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _reveal(
                  0.55,
                  1,
                  PrimaryButton(
                    label: 'Sign in',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _reveal(
                  0.65,
                  1,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 15, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        'Private workspace',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return LabeledField(
      key: const ValueKey('email'),
      label: 'Email',
      child: TextFormField(
        controller: _emailController,
        enabled: !_isSubmitting,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        autocorrect: false,
        decoration: const InputDecoration(
          hintText: 'you@example.com',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
        validator: _validateEmail,
        onChanged: (_) => _clearError(),
        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
      ),
    );
  }

  Widget _buildPasswordField() {
    return LabeledField(
      label: 'Password',
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        enabled: !_isSubmitting,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          hintText: 'Your password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: _validatePassword,
        onChanged: (_) => _clearError(),
        onFieldSubmitted: (_) => _submit(),
      ),
    );
  }
}

/// The rounded surface the form sits on.
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
