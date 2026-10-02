import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_management_auth.dart';

/// Signs the currently authenticated Store Management user out after a period
/// with no interaction anywhere in the application.
class StoreManagementInactivityLogoutGuard extends StatefulWidget {
  const StoreManagementInactivityLogoutGuard({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 3),
  });

  final Widget child;
  final Duration timeout;

  @override
  State<StoreManagementInactivityLogoutGuard> createState() =>
      _StoreManagementInactivityLogoutGuardState();
}

class _StoreManagementInactivityLogoutGuardState
    extends State<StoreManagementInactivityLogoutGuard> {
  final _auth = const StoreManagementAuth();
  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _timer?.cancel();
      } else {
        _restartTimer();
      }
    });
    _restartTimer();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _authSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _recordActivity();
    }
    return false;
  }

  void _recordActivity() {
    if (_loggingOut) return;
    if (_auth.session == null) {
      _timer?.cancel();
      return;
    }
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_auth.session == null || widget.timeout <= Duration.zero) return;
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    if (_loggingOut || _auth.session == null) return;
    _loggingOut = true;
    _timer?.cancel();

    try {
      await _auth.signOut();
    } finally {
      _loggingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: widget.child,
    );
  }
}
