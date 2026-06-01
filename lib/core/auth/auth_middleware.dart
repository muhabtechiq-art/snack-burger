import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'admin_profile_session.dart';
import 'auth_notifier.dart';

/// RBAC — ينتظر await profiles قبل قرار التوجيه.
abstract final class AuthMiddleware {
  AuthMiddleware._();

  static bool isAdminPath(String location) {
    return location.toLowerCase().contains('/admin');
  }

  static bool isAdminLoginPath(String location) {
    return location.toLowerCase().endsWith('/admin/login');
  }

  static Future<String?> redirectAsync(
    BuildContext context,
    GoRouterState state,
  ) async {
    final auth = context.read<AuthNotifier>();
    final location = state.uri.path;
    final slug = state.pathParameters['slug'] ?? 'snack_burger';

    final needsProfile =
        isAdminPath(location) && !isAdminLoginPath(location);

    await auth.ensureReadyForRouting(needsAdminProfile: needsProfile);

    debugPrint(
      '[AuthMiddleware] evaluate location=$location '
      'resolving=${auth.isAuthResolving} '
      'authenticated=${auth.isAuthenticated} '
      'hasProfile=${auth.hasAdminProfile} '
      'profileFailed=${auth.profileLoadFailed} '
      'restaurantId=${AdminProfileSession.restaurantId}',
    );

    // لا قرار توجيه أثناء التحميل — تبقى الشاشة الحالية مع Loading.
    if (auth.isAuthResolving) {
      debugPrint('[AuthMiddleware] → stay (loading profile/auth)');
      return null;
    }

    if (location == '/' || location.isEmpty) {
      final target = auth.isAdminAuthorized ? '/$slug/admin' : '/$slug';
      debugPrint('[AuthMiddleware] → root redirect $target');
      return target;
    }

    if (isAdminLoginPath(location)) {
      if (auth.isAdminAuthorized) {
        debugPrint('[AuthMiddleware] → authorized on login → dashboard');
        return '/$slug/admin';
      }
      debugPrint('[AuthMiddleware] → stay on login');
      return null;
    }

    if (isAdminPath(location)) {
      // الطرد لصفحة الدخول فقط إذا auth = null بعد انتهاء التحميل.
      if (!auth.isAuthenticated) {
        debugPrint('[AuthMiddleware] → no session after load → login');
        return '/$slug/admin/login';
      }

      // جلسة موجودة — ابقَ على المسار (حتى لو فشل profile: AdminWrapper يعرض خطأ).
      debugPrint('[AuthMiddleware] → stay on admin (session exists)');
      return null;
    }

    if (auth.isAdminAuthorized && !isAdminPath(location)) {
      debugPrint('[AuthMiddleware] → customer path but authorized → dashboard');
      return '/$slug/admin';
    }

    debugPrint('[AuthMiddleware] → stay on customer path');
    return null;
  }
}
