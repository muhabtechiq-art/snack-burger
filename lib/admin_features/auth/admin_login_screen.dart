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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AdminPanelColors.charcoal,
        appBar: AppBar(
          backgroundColor: AdminPanelColors.charcoal,
          foregroundColor: AdminPanelColors.gold,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'دخول الإدارة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'العودة للمنيو',
            onPressed: _isSubmitting ? null : _exitToCustomerMenu,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: AdminPanelColors.gold.withValues(alpha: 0.2),
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'لوحة تحكم Snack Burger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AdminPanelColors.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سجّل دخولك كمسؤول للوصول إلى لوحة التحكم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: AdminPanelColors.gold.withValues(alpha: 0.8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
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
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: AdminPanelColors.gold.withValues(alpha: 0.8),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AdminPanelColors.textMuted,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'أدخل كلمة المرور';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminPanelColors.gold,
                        foregroundColor: AdminPanelColors.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AdminPanelColors.charcoal,
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
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _exitToCustomerMenu,
                      icon: Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
                      ),
                      label: Text(
                        'العودة للمنيو',
                        style: TextStyle(
                          color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
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
      ),
    );
  }
}
