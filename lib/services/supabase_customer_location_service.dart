import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_delivery_profile.dart';
import '../models/saved_delivery_location_model.dart';

/// أسماء دوال RPC — لا تستخدم `.from('profiles')` لموقع الزبون.
abstract final class CustomerLocationRpc {
  /// جلب `has_saved_location`, `last_delivery_address`, الإحداثيات.
  static const getByPhone = 'get_customer_delivery_by_phone';

  /// حفظ/تحديث موحد (upsert حسب رقم الهاتف).
  static const updateLocation = 'update_customer_location';
}

/// قراءة/كتابة موقع التوصيل عبر RPC فقط.
abstract final class SupabaseCustomerLocationService {
  SupabaseCustomerLocationService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// جلب بيانات الزبون لصفحة إتمام الطلب (حسب `phone_number`).
  static Future<CustomerDeliveryProfile?> fetchCustomerByPhone({
    required String phoneNumber,
  }) async {
    final phone = phoneNumber.trim();
    if (phone.isEmpty) return null;

    try {
      final raw = await _client.rpc(
        CustomerLocationRpc.getByPhone,
        params: {'phone_number': phone},
      );

      final map = _parseRpcJsonMap(raw);
      if (map == null) return null;
      return CustomerDeliveryProfile.fromRpcRow(map, phoneNumber: phone);
    } catch (e, stack) {
      debugPrint(
        '[SupabaseCustomerLocationService] fetchCustomerByPhone: $e\n$stack',
      );
      return null;
    }
  }

  /// للتوافق مع الاستدعاءات القديمة.
  static Future<SavedDeliveryLocation?> fetchSavedLocation({
    required String phoneNumber,
  }) async {
    final profile = await fetchCustomerByPhone(phoneNumber: phoneNumber);
    return profile?.savedLocation;
  }

  /// كل حفظ موقع يمر عبر `update_customer_location` (تحديث أو إدراج مرة واحدة).
  static Future<void> updateCustomerLocation({
    required String phoneNumber,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final phone = phoneNumber.trim();
    if (phone.isEmpty) return;

    final payload = <String, dynamic>{
      'phone_number': phone,
      'lat': latitude,
      'lng': longitude,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
    };

    try {
      await _client.rpc(
        CustomerLocationRpc.updateLocation,
        params: payload,
      );
      debugPrint(
        '[SupabaseCustomerLocationService] update_customer_location '
        'phone=$phone lat=$latitude lng=$longitude',
      );
    } catch (e, stack) {
      debugPrint(
        '[SupabaseCustomerLocationService] updateCustomerLocation: $e\n$stack',
      );
    }
  }

  static Map<String, dynamic>? _parseRpcJsonMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return map.isEmpty ? null : map;
    }
    return null;
  }
}
