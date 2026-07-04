import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../services/product_repository.dart';
import '../../state/active_restaurant_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../widgets/admin_restaurant_logo_image.dart';

/// صفحة «حول النظام» — بصمة أنظمة المهاب داخل لوحة الإدارة.
class AboutSystemScreen extends StatefulWidget {
  const AboutSystemScreen({super.key, required this.slug});

  final String slug;

  static const String vendorNameAr = 'أنظمة المهاب';
  static const String vendorNameEn = 'Muhab Systems';

  @override
  State<AboutSystemScreen> createState() => _AboutSystemScreenState();
}

class _AboutSystemScreenState extends State<AboutSystemScreen> {
  late final Future<AboutSystemMetadata> _metadataFuture =
      AboutSystemMetadata.load();

  @override
  Widget build(BuildContext context) {
    final restaurant = context.watch<ActiveRestaurantNotifier>().restaurant;

    return AdminPageScaffold(
      slug: widget.slug,
      title: 'حول النظام',
      titleIcon: Icons.info_outline_rounded,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AdminPanelColors.loginGradient),
        child: SafeArea(
          top: false,
          child: FutureBuilder<AboutSystemMetadata>(
            future: _metadataFuture,
            builder: (context, snapshot) {
              final metadata = snapshot.data ?? AboutSystemMetadata.fallback();
              final restaurantName = restaurant?.name.trim() ?? '';
              final restaurantSlug = restaurant?.slug.trim() ?? '';
              final routeSlug = widget.slug.trim();
              final packageAppName = metadata.appName.trim();
              final displayName = restaurantName.isNotEmpty
                  ? restaurantName
                  : restaurantSlug.isNotEmpty
                      ? restaurantSlug
                      : routeSlug.isNotEmpty
                          ? routeSlug
                          : packageAppName.isNotEmpty
                              ? packageAppName
                              : 'Restaurant';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AboutMainCard(
                          metadata: metadata,
                          displayName: displayName,
                        ),
                        const SizedBox(height: 16),
                        _SystemInfoCard(
                          metadata: metadata,
                          displayName: displayName,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 16),
                          _DebugMaintenanceCard(slug: widget.slug),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// بيانات النظام — تُجلب من [PackageInfo] مع قيم احتياطية آمنة.
class AboutSystemMetadata {
  const AboutSystemMetadata({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.platformLabel,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final String platformLabel;

  static Future<AboutSystemMetadata> load() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return AboutSystemMetadata(
        appName: _nonEmpty(packageInfo.appName) ?? 'Restaurant',
        version: _nonEmpty(packageInfo.version) ?? '—',
        buildNumber: _nonEmpty(packageInfo.buildNumber) ?? '—',
        platformLabel: detectPlatformLabel(),
      );
    } catch (error, stack) {
      debugPrint('[AboutSystemScreen] metadata load failed: $error\n$stack');
      return AboutSystemMetadata.fallback();
    }
  }

  factory AboutSystemMetadata.fallback() {
    return AboutSystemMetadata(
      appName: 'Restaurant',
      version: '—',
      buildNumber: '—',
      platformLabel: detectPlatformLabel(),
    );
  }

  static String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String detectPlatformLabel() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isWindows) return 'Windows';
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isLinux) return 'Linux';
      if (Platform.isMacOS) return 'macOS';
      return Platform.operatingSystem;
    } catch (_) {
      return '—';
    }
  }
}

class _AboutMainCard extends StatelessWidget {
  const _AboutMainCard({
    required this.metadata,
    required this.displayName,
  });

  final AboutSystemMetadata metadata;
  final String displayName;

  static const double _logoCircleSize = 88;
  static const double _logoImageSize = 80;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: _logoCircleSize,
            height: _logoCircleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.45),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            alignment: Alignment.center,
            child: ClipOval(
              child: AdminRestaurantLogoImage(
                size: _logoImageSize,
                iconSize: 40,
                debugTag: 'AboutSystemScreen',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminPanelColors.charcoal,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نظام إدارة المنيو والطلبات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.charcoal.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AdminPanelColors.gold.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AdminPanelColors.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'الإصدار: ${metadata.version}',
              style: const TextStyle(
                color: AdminPanelColors.charcoal,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Divider(color: AdminPanelColors.charcoal.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          Text(
            'تطوير وتشغيل:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.charcoal.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            AboutSystemScreen.vendorNameAr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.charcoal,
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AboutSystemScreen.vendorNameEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.gold.withValues(alpha: 0.95),
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'شكراً لاستخدامكم نظامنا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AdminPanelColors.charcoal.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({
    required this.metadata,
    required this.displayName,
  });

  final AboutSystemMetadata metadata;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'معلومات النظام',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _SystemInfoRow(label: 'اسم التطبيق', value: displayName),
          _SystemInfoRow(label: 'إصدار التطبيق', value: metadata.version),
          _SystemInfoRow(label: 'رقم البناء', value: metadata.buildNumber),
          _SystemInfoRow(label: 'المنصة', value: metadata.platformLabel),
        ],
      ),
    );
  }
}

class _SystemInfoRow extends StatelessWidget {
  const _SystemInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AdminPanelColors.textLight,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// أدوات صيانة — debug فقط، لا تظهر في build الإنتاج.
class _DebugMaintenanceCard extends StatefulWidget {
  const _DebugMaintenanceCard({required this.slug});

  final String slug;

  @override
  State<_DebugMaintenanceCard> createState() => _DebugMaintenanceCardState();
}

class _DebugMaintenanceCardState extends State<_DebugMaintenanceCard> {
  static const bool _variantCleanupEnabled = false;

  final ProductRepository _productRepository = ProductRepository();
  bool _running = false;

  Future<void> _cleanupDuplicateVariants() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظيف أحجام المنتجات'),
        content: const Text(
          'سيتم حذف الصفوف المكررة في product_variants '
          '(نفس product_id + name + price) والإبقاء على صف واحد فقط.\n\n'
          'لا تُحذف أحجام مختلفة بالاسم أو السعر.\n\n'
          'لا يتم تحديث jsonb أو إدراج أحجام جديدة.\n\n'
          'يجب أن تكون مسجّل دخول الإدارة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تنظيف الآن'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _running = true);
    try {
      final report = await _productRepository.cleanupDuplicateProductVariants();
      if (!mounted) return;

      final message = report.hasChanges
          ? 'تم حذف ${report.totalDeleted} صف مكرر '
              'من ${report.productsAffected} منتج.'
          : 'لا توجد صفوف مكررة — الجدول نظيف.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error, stack) {
      debugPrint('[DebugMaintenance] cleanup failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('delete_blocked')
                ? 'تعذّر الحذف — سجّل دخول الإدارة ثم أعد المحاولة'
                : 'تعذّر تنظيف product_variants — راجع السجل',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صيانة (Debug)',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _variantCleanupEnabled
                ? 'تنظيف المكررات في جدول product_variants'
                : 'تنظيف المكررات معطّل مؤقتاً — يُعاد تفعيله بعد التحقق من الحذف فقط.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AdminPanelColors.textLight.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          if (_variantCleanupEnabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _running ? null : _cleanupDuplicateVariants,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined, size: 20),
              label: Text(_running ? 'جاري التنظيف...' : 'تنظيف أحجام مكررة'),
            ),
          ],
        ],
      ),
    );
  }
}
