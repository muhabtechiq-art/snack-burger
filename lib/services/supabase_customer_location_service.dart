import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_delivery_profile.dart';
import '../models/saved_delivery_location_model.dart';
import 'supabase_error_reporter.dart';

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

  static const String _logTag = 'SupabaseCustomerLocationService';

  static SupabaseClient get _client => Supabase.instance.client;

  static void _log(
    String method,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (error == null) {
      debugPrint('$_logTag.$method: $message');
      return;
    }
    debugPrint('$_logTag.$method: $message\n$error${stack != null ? '\n$stack' : ''}');
  }

  static String? _normalizePhone(String phoneNumber) {
    final phone = phoneNumber.trim();
    return phone.isEmpty ? null : phone;
  }

  static Map<String, dynamic> _buildLocationUpdatePayload({
    required String restaurantId,
    required String phone,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    return <String, dynamic>{
      'phone_number': phone,
      'restaurant_id': restaurantId,
      'lat': latitude,
      'lng': longitude,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
    };
  }

  static String? _normalizeRestaurantId(String? restaurantId) {
    final id = restaurantId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<T?> _runRpcSafely<T>({
    required String method,
    required Future<T?> Function() action,
  }) async {
    try {
      return await action();
    } catch (e, stack) {
      _log(method, 'failed', error: e, stack: stack);
      reportSupabaseError(e, stack, operation: method);
      return null;
    }
  }

  /// جلب بيانات الزبون لصفحة إتمام الطلب (حسب `phone_number`).
  static Future<CustomerDeliveryProfile?> fetchCustomerByPhone({
    required String phoneNumber,
  }) async {
    final phone = _normalizePhone(phoneNumber);
    if (phone == null) return null;

    return _runRpcSafely(
      method: 'fetchCustomerByPhone',
      action: () async {
        final raw = await _client.rpc(
          CustomerLocationRpc.getByPhone,
          params: {'phone_number': phone},
        );

        final map = _parseRpcJsonMap(raw);
        if (map == null) return null;
        return CustomerDeliveryProfile.fromRpcRow(map, phoneNumber: phone);
      },
    );
  }

  /// للتوافق مع الاستدعاءات القديمة.
  static Future<SavedDeliveryLocation?> fetchSavedLocation({
    required String phoneNumber,
  }) async {
    final profile = await fetchCustomerByPhone(phoneNumber: phoneNumber);
    return profile?.savedLocation;
  }

  /// كل حفظ موقع يمر عبر `update_customer_location` (تحديث أو إدراج مرة واحدة).
  /// فشل الحفظ لا يُبلّغ الزبون — الطلب قد يكون اكتمل بنجاح.
  static Future<void> updateCustomerLocation({
    required String restaurantId,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final phone = _normalizePhone(phoneNumber);
    if (phone == null) return;

    final normalizedRestaurantId = _normalizeRestaurantId(restaurantId);
    if (normalizedRestaurantId == null) {
      _log(
        'updateCustomerLocation',
        'skipped: restaurant_id is missing (phone=$phone)',
      );
      return;
    }

    try {
      await _client.rpc(
        CustomerLocationRpc.updateLocation,
        params: _buildLocationUpdatePayload(
          restaurantId: normalizedRestaurantId,
          phone: phone,
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
      );
      _log(
        'updateCustomerLocation',
        'saved phone=$phone restaurant_id=$normalizedRestaurantId '
        'lat=$latitude lng=$longitude',
      );
    } catch (e, stack) {
      _log(
        'updateCustomerLocation',
        'failed silently after order (phone=$phone): $e',
        error: e,
        stack: stack,
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
