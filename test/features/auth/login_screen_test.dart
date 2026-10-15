import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/auth/data/remembered_account_store.dart';
import 'package:careerly/features/auth/presentation/login_screen.dart';
import 'package:careerly/features/auth/presentation/signup_screen.dart';

import 'auth_test_utils.dart';

void main() {
  Future<FakeAuthRepository> pumpLogin(
    WidgetTester tester, {
    FakeRememberedAccountStore? store,
  }) async {
    final repo = FakeAuthRepository();
    await pumpAuthScreen(
      tester,
      LoginScreen(
        authRepository: repo,
        accountStore: store ?? FakeRememberedAccountStore(),
      ),
    );
    return repo;
  }

  testWidgets('shows validation errors when fields are empty', (tester) async {
    final repo = await pumpLogin(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(repo.lastEmail, isNull);
  });

  testWidgets('signs in with trimmed email and remembers it', (tester) async {
    final store = FakeRememberedAccountStore();
    final repo = await pumpLogin(tester, store: store);

    await tester.enterText(find.byType(TextFormField).first, ' me@careerly.app ');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'me@careerly.app');
    expect(store.account?.email, 'me@careerly.app');
  });

  testWidgets('shows a friendly message for wrong credentials', (tester) async {
    final repo = await pumpLogin(tester);
    repo.errorToThrow = const AuthException('Invalid login credentials');

    await tester.enterText(find.byType(TextFormField).first, 'me@careerly.app');
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text("That email and password don't match. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('remembered account greets by name and asks for password only',
      (tester) async {
    final repo = await pumpLogin(
      tester,
      store: FakeRememberedAccountStore(
        const RememberedAccount(email: 'me@careerly.app', name: 'Marc Esteban'),
      ),
    );

    expect(find.textContaining(',\nMarc'), findsOneWidget);
    expect(find.text('Marc Esteban'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(repo.lastEmail, 'me@careerly.app');

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('opens the sign-up screen', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
