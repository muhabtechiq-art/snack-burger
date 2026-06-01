import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_profile_session.dart';

/// حالة المصادقة — لا يُعتبر المسؤول مخوّلاً إلا بعد await لجلب profiles.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _session = Supabase.instance.client.auth.currentSession;
    _lastAuthUserId = _session?.user.id;
    _readyFuture = _bootstrap();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
    );
  }

  Session? _session;
  StreamSubscription<AuthState>? _subscription;
  Future<void>? _readyFuture;
  Future<void>? _profileResolveFuture;

  bool _authResolving = true;
  bool _profileLoadFailed = false;
  String? _lastAuthUserId;

  bool get isAuthResolving => _authResolving;

  bool get profileLoadFailed => _profileLoadFailed;

  bool get isAuthenticated => _session != null;

  bool get hasAdminProfile {
    final id = AdminProfileSession.restaurantId;
    return id != null && id.trim().isNotEmpty;
  }

  bool get isAdminAuthorized => isAuthenticated && hasAdminProfile;

  User? get currentUser => _session?.user;

  String? get userEmail => currentUser?.email;

  /// ينتظر اكتمال bootstrap الأولي.
  Future<void> waitUntilReady() async {
    await (_readyFuture ?? Future<void>.value());
  }

  /// يُستدعى من GoRouter قبل أي قرار توجيه — ينتظر profiles إن وُجدت جلسة.
  Future<void> ensureReadyForRouting({required bool needsAdminProfile}) async {
    await waitUntilReady();
    _session = Supabase.instance.client.auth.currentSession;

    if (!needsAdminProfile) return;

    if (_session == null) {
      _profileLoadFailed = false;
      return;
    }

    if (hasAdminProfile) {
      _profileLoadFailed = false;
      return;
    }

    await _resolveProfileOnce();
  }

  /// بعد signInWithPassword — ينتظر profiles ثم يُحدّث الحالة.
  Future<bool> completeAdminSignIn() async {
    _session = Supabase.instance.client.auth.currentSession;
    _lastAuthUserId = _session?.user.id;
    _profileLoadFailed = false;

    if (_session == null) {
      debugPrint('[AuthNotifier] completeAdminSignIn — no session');
      return false;
    }

    await _resolveProfileOnce();
    return isAdminAuthorized;
  }

  Future<void> _bootstrap() async {
    _authResolving = true;
    notifyListeners();

    try {
      _session = Supabase.instance.client.auth.currentSession;
      _lastAuthUserId = _session?.user.id;

      if (_session != null && !hasAdminProfile) {
        debugPrint('[AuthNotifier] bootstrap — loading profile');
        await _resolveProfileOnce();
      }
    } finally {
      if (_profileResolveFuture == null) {
        _authResolving = false;
      }
      debugPrint(
        '[AuthNotifier] bootstrap done — '
        'authenticated=$isAuthenticated authorized=$isAdminAuthorized '
        'restaurantId=${AdminProfileSession.restaurantId}',
      );
      notifyListeners();
    }
  }

  Future<void> _resolveProfileOnce() {
    _profileResolveFuture ??= _loadProfileInternal().whenComplete(() {
      _profileResolveFuture = null;
    });
    return _profileResolveFuture!;
  }

  Future<void> _loadProfileInternal() async {
    _authResolving = true;
    _profileLoadFailed = false;
    notifyListeners();

    try {
      final ok = await loadAdminProfile(signOutOnFailure: false);
      _profileLoadFailed = !ok;
    } finally {
      _authResolving = false;
      debugPrint(
        '[AuthNotifier] profile resolve done — '
        'authorized=$isAdminAuthorized failed=$_profileLoadFailed',
      );
      notifyListeners();
    }
  }

  void _handleAuthStateChange(AuthState data) {
    final session = data.session;
    final userId = session?.user.id;
    final event = data.event;

    debugPrint(
      '[AuthNotifier] onAuthStateChange event=$event userId=$userId '
      'prevUserId=$_lastAuthUserId',
    );

    if (session == null) {
      _session = null;
      _lastAuthUserId = null;
      _profileLoadFailed = false;
      _authResolving = false;
      unawaited(AdminProfileSession.clear());
      notifyListeners();
      return;
    }

    final sameUser = userId == _lastAuthUserId;
    if (sameUser && hasAdminProfile && !_authResolving) {
      debugPrint('[AuthNotifier] skip — same user with profile');
      return;
    }

    _session = session;
    _lastAuthUserId = userId;

    if (hasAdminProfile) {
      _profileLoadFailed = false;
      notifyListeners();
      return;
    }

    unawaited(_resolveProfileOnce());
  }

  Future<bool> loadAdminProfile({required bool signOutOnFailure}) async {
    final uid =
        _session?.user.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      debugPrint('[AuthNotifier] loadAdminProfile — no uid');
      return false;
    }

    try {
      debugPrint('[AuthNotifier] loadAdminProfile — fetching profiles.id=$uid');
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('restaurant_id, role')
          .eq('id', uid)
          .maybeSingle();

      if (profile == null) {
        debugPrint(
          '[AuthNotifier] loadAdminProfile — null (RLS or missing row)',
        );
        if (signOutOnFailure) await signOut();
        return false;
      }

      final restaurantId = profile['restaurant_id']?.toString().trim() ?? '';
      final role = profile['role']?.toString().trim() ?? '';

      if (restaurantId.isEmpty) {
        debugPrint('[AuthNotifier] loadAdminProfile — empty restaurant_id');
        if (signOutOnFailure) await signOut();
        return false;
      }

      await AdminProfileSession.save(
        restaurantId: restaurantId,
        role: role,
      );
      debugPrint(
        '[AuthNotifier] loadAdminProfile OK — '
        'restaurantId=$restaurantId role=$role',
      );
      return true;
    } on PostgrestException catch (e, stack) {
      debugPrint(
        '[AuthNotifier] loadAdminProfile RLS failed: '
        '${e.code} ${e.message}\n$stack',
      );
      if (signOutOnFailure) await signOut();
      return false;
    } catch (e, stack) {
      debugPrint('[AuthNotifier] loadAdminProfile error: $e\n$stack');
      if (signOutOnFailure) await signOut();
      return false;
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    debugPrint('[AuthNotifier] signOut');
    await Supabase.instance.client.auth.signOut();
    await AdminProfileSession.clear();
    _session = null;
    _lastAuthUserId = null;
    _profileLoadFailed = false;
    _authResolving = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
