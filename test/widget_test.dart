import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snack_burger/features/landing/landing_page.dart';

void main() {
  testWidgets('Landing page shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LandingPage()),
    );

    expect(find.text('Al-Mahab Menu'), findsOneWidget);
  });
}
