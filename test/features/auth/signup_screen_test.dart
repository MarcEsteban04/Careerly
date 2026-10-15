import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/auth/presentation/signup_screen.dart';
import 'package:careerly/features/auth/presentation/widgets/password_strength_meter.dart';

import 'auth_test_utils.dart';

void main() {
  Future<FakeAuthRepository> pumpSignup(WidgetTester tester) async {
    final repo = FakeAuthRepository();
    await pumpAuthScreen(tester, SignupScreen(authRepository: repo));
    return repo;
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Marc Esteban',
    String email = 'me@careerly.app',
    String password = 'career2026',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), password);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('validates every field', (tester) async {
    final repo = await pumpSignup(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Create a password'), findsWidgets);
    expect(repo.lastEmail, isNull);
  });

  testWidgets('rejects passwords without a number', (tester) async {
    final repo = await pumpSignup(tester);

    await fillForm(tester, password: 'onlyletters');

    expect(
      find.text('Include at least one letter and one number'),
      findsOneWidget,
    );
    expect(repo.lastEmail, isNull);
  });

  testWidgets('shows "check your inbox" when confirmation is required',
      (tester) async {
    final repo = await pumpSignup(tester);

    await fillForm(tester, email: ' me@careerly.app ');

    expect(repo.lastName, 'Marc Esteban');
    expect(repo.lastEmail, 'me@careerly.app');
    expect(find.text('Check your inbox'), findsOneWidget);
  });

  testWidgets('shows a friendly message when the email is taken',
      (tester) async {
    final repo = await pumpSignup(tester);
    repo.errorToThrow = const AuthException('User already registered');

    await fillForm(tester);

    expect(
      find.text('An account with this email already exists. Try signing in.'),
      findsOneWidget,
    );
  });

  test('password strength scoring', () {
    expect(passwordStrengthOf(''), PasswordStrength.empty);
    expect(passwordStrengthOf('abc12'), PasswordStrength.weak);
    expect(passwordStrengthOf('abcdefgh'), PasswordStrength.fair);
    expect(passwordStrengthOf('abcdefg1'), PasswordStrength.fair);
    expect(passwordStrengthOf('Abcdefg1'), PasswordStrength.good);
    expect(passwordStrengthOf('Abcdefgh1!xyz'), PasswordStrength.strong);
  });
}
