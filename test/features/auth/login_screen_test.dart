import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careerly/features/auth/data/auth_repository.dart';
import 'package:careerly/features/auth/data/last_email_store.dart';
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

class _FakeLastEmailStore implements LastEmailStore {
  _FakeLastEmailStore([this.email]);

  String? email;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String email) async => this.email = email;
}

void main() {
  Future<_FakeAuthRepository> pumpLogin(
    WidgetTester tester, {
    _FakeLastEmailStore? store,
  }) async {
    // Reduce motion: skips the intro and the looping star animation.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    // Typical phone viewport.
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final repo = _FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authRepository: repo,
          lastEmailStore: store ?? _FakeLastEmailStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
    final store = _FakeLastEmailStore();
    final repo = await pumpLogin(tester, store: store);

    await tester.enterText(find.byType(TextFormField).first, ' me@careerly.app ');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'me@careerly.app');
    expect(store.email, 'me@careerly.app');
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

  testWidgets('remembered email only asks for a password', (tester) async {
    final repo = await pumpLogin(
      tester,
      store: _FakeLastEmailStore('me@careerly.app'),
    );

    expect(find.text('me@careerly.app'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(repo.lastEmail, 'me@careerly.app');

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
