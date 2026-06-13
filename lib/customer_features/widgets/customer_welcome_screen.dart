import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import '../theme/customer_menu_theme.dart';

/// شاشة البداية — مطابقة للتصميم المرجعي.
class CustomerWelcomeScreen extends StatelessWidget {
  const CustomerWelcomeScreen({
    super.key,
    required this.restaurant,
    required this.onStartOrder,
  });

  final RestaurantModel restaurant;
  final VoidCallback onStartOrder;

  static const double _horizontalPadding = 24;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoSize = (width * 0.52).clamp(250.0, 320.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CustomerMenuTheme.mustard,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _WelcomeBackdrop(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  16,
                  _horizontalPadding,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    _LogoSection(logoSize: logoSize),
                    const SizedBox(height: 20),
                    const Text(
                      'Snack Burger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: CustomerMenuTheme.ink,
                        height: 1.05,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _ArabicBrandTitle(),
                    const Spacer(flex: 2),
                    const Center(child: _WelcomeGreeting()),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStartOrder,
                        icon: const Icon(
                          Icons.lunch_dining_rounded,
                          size: 22,
                          color: CustomerMenuTheme.mustard,
                        ),
                        label: const Text(
                          'أطلب الآن',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: CustomerMenuTheme.mutedRedDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              CustomerMenuTheme.radiusLg,
                            ),
                          ),
                          elevation: 6,
                          shadowColor: CustomerMenuTheme.mutedRedDark
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(child: _FooterTagline()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: CustomerMenuTheme.mustard),
        Positioned(
          top: size.height * 0.04,
          left: 0,
          right: 0,
          child: Center(
            child: CustomPaint(
              size: const Size(320, 320),
              painter: _LogoRaysPainter(),
            ),
          ),
        ),
        Positioned(
          top: 64,
          left: 14,
          child: Icon(
            Icons.lunch_dining_rounded,
            size: 68,
            color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.04),
          ),
        ),
        Positioned(
          top: 78,
          right: 16,
          child: Transform.rotate(
            angle: 0.2,
            child: Icon(
              Icons.fastfood_rounded,
              size: 62,
              color: CustomerMenuTheme.ink.withValues(alpha: 0.035),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.42,
          left: 10,
          child: Transform.rotate(
            angle: -0.15,
            child: Icon(
              Icons.fastfood_rounded,
              size: 56,
              color: CustomerMenuTheme.mutedRedDark.withValues(alpha: 0.035),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.44,
          right: 12,
          child: Icon(
            Icons.local_drink_rounded,
            size: 58,
            color: CustomerMenuTheme.ink.withValues(alpha: 0.035),
          ),
        ),
        Positioned(
          top: size.height * 0.36,
          right: 18,
          child: Transform.rotate(
            angle: 0.12,
            child: Icon(
              Icons.lunch_dining_rounded,
              size: 52,
              color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      size.width * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.22)),
    );

    const rayCount = 14;
    for (var i = 0; i < rayCount; i++) {
      final angle = (math.pi * 2 / rayCount) * i;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      final end = Offset(
        center.dx + math.cos(angle) * size.width * 0.48,
        center.dy + math.sin(angle) * size.height * 0.48,
      );
      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({required this.logoSize});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logoSize + 6,
      height: logoSize + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Image.asset(
          'assets/images/menu_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => ColoredBox(
            color: CustomerMenuTheme.mustardSoft,
            child: Center(
              child: Icon(
                Icons.restaurant_rounded,
                size: logoSize * 0.42,
                color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArabicBrandTitle extends StatelessWidget {
  const _ArabicBrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        const Text(
          'سناك بركر',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: CustomerMenuTheme.mutedRedDark,
            height: 1.15,
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          Icons.circle,
          size: 6,
          color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

class _WelcomeGreeting extends StatefulWidget {
  const _WelcomeGreeting();

  @override
  State<_WelcomeGreeting> createState() => _WelcomeGreetingState();
}

class _WelcomeGreetingState extends State<_WelcomeGreeting>
    with TickerProviderStateMixin {
  static const double _boxWidth = 300;

  late final AnimationController _boxController;
  late final AnimationController _handController;
  late final Animation<double> _boxScale;
  late final Animation<double> _handRotation;

  @override
  void initState() {
    super.initState();
    _boxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _boxScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.04), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 0.98), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _boxController, curve: Curves.easeOut));

    _handRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.14), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.14, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _handController, curve: Curves.easeInOut));

    _boxController.forward();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _handController.forward();
    });
  }

  @override
  void dispose() {
    _boxController.dispose();
    _handController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final stackWidth = screenWidth - CustomerWelcomeScreen._horizontalPadding * 2;
    final handLeft = (stackWidth - _boxWidth) / 2 - 54;

    return SizedBox(
      width: stackWidth,
      height: 156,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _boxController,
            builder: (context, child) {
              return Transform.scale(
                scale: _boxScale.value,
                child: child,
              );
            },
            child: SizedBox(
              width: _boxWidth,
              child: _WelcomeBox(),
            ),
          ),
          Positioned(
            left: handLeft.clamp(0.0, stackWidth - 40),
            top: 38,
            child: AnimatedBuilder(
              animation: _handController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _handRotation.value,
                  alignment: Alignment.bottomCenter,
                  child: child,
                );
              },
              child: const Text(
                '👋',
                style: TextStyle(fontSize: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أهلاً بك!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              color: CustomerMenuTheme.mutedRed,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'أطيب بركر يوصلك بسرعة!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CustomerMenuTheme.inkMuted,
              height: 1.35,
            ),
          ),
          SizedBox(height: 12),
          _RedAccentLine(),
        ],
      ),
    );
  }
}

class _RedAccentLine extends StatelessWidget {
  const _RedAccentLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 3,
      decoration: BoxDecoration(
        color: CustomerMenuTheme.mutedRed,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _FooterTagline extends StatelessWidget {
  const _FooterTagline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FooterDecorLine(),
            const SizedBox(width: 10),
            Icon(
              Icons.favorite_rounded,
              size: 13,
              color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            const _FooterDecorLine(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'جودة • سرعة • طعم لا يقاوم',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CustomerMenuTheme.ink.withValues(alpha: 0.55),
            letterSpacing: 0.2,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _FooterDecorLine extends StatelessWidget {
  const _FooterDecorLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 1.5,
      decoration: BoxDecoration(
        color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
