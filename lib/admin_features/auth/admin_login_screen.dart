import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_notifier.dart';
import '../shell/admin_panel_colors.dart';

/// شاشة تسجيل دخول المسؤولين — Supabase Auth + جلب ملف `profiles`.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.slug});

  final String slug;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mapAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        error.statusCode == '400') {
      return 'كلمة المرور أو البريد الإلكتروني غير صحيح';
    }
    return error.message;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthNotifier>();

    try {
      await auth.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final authorized = await auth.completeAdminSignIn();

      if (!mounted) return;

      if (!authorized) {
        _showErrorSnackBar(
          auth.profileLoadFailed
              ? 'تعذّر جلب بيانات الملف — تحقق من profiles و RLS في Supabase'
              : 'حسابك غير مربوط بمطعم',
        );
        return;
      }

      context.go('/${widget.slug}/admin');
    } on AuthException catch (e) {
      _showErrorSnackBar(_mapAuthError(e));
    } catch (_) {
      _showErrorSnackBar('تعذّر تسجيل الدخول، حاول مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _exitToCustomerMenu() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/${widget.slug}');
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AdminPanelColors.charcoal.withValues(alpha: 0.7),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: AdminPanelColors.charcoal.withValues(alpha: 0.55),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminPanelColors.charcoal.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminPanelColors.charcoal.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminPanelColors.gold.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AdminPanelColors.loginGradient),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AdminPanelColors.gold,
                    tooltip: 'العودة للمنيو',
                    onPressed: _isSubmitting ? null : _exitToCustomerMenu,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
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
                                    size: 44,
                                    color: AdminPanelColors.charcoal
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'لوحة إدارة المطعم',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AdminPanelColors.gold,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'إدارة الطلبات والمنتجات والتقارير',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AdminPanelColors.textMuted
                                    .withValues(alpha: 0.92),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      decoration: _fieldDecoration(
                                        label: 'البريد الإلكتروني',
                                        icon: Icons.email_outlined,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'أدخل البريد الإلكتروني';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: _fieldDecoration(
                                        label: 'كلمة المرور',
                                        icon: Icons.lock_outline_rounded,
                                        suffix: IconButton(
                                          onPressed: () {
                                            setState(() => _obscurePassword =
                                                !_obscurePassword);
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: AdminPanelColors.charcoal
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'أدخل كلمة المرور';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 22),
                                    FilledButton(
                                      onPressed:
                                          _isSubmitting ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AdminPanelColors.gold,
                                        foregroundColor:
                                            AdminPanelColors.charcoal,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    AdminPanelColors.charcoal,
                                              ),
                                            )
                                          : const Text(
                                              'تسجيل الدخول',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextButton.icon(
                              onPressed:
                                  _isSubmitting ? null : _exitToCustomerMenu,
                              icon: Icon(
                                Icons.storefront_outlined,
                                size: 20,
                                color: AdminPanelColors.textMuted
                                    .withValues(alpha: 0.9),
                              ),
                              label: Text(
                                'العودة للمنيو',
                                style: TextStyle(
                                  color: AdminPanelColors.textMuted
                                      .withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
