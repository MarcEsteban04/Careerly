import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careerly/features/auth/data/auth_repository.dart';
import 'package:careerly/features/auth/data/remembered_account_store.dart';

class FakeAuthRepository implements AuthRepository {
  Object? errorToThrow;
  bool signUpSignsIn = false;
  String? lastEmail;
  String? lastName;

  @override
  String? get currentUserName => lastName;

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    lastName = name;
    lastEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
    return signUpSignsIn;
  }

  String? avatarUrl;

  @override
  String? get currentUserAvatarUrl => avatarUrl;

  @override
  Future<void> setAvatarUrl(String? url) async => avatarUrl = url;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRememberedAccountStore implements RememberedAccountStore {
  FakeRememberedAccountStore([this.account]);

  RememberedAccount? account;

  @override
  Future<RememberedAccount?> read() async => account;

  @override
  Future<void> save(RememberedAccount account) async => this.account = account;
}

/// Pumps [screen] on a phone-sized view with reduced motion, so intro and
/// looping animations don't block `pumpAndSettle`.
Future<void> pumpAuthScreen(WidgetTester tester, Widget screen) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}
