import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('menu_logo.png loads from asset bundle', (tester) async {
    Object? caught;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Image.asset(
              'assets/images/menu_logo.png',
              width: 80,
              height: 80,
              errorBuilder: (context, error, stack) {
                caught = error;
                return const Text('failed');
              },
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    if (caught != null) {
      fail('asset failed: $caught');
    }
    expect(find.text('failed'), findsNothing);
  });
}
