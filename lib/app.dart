import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';

class CareerlyApp extends StatelessWidget {
  const CareerlyApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Careerly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AuthGate(authRepository: authRepository),
    );
  }
}
