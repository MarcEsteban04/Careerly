import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/header_wash.dart';
import '../../shell/presentation/app_shell.dart';
import '../data/app_lock_repository.dart';
import '../data/auth_repository.dart';
import '../data/remembered_account_store.dart';
import 'login_screen.dart';
import 'unlock_screen.dart';
import 'widgets/enable_app_lock_sheet.dart';

enum _GateStatus { loading, signedOut, locked, unlocked }

/// Decides what the user sees: login, the biometric lock, or the app.
/// Also re-locks the app after it's been in the background for a while.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.appLock,
  });

  final AuthRepository authRepository;
  final AppLockRepository appLock;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  static const _relockAfter = Duration(minutes: 1);

  late final StreamSubscription<AuthState> _authSubscription;
  _GateStatus _status = _GateStatus.loading;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription =
        widget.authRepository.authStateChanges.listen(_onAuthStateChanged);
    _resolveInitialStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _resolveInitialStatus() async {
    if (widget.authRepository.currentSession == null) {
      setState(() => _status = _GateStatus.signedOut);
      return;
    }
    final locked = await widget.appLock.isEnabled();
    if (!mounted || _status != _GateStatus.loading) return;
    setState(() => _status = locked ? _GateStatus.locked : _GateStatus.unlocked);
  }

  void _onAuthStateChanged(AuthState state) {
    if (!mounted) return;
    final signedIn = state.session != null;

    if (!signedIn && _status != _GateStatus.signedOut) {
      setState(() => _status = _GateStatus.signedOut);
    } else if (signedIn && _status == _GateStatus.signedOut) {
      // Fresh password sign-in (or sign-up): close any auth routes on top
      // (e.g. the sign-up screen) and go straight in.
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _status = _GateStatus.unlocked);
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerAppLock());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (_status == _GateStatus.unlocked &&
          backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= _relockAfter) {
        _relockIfEnabled();
      }
    }
  }

  Future<void> _relockIfEnabled() async {
    if (!await widget.appLock.isEnabled() || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _status = _GateStatus.locked);
  }

  Future<void> _offerAppLock() async {
    final appLock = widget.appLock;
    if (await appLock.isEnabled() ||
        await appLock.wasOffered() ||
        !await appLock.canUseBiometrics()) {
      return;
    }
    await appLock.markOffered();
    if (!mounted) return;

    if (!await showEnableAppLockSheet(context)) return;
    // Confirm the user can actually unlock before turning it on.
    if (await appLock.authenticate(reason: 'Turn on biometric unlock') !=
        UnlockResult.success) {
      return;
    }
    await appLock.setEnabled(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Biometric unlock is on')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_status) {
      _GateStatus.loading => const HeaderWash(
          key: ValueKey('loading'),
          child: SizedBox.expand(),
        ),
      _GateStatus.signedOut => LoginScreen(
          key: const ValueKey('login'),
          authRepository: widget.authRepository,
        ),
      _GateStatus.locked => _LockedView(
          key: const ValueKey('locked'),
          appLock: widget.appLock,
          onUnlocked: () => setState(() => _status = _GateStatus.unlocked),
          onUsePassword: widget.authRepository.signOut,
        ),
      _GateStatus.unlocked => AppShell(
          key: const ValueKey('app'),
          authRepository: widget.authRepository,
          appLock: widget.appLock,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}

/// Loads the remembered first name for the unlock greeting.
class _LockedView extends StatefulWidget {
  const _LockedView({
    super.key,
    required this.appLock,
    required this.onUnlocked,
    required this.onUsePassword,
  });

  final AppLockRepository appLock;
  final VoidCallback onUnlocked;
  final VoidCallback onUsePassword;

  @override
  State<_LockedView> createState() => _LockedViewState();
}

class _LockedViewState extends State<_LockedView> {
  late final _account = RememberedAccountStore().read();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RememberedAccount?>(
      future: _account,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const HeaderWash(
            child: SizedBox.expand(),
          );
        }
        return UnlockScreen(
          appLock: widget.appLock,
          firstName: snapshot.data?.firstName,
          onUnlocked: widget.onUnlocked,
          onUsePassword: widget.onUsePassword,
        );
      },
    );
  }
}
