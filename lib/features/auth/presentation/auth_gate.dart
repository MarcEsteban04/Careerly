import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/presentation/home_screen.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

/// Shows the login screen or the app depending on the current session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authRepository.authStateChanges,
      builder: (context, _) {
        final signedIn = authRepository.currentSession != null;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: signedIn
              ? HomeScreen(
                  key: const ValueKey('home'),
                  authRepository: authRepository,
                )
              : LoginScreen(
                  key: const ValueKey('login'),
                  authRepository: authRepository,
                ),
        );
      },
    );
  }
}
