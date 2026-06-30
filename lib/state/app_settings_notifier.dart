import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/restaurant_slug_utils.dart';
import '../models/app_settings_model.dart';
import '../services/supabase_app_settings_service.dart';

/// حالة إعدادات التطبيق العامة — وضع الصيانة وأرقام الطوارئ.
class AppSettingsNotifier extends ChangeNotifier {
  AppSettingsModel _settings = AppSettingsModel.defaults();
  bool _loading = true;
  bool _emergencyFallback = false;
  StreamSubscription<AppSettingsModel>? _subscription;
  bool _disposed = false;

  /// معرّف المطعم الحالي لقراءة إعدادات scoped — null = المسار العالمي.
  String? _restaurantId;

  AppSettingsModel get settings => _settings;
  bool get isLoading => _loading;
  bool get maintenanceMode => _settings.maintenanceMode;
  bool get emergencyFallback => _emergencyFallback;
  String? get restaurantId => _restaurantId;

  /// هل يُحجَب واجهة الزبون بالكامل؟
  bool get shouldBlockCustomerApp =>
      _settings.maintenanceMode || _emergencyFallback;

  static const Duration _foregroundRefreshDebounce = Duration(seconds: 2);
  DateTime? _lastForegroundRefreshAt;

  Future<void> initialize() async {
    await refresh(force: true);
    _startRealtime();
  }

  /// يربط القراءة بمطعم محدد عبر slug — قراءة scoped مع fallback إلى global.
  /// لا يمسّ البث (realtime) ولا الحفظ. لا يعيد التحميل إن لم يتغيّر المطعم.
  Future<void> bindRestaurant(String slug) async {
    if (_disposed) return;
    final normalized = normalizeRestaurantSlug(slug);
    if (normalized.isEmpty || normalized == _restaurantId) return;
    _restaurantId = normalized;
    await refresh(force: true);
    if (_disposed) return;
    _startRealtime();
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;

    final now = DateTime.now();
    if (!force) {
      final last = _lastForegroundRefreshAt;
      if (last != null && now.difference(last) < _foregroundRefreshDebounce) {
        return;
      }
    }
    _lastForegroundRefreshAt = now;

    if (_loading) notifyListeners();

    try {
      final fetched = await SupabaseAppSettingsService.fetch(
        restaurantId: _restaurantId,
      );
      if (_disposed) return;
      _applySettings(fetched, clearEmergency: fetched.maintenanceMode);
    } catch (_) {
      if (_disposed) return;
      _loading = false;
      notifyListeners();
    }
  }

  Future<AppSettingsModel> saveSettings(AppSettingsModel next) async {
    final saved = await SupabaseAppSettingsService.save(
      next,
      restaurantId: _restaurantId,
    );
    if (_disposed) return saved;
    _applySettings(saved, clearEmergency: saved.maintenanceMode);
    return saved;
  }

  void activateEmergencyFallback() {
    if (_emergencyFallback) return;
    _emergencyFallback = true;
    if (kDebugMode) {
      debugPrint('[AppSettingsNotifier] emergency maintenance fallback ON');
    }
    notifyListeners();
  }

  void clearEmergencyFallback() {
    if (!_emergencyFallback) return;
    _emergencyFallback = false;
    notifyListeners();
  }

  void _startRealtime() {
    unawaited(_subscription?.cancel());
    _subscription =
        SupabaseAppSettingsService.watchSettings(
          restaurantId: _restaurantId,
        ).listen(
          (settings) {
            if (_disposed) return;
            _applySettings(settings, clearEmergency: settings.maintenanceMode);
          },
          onError: (Object error, StackTrace stack) {
            debugPrint(
              '[AppSettingsNotifier] realtime settings error (ignored): '
              '$error\n$stack',
            );
          },
          cancelOnError: false,
        );
  }

  void _applySettings(AppSettingsModel next, {bool clearEmergency = false}) {
    _settings = next;
    _loading = false;
    if (clearEmergency && !_settings.maintenanceMode) {
      _emergencyFallback = false;
    }
    if (kDebugMode) {
      debugPrint(
        '[AppSettingsNotifier] maintenanceMode=${_settings.maintenanceMode} '
        'emergencyFallback=$_emergencyFallback',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
