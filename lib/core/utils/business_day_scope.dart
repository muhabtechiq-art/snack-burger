import '../../models/business_day_model.dart';

/// المصدر الوحيد لاستنتاج نطاق يوم العمل من سجل `business_days`.
abstract final class BusinessDayScope {
  BusinessDayScope._();

  static DateTime reportDateFor(BusinessDayModel day) {
    final opened = day.openedAt.toLocal();
    return DateTime(opened.year, opened.month, opened.day);
  }

  static bool orderBelongsToBusinessDay({
    required String? orderBusinessDayId,
    required String businessDayId,
  }) {
    if (orderBusinessDayId == null || orderBusinessDayId.trim().isEmpty) {
      return false;
    }
    return orderBusinessDayId.trim() == businessDayId.trim();
  }
}
