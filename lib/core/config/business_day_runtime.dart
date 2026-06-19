import '../../models/business_day_model.dart';

/// جسر تشغيلي — يُحدَّث من [BusinessDayNotifier] لاستخدامه في طبقة الخدمات الثابتة.
abstract final class BusinessDayRuntime {
  BusinessDayRuntime._();

  static BusinessDayModel? openDay;

  static String? get openBusinessDayId => openDay?.id;

  static void apply(BusinessDayModel? day) {
    openDay = day?.isOpen == true ? day : null;
  }
}
