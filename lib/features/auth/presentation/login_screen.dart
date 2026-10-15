import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/form_error_banner.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_error_message.dart';
import '../data/auth_repository.dart';
import 'widgets/brand_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Welcome back', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Sign in to pick up where you left off.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LabeledField(
                        label: 'Email',
                        child: TextFormField(
                          controller: _emailController,
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
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
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            hintText: 'Your password',
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
                      PrimaryButton(
                        label: 'Sign in',
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: muted),
                          const SizedBox(width: AppSpacing.xxs + 2),
                          Text(
                            'Private workspace',
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
