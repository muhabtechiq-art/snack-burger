import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/tenant_palette.dart';
import '../../models/app_settings_model.dart';
import '../theme/customer_menu_theme.dart';

/// شاشة صيانة كاملة للزبون — اعتذار + أرقام اتصال مباشرة.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.settings,
    this.isEmergencyFallback = false,
  });

  final AppSettingsModel settings;
  final bool isEmergencyFallback;

  @override
  Widget build(BuildContext context) {
    final palette = TenantPalette.fromRestaurant(null);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CustomerMenuTheme.mustard,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _MaintenanceBackdrop(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LogoBadge(),
                        const SizedBox(height: 24),
                        Text(
                          settings.maintenanceTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CustomerMenuTheme.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(
                              CustomerMenuTheme.radiusLg,
                            ),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            settings.maintenanceMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CustomerMenuTheme.inkMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.65,
                            ),
                          ),
                        ),
                        if (isEmergencyFallback) ...[
                          const SizedBox(height: 12),
                          Text(
                            'نواجه مشكلة تقنية مؤقتة — يمكنكم الطلب عبر الهاتف.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CustomerMenuTheme.mutedRed
                                  .withValues(alpha: 0.85),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (settings.phone1.trim().isNotEmpty)
                          _PhoneCallButton(
                            label: 'اتصال — ${settings.phone1}',
                            phone: settings.phone1,
                          ),
                        if (settings.phone2.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _PhoneCallButton(
                            label: 'اتصال — ${settings.phone2}',
                            phone: settings.phone2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: ClipOval(
          child: Image.asset(
            AppAssets.menuLogo,
            width: 108,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.restaurant_rounded,
              size: 48,
              color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneCallButton extends StatelessWidget {
  const _PhoneCallButton({
    required this.label,
    required this.phone,
  });

  final String label;
  final String phone;

  Future<void> _call() async {
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri)) {
      debugPrint('[MaintenanceScreen] launch tel failed: $normalized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _call,
      icon: const Icon(Icons.phone_in_talk_rounded),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: CustomerMenuTheme.mutedRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CustomerMenuTheme.radiusMd),
        ),
      ),
    );
  }
}

class _MaintenanceBackdrop extends StatelessWidget {
  const _MaintenanceBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mustard = Paint()..color = CustomerMenuTheme.mustardSoft;
    canvas.drawRect(Offset.zero & size, mustard);

    final circle = Paint()
      ..color = CustomerMenuTheme.mutedRed.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      size.width * 0.28,
      circle,
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.78),
      size.width * 0.22,
      circle,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
