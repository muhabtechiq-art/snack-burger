import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_star_prnt_example/main.dart';

void main() {
  testWidgets('Plugin example app renders main UI', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();

    expect(find.text('Plugin example app'), findsOneWidget);
    expect(find.text('Print from text'), findsOneWidget);
    expect(find.text('Print from url'), findsOneWidget);
    expect(find.text('Print from genrated image'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.data?.startsWith('This is a text to print') == true,
      ),
      findsOneWidget,
    );
  });
}
