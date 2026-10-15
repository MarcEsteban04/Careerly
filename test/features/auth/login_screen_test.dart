import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/auth/data/auth_repository.dart';
import 'package:careerly/features/auth/presentation/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  Object? errorToThrow;
  String? lastEmail;

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_FakeAuthRepository> pumpLogin(WidgetTester tester) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authRepository: repo)),
    );
    return repo;
  }

  testWidgets('shows validation errors when fields are empty', (tester) async {
    final repo = await pumpLogin(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(repo.lastEmail, isNull);
  });

  testWidgets('signs in with trimmed email', (tester) async {
    final repo = await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, ' me@careerly.app ');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'me@careerly.app');
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
}
