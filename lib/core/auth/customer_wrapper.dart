import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_notifier.dart';

/// يغلّف شاشات الزبون — لا يوجّه داخل build (الـ Router يتولى ذلك).
class CustomerWrapper extends StatelessWidget {
  const CustomerWrapper({
    super.key,
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (auth.isAuthResolving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAdminAuthorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}
