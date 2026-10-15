import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/data/auth_repository.dart';

/// Placeholder home until the main app screens are designed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Careerly'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: authRepository.signOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            "You're signed in.",
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
