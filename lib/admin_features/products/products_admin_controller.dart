import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/product_model.dart';
import '../data/admin_repositories.dart';

/// إدارة منتجات لوحة الإدارة — fetch + realtime مع lifecycle آمن.
class ProductsAdminController extends ChangeNotifier {
  ProductsAdminController({
    AdminProductRepository? repository,
    this.onRealtimeDegraded,
  }) : _repository = repository ?? AdminProductRepository();

  static const List<Duration> _realtimeRetryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  static const Duration _realtimeHandshakeTimeout = Duration(seconds: 12);

  final AdminProductRepository _repository;
  final VoidCallback? onRealtimeDegraded;

  StreamSubscription<List<ProductModel>>? _subscription;
  int _bindGeneration = 0;
  bool _disposed = false;

  String? _restaurantId;
  String? _slug;

  List<ProductModel> _products = const [];
  bool _loading = true;
  bool _realtimeActive = false;

  List<ProductModel> get products => _products;
  bool get loading => _loading;
  bool get realtimeActive => _realtimeActive;
  bool get hasProducts => _products.isNotEmpty;

  /// Flutter Web على الموبايل — realtime معطّل؛ fetch فقط.
  static bool get enableProductsRealtime {
    if (kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return false;
    }
    return true;
  }

  /// ربط المطعم — fetch ثم realtime (إن كان مفعّلاً).
  Future<void> bind({
    required String restaurantId,
    required String slug,
  }) async {
    if (_disposed) return;
    if (_restaurantId == restaurantId && _slug == slug && _products.isNotEmpty) {
      return;
    }

    _restaurantId = restaurantId;
    _slug = slug;
    final generation = ++_bindGeneration;

    await stopRealtime();
    _loading = true;
    _realtimeActive = false;
    notifyListeners();

    await loadProducts();
    if (_disposed || generation != _bindGeneration) return;

    if (!enableProductsRealtime) return;

    await reconnectRealtime(
      showDegradedToast: false,
      bindGeneration: generation,
    );
  }

  /// جلب المنتجات عبر select — بدون realtime.
  Future<void> loadProducts() async {
    final restaurantId = _restaurantId;
    final slug = _slug;
    if (restaurantId == null || slug == null || _disposed) return;

    try {
      final items = await _repository.fetchProducts(
        restaurantId: restaurantId,
        slug: slug,
      );
      if (_disposed) return;
      _products = List<ProductModel>.unmodifiable(items);
      _loading = false;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('[ProductsAdminController] loadProducts: $error\n$stack');
      if (_disposed) return;
      _loading = false;
      notifyListeners();
    }
  }

  /// يبدأ اشتراك realtime — يُفضّل استدعاء [reconnectRealtime].
  Future<void> startRealtime() {
    if (!enableProductsRealtime) return Future<void>.value();
    return reconnectRealtime(showDegradedToast: false);
  }

  /// يلغي اشتراك realtime دون مسح القائمة.
  Future<void> stopRealtime() async {
    await _subscription?.cancel();
    _subscription = null;
    _realtimeActive = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// إعادة الاتصال: 3 محاولات (1s → 2s → 4s).
  Future<void> reconnectRealtime({
    bool showDegradedToast = true,
    int? bindGeneration,
  }) async {
    if (!enableProductsRealtime) return;
    if (_disposed || _restaurantId == null || _slug == null) return;

    final generation = bindGeneration ?? ++_bindGeneration;
    await stopRealtime();

    for (var attempt = 0; attempt < _realtimeRetryDelays.length; attempt++) {
      if (_disposed || generation != _bindGeneration) return;

      final connected = await _subscribeOnce(generation: generation);
      if (connected) {
        _realtimeActive = true;
        if (!_disposed) notifyListeners();
        return;
      }

      if (attempt < _realtimeRetryDelays.length - 1) {
        await Future<void>.delayed(_realtimeRetryDelays[attempt]);
      }
    }

    _realtimeActive = false;
    if (!_disposed) notifyListeners();
    if (showDegradedToast && hasProducts) {
      onRealtimeDegraded?.call();
    }
  }

  void handleLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        unawaited(stopRealtime());
      case AppLifecycleState.resumed:
        unawaited(_onResumed());
      case AppLifecycleState.detached:
        unawaited(stopRealtime());
    }
  }

  Future<void> _onResumed() async {
    if (_disposed || _restaurantId == null || _slug == null) return;
    await stopRealtime();

    if (!enableProductsRealtime) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed) return;
      await loadProducts();
      return;
    }

    await loadProducts();
    await reconnectRealtime(bindGeneration: ++_bindGeneration);
  }

  Future<bool> _subscribeOnce({required int generation}) async {
    final restaurantId = _restaurantId!;
    final slug = _slug!;

    await _subscription?.cancel();
    _subscription = null;

    final completer = Completer<bool>();
    Timer? handshakeTimer;

    void completeOnce(bool value) {
      if (completer.isCompleted) return;
      handshakeTimer?.cancel();
      completer.complete(value);
    }

    _subscription = _repository
        .watchProducts(restaurantId: restaurantId, slug: slug)
        .listen(
      (List<ProductModel> items) {
        if (_disposed || generation != _bindGeneration) return;
        _products = List<ProductModel>.unmodifiable(items);
        _loading = false;
        completeOnce(true);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint(
          '[ProductsAdminController] realtime error (swallowed): '
          '$error\n$stack',
        );
        completeOnce(false);
      },
      cancelOnError: false,
    );

    handshakeTimer = Timer(_realtimeHandshakeTimeout, () {
      completeOnce(false);
    });

    final connected = await completer.future;
    if (!connected) {
      await _subscription?.cancel();
      _subscription = null;
    }
    return connected;
  }

  @override
  void dispose() {
    _disposed = true;
    _bindGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
