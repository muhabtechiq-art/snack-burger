import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../admin_features/auth/admin_login_screen.dart';
import '../../admin_features/dashboard/admin_home_screen.dart';
import '../../admin_features/dashboard/orders_dashboard_screen.dart';
import '../../admin_features/banners/banners_admin_screen.dart';
import '../../admin_features/products/product_form_controller.dart';
import '../../admin_features/products/product_form_page.dart';
import '../../admin_features/products/products_admin_screen.dart';
import '../../admin_features/reports/end_of_day_report_screen.dart';
import '../../admin_features/settings/about_system_screen.dart';
import '../../admin_features/settings/printer_settings_page.dart';
import '../../core/auth/admin_wrapper.dart';
import '../../core/auth/auth_middleware.dart';
import '../../core/auth/auth_notifier.dart';
import '../../customer_features/menu/customer_menu_screen.dart';
import '../../customer_features/my_orders/my_orders_screen.dart';
import '../../customer_features/order_status/order_status_screen.dart';

/// مسارات التطبيق — فصل كامل بين الزبون والإدارة.
GoRouter createAppRouter(AuthNotifier authNotifier) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) => AuthMiddleware.redirectAsync(context, state),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'landing',
        redirect: (_, _) => '/snack_burger',
      ),
      GoRoute(
        path: '/:slug/products/manage',
        redirect: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return '/$slug/admin/products/manage';
        },
      ),
      GoRoute(
        path: '/:slug/products/new',
        redirect: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return '/$slug/admin/products/new';
        },
      ),
      GoRoute(
        path: '/:slug/products/:productId/edit',
        redirect: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final productId = state.pathParameters['productId'] ?? '';
          return '/$slug/admin/products/$productId/edit';
        },
      ),
      GoRoute(
        path: '/:slug/settings/printer',
        redirect: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return '/$slug/admin/settings/printer';
        },
      ),
      GoRoute(
        path: '/:slug/cashier',
        name: 'cashier-legacy',
        redirect: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final auth = context.read<AuthNotifier>();
          return auth.isAdminAuthorized ? '/$slug/admin' : '/$slug';
        },
      ),
      GoRoute(
        path: '/:slug/admin/login',
        name: 'admin-login',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminLoginScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin',
        name: 'admin-home',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: AdminHomeScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/orders',
        name: 'admin-orders-dashboard',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: OrdersDashboardScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/reports/closing',
        name: 'end-of-day-report',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: EndOfDayReportScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/settings/printer',
        name: 'printer-settings',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: PrinterSettingsPage(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/about',
        name: 'about-system',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: AboutSystemScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/banners/manage',
        name: 'banners-manage',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: BannersAdminScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/products/manage',
        name: 'products-manage',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: ProductsAdminScreen(slug: slug),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/products/new',
        name: 'product-new',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: ChangeNotifierProvider(
                create: (_) => ProductFormController(),
                child: ProductFormPage(slug: slug),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/admin/products/:productId/edit',
        name: 'product-edit',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final productId = state.pathParameters['productId'] ?? '';
          return NoTransitionPage<void>(
            child: AdminWrapper(
              slug: slug,
              child: ChangeNotifierProvider(
                create: (_) => ProductFormController(productId: productId),
                child: ProductFormPage(slug: slug),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/:slug/my-order',
        name: 'my-orders',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: MyOrdersScreen(slug: slug),
          );
        },
      ),
      GoRoute(
        path: '/:slug/order/:orderId/status',
        name: 'order-status',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          final orderId = state.pathParameters['orderId'] ?? '';
          return NoTransitionPage<void>(
            child: OrderStatusScreen(slug: slug, orderId: orderId),
          );
        },
      ),
      GoRoute(
        path: '/:slug',
        name: 'customer-menu',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return NoTransitionPage<void>(
            child: CustomerMenuScreen(slug: slug),
          );
        },
      ),
    ],
  );
}
