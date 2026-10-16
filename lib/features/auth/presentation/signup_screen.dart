import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_banner.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/shake_effect.dart';
import '../data/auth_error_message.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_strength_meter.dart';

/// Creates an account. If Supabase signs the user in straight away the auth
/// gate takes over; if the email must be confirmed first, shows a "check your
/// inbox" state and pops with the email so login can prefill it.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeEffectState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  /// Set once the account is created and awaiting email confirmation.
  String? _pendingConfirmationEmail;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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
      final signedIn = await widget.authRepository.signUp(
        name: _nameController.text.trim(),
        email: email,
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();
      if (!signedIn && mounted) {
        setState(() => _pendingConfirmationEmail = email);
      }
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

  static String? _validateName(String? value) =>
      (value?.trim() ?? '').isEmpty ? 'Enter your name' : null;

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Create a password';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingConfirmationEmail != null;

    return AuthScaffold(
      headline: pending
          ? 'Almost **there**'
          : "Let's get you **hired** for the job you **deserve**",
      subtitle: pending
          ? 'One quick step to confirm your email.'
          : 'Create your private Careerly workspace.',
      onBack: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
      builder: (context, reveal) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pendingConfirmationEmail == null
            ? _buildForm(reveal)
            : _buildCheckInbox(_pendingConfirmationEmail!),
      ),
    );
  }

  Widget _buildForm(AuthReveal reveal) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AutofillGroup(
      key: const ValueKey('form'),
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
                    LabeledField(
                      label: 'Full name',
                      child: TextFormField(
                        controller: _nameController,
                        enabled: !_isSubmitting,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: _validateName,
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LabeledField(
                      label: 'Email',
                      child: TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: _validateEmail,
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LabeledField(
                      label: 'Password',
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          hintText: 'Create a password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PasswordStrengthMeter(password: _passwordController.text),
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
                      child: FormBanner(message: _errorMessage!),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            reveal(
              0.55,
              1,
              PrimaryButton(
                label: 'Create account',
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
                    'Already have an account?',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInbox(String email) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('check-inbox'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: const IconBadge(
            icon: Icons.mark_email_unread_rounded,
            size: 64,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Check your inbox',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'We sent a confirmation link to '),
              TextSpan(
                text: email,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '. Open it, then come back to sign in.'),
            ],
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).pop(email),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Can't find it? Check your spam folder.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
