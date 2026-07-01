import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/auth/admin_profile_session.dart';
import '../core/config/business_day_runtime.dart';
import '../models/business_day_model.dart';
import '../services/supabase_business_day_service.dart';

/// حالة يوم العمل اليدوي — مفتوح/مغلق + Realtime.
class BusinessDayNotifier extends ChangeNotifier {
  String? _restaurantId;
  String? _slug;
  BusinessDayModel? _openDay;
  bool _loading = true;
  bool _actionInProgress = false;
  StreamSubscription<BusinessDayModel?>? _subscription;
  bool _disposed = false;

  BusinessDayModel? get openDay => _openDay;
  bool get hasOpenDay => _openDay != null;
  bool get isLoading => _loading;
  bool get actionInProgress => _actionInProgress;

  Future<void> ensureScope({
    required String restaurantId,
    required String slug,
  }) async {
    final resolvedRestaurantId = _resolveRestaurantId(
      restaurantId: restaurantId,
      slug: slug,
    );
    final normalizedSlug = slug.trim();

    if (_restaurantId == resolvedRestaurantId && _slug == normalizedSlug) {
      return;
    }

    _restaurantId = resolvedRestaurantId;
    _slug = normalizedSlug;
    await refresh(force: true);
    _startWatch();
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    final restaurantId = _restaurantId;
    final slug = _slug;
    if (restaurantId == null || slug == null) {
      _applyOpenDay(null);
      return;
    }

    if (_loading || force) {
      if (_loading) notifyListeners();
    }

    try {
      final open = await SupabaseBusinessDayService.fetchOpenDay(
        restaurantId: restaurantId,
        slug: slug,
      );
      if (_disposed) return;
      _applyOpenDay(open);
    } catch (e, stack) {
      debugPrint('[BusinessDayNotifier] refresh failed: $e\n$stack');
      if (_disposed) return;
      _loading = false;
      notifyListeners();
    }
  }

  Future<BusinessDayModel> openBusinessDay() async {
    final restaurantId = _restaurantId;
    final slug = _slug;
    if (restaurantId == null || slug == null) {
      throw StateError('business_day_scope_missing');
    }

    _actionInProgress = true;
    notifyListeners();
    try {
      final opened = await SupabaseBusinessDayService.openDay(
        restaurantId: restaurantId,
        slug: slug,
      );
      _applyOpenDay(opened);
      return opened;
    } finally {
      _actionInProgress = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<BusinessDayModel> closeBusinessDay({String? notes}) async {
    final open = _openDay;
    final restaurantId = _restaurantId;
    if (open == null || restaurantId == null) {
      throw StateError(SupabaseBusinessDayService.noOpenDayCode);
    }

    _actionInProgress = true;
    notifyListeners();
    try {
      final closed = await SupabaseBusinessDayService.closeDay(
        restaurantId: restaurantId,
        notes: notes,
      );
      _applyOpenDay(null);
      return closed;
    } finally {
      _actionInProgress = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _startWatch() {
    unawaited(_subscription?.cancel());
    final restaurantId = _restaurantId;
    final slug = _slug;
    if (restaurantId == null || slug == null) return;

    _subscription = SupabaseBusinessDayService.watchOpenDay(
      restaurantId: restaurantId,
      slug: slug,
    ).listen(
      (day) {
        if (_disposed) return;
        _applyOpenDay(day);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint(
          '[BusinessDayNotifier] realtime error (ignored): $error\n$stack',
        );
      },
      cancelOnError: false,
    );
  }

  void _applyOpenDay(BusinessDayModel? day) {
    _openDay = day?.isOpen == true ? day : null;
    BusinessDayRuntime.apply(_openDay);
    _loading = false;
    if (kDebugMode) {
      debugPrint(
        '[BusinessDayNotifier] openDay=${_openDay?.id ?? 'none'}',
      );
    }
    notifyListeners();
  }

  static String _resolveRestaurantId({
    required String restaurantId,
    required String slug,
  }) {
    final sessionRestaurantId = AdminProfileSession.restaurantId?.trim();
    if (sessionRestaurantId != null && sessionRestaurantId.isNotEmpty) {
      return sessionRestaurantId.toLowerCase();
    }

    final trimmed = restaurantId.trim();
    if (trimmed.isNotEmpty) return trimmed.toLowerCase();
    return slug.trim().toLowerCase();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
