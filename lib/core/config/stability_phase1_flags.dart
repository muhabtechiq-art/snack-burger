/// Phase 1 rollout flags (strict rollback gate).
///
/// إذا ظهر أي سلوك غير مستقر في الإنتاج:
/// - عطّل `enablePhase1RealtimeHardening`
/// - سيعود التطبيق فوراً إلى مسار البث التقليدي (legacy).
abstract final class StabilityPhase1Flags {
  StabilityPhase1Flags._();

  /// تشغيل/إطفاء منطق البث المتقدم (reconnect + health).
  static const bool enablePhase1RealtimeHardening = true;

  /// نشر حالات الصحة للواجهة (live/reconnecting/stale...).
  static const bool enablePhase1HealthSignals = true;
}
