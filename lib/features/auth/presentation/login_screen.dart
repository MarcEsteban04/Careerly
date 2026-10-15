import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/shake_effect.dart';
import '../data/auth_error_message.dart';
import '../data/auth_repository.dart';
import '../data/remembered_account_store.dart';
import 'signup_screen.dart';
import 'widgets/account_chip.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({
    super.key,
    required this.authRepository,
    RememberedAccountStore? accountStore,
  }) : accountStore = accountStore ?? RememberedAccountStore();

  final AuthRepository authRepository;
  final RememberedAccountStore accountStore;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeEffectState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  RememberedAccount? _account;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedAccount();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedAccount() async {
    final account = await widget.accountStore.read();
    if (!mounted || account == null) return;
    setState(() {
      _account = account;
      _emailController.text = account.email;
    });
  }

  void _forgetAccount() {
    setState(() {
      _account = null;
      _emailController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _openSignup() async {
    final confirmEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SignupScreen(authRepository: widget.authRepository),
      ),
    );
    if (!mounted || confirmEmail == null) return;
    // Account created but waiting on email confirmation.
    setState(() {
      _account = null;
      _emailController.text = confirmEmail;
      _passwordController.clear();
      _errorMessage = null;
      _infoMessage = 'Account created. Confirm your email, then sign in.';
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
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    try {
      await widget.authRepository.signIn(
        email: email,
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();
      await widget.accountStore.save(
        RememberedAccount(
          email: email,
          name: widget.authRepository.currentUserName,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _shakeKey.currentState?.shake();
      setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      setState(() {
        _errorMessage = null;
        _infoMessage = null;
      });
    }
  }

  static String _greeting(DateTime now, String? firstName) {
    final hour = now.hour;
    final base = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return firstName == null ? '$base,\nwelcome **back**' : '$base,\n**$firstName**';
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

  @override
  Widget build(BuildContext context) {
    final account = _account;

    return AuthScaffold(
      headline: _greeting(DateTime.now(), account?.firstName),
      subtitle: account == null
          ? 'Sign in to pick up where you left off.'
          : 'Enter your password to continue.',
      builder: (context, reveal) => _buildForm(reveal),
    );
  }

  Widget _buildForm(AuthReveal reveal) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final account = _account;
    final message = _errorMessage ?? _infoMessage;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            reveal(
              0.45,
              0.95,
              ShakeEffect(
                key: _shakeKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: account != null
                          ? AccountChip(
                              key: const ValueKey('account'),
                              account: account,
                              enabled: !_isSubmitting,
                              onChange: _forgetAccount,
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
              child: message == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: FormBanner(
                        message: message,
                        tone: _errorMessage != null
                            ? FormBannerTone.error
                            : FormBannerTone.success,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            reveal(
              0.55,
              1,
              PrimaryButton(
                label: 'Sign in',
                icon: Icons.arrow_forward_rounded,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            reveal(
              0.65,
              1,
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'New to Careerly?',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _openSignup,
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ],
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
        onChanged: (_) => _clearMessages(),
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
        onChanged: (_) => _clearMessages(),
        onFieldSubmitted: (_) => _submit(),
      ),
    );
  }
}
