import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

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

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AboutMainCard(metadata: metadata),
                        const SizedBox(height: 16),
                        _SystemInfoCard(metadata: metadata),
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
        appName: _nonEmpty(packageInfo.appName) ?? 'Snack Burger',
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
      appName: 'Snack Burger',
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
  const _AboutMainCard({required this.metadata});

  final AboutSystemMetadata metadata;

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
            width: 88,
            height: 88,
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
            child: ClipOval(
              child: Image.asset(
                'assets/images/menu_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.restaurant_rounded,
                  size: 40,
                  color: AdminPanelColors.charcoal.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            metadata.appName,
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
  const _SystemInfoCard({required this.metadata});

  final AboutSystemMetadata metadata;

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
          _SystemInfoRow(label: 'اسم التطبيق', value: metadata.appName),
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
