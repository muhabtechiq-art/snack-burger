import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/core/theme/tenant_palette.dart';
import 'package:snack_burger/customer_features/theme/customer_menu_theme.dart';
import 'package:snack_burger/customer_features/widgets/menu_product_card.dart';
import 'package:snack_burger/models/product_model.dart';

ProductModel _sampleProduct({String? description}) {
  return ProductModel(
    id: '1',
    restaurantId: 'snack_burger',
    name: 'سندويش شاورما لحم بالجبن الحار مع صوص خاص',
    description: description ??
        'وصف طويل جداً قد يسبب overflow إذا لم يُقص',
    price: 12000,
    category: 'شاورما',
    createdAt: DateTime.utc(2024, 1, 1),
  );
}

Future<void> _pumpGridCard(
  WidgetTester tester, {
  required Size surfaceSize,
  required double aspectRatio,
}) async {
  final palette = const TenantPalette(
    primary: Color(0xFF8B0000),
    accent: Color(0xFFE1AD01),
  );

  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: CustomerMenuTheme.buildTheme(palette),
      home: Scaffold(
        body: GridView(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          children: [
            MenuProductCard(
              product: _sampleProduct(),
              palette: palette,
              onQuickAdd: () {},
              onOpenDetails: () {},
            ),
            MenuProductCard(
              product: _sampleProduct(description: null),
              palette: palette,
              onQuickAdd: () {},
              onOpenDetails: () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('grid product card — no overflow on narrow phone', (tester) async {
    await _pumpGridCard(
      tester,
      surfaceSize: const Size(360, 640),
      aspectRatio: 0.68,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid product card — no overflow on small Windows window',
      (tester) async {
    await _pumpGridCard(
      tester,
      surfaceSize: const Size(480, 520),
      aspectRatio: 0.76,
    );
    expect(tester.takeException(), isNull);
  });
}
