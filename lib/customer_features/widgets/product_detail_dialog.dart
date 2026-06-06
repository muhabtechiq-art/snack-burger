import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

typedef ProductDetailAddHandler = void Function({
  required List<CartItemAddon> selectedAddons,
  CartItemVariant? selectedVariant,
});

/// مودال تفاصيل المنتج — أحجام (variants) وإضافات حسب بيانات قاعدة البيانات.
class ProductDetailDialog extends StatefulWidget {
  const ProductDetailDialog({
    super.key,
    required this.product,
    required this.palette,
    required this.onAdd,
  });

  final ProductModel product;
  final TenantPalette palette;
  final ProductDetailAddHandler onAdd;

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  final Map<int, int> _addonQuantities = <int, int>{};
  int? _selectedVariantIndex;

  ProductModel get product => widget.product;

  bool get _hasVariants => product.hasVariants;

  ProductVariant? get _selectedVariant {
    if (!_hasVariants || _selectedVariantIndex == null) return null;
    return product.variants[_selectedVariantIndex!];
  }

  @override
  void initState() {
    super.initState();
    if (_hasVariants) {
      _selectedVariantIndex = 0;
    }
  }

  List<CartItemAddon> _buildSelectedAddons() {
    return _addonQuantities.keys
        .where((i) => (_addonQuantities[i] ?? 0) > 0)
        .map(
          (i) => CartItemAddon(
            name: product.addons[i].name,
            price: product.addons[i].price,
            quantity: _addonQuantities[i] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  double _calculateTotal() {
    final basePrice = product.resolveBasePrice(selectedVariant: _selectedVariant);
    final addonsTotal = _buildSelectedAddons().fold<double>(
      0,
      (sum, addon) => sum + addon.lineTotal,
    );
    return basePrice + addonsTotal;
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddons = _buildSelectedAddons();
    final finalPrice = _calculateTotal();
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(product.name, textAlign: TextAlign.right),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((product.description ?? '').trim().isNotEmpty) ...[
              Text(product.description!, textAlign: TextAlign.right),
              const SizedBox(height: 10),
            ],
            if (_hasVariants)
              _SizeSelectorSection(
                variants: product.variants,
                palette: widget.palette,
                selectedIndex: _selectedVariantIndex ?? 0,
                onSelected: (index) {
                  setState(() => _selectedVariantIndex = index);
                },
              )
            else
              _FixedPriceRow(price: product.price),
            if (product.hasAddons) ...[
              const SizedBox(height: 12),
              const Text(
                'الإضافات',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...product.addons.asMap().entries.map((entry) {
                final index = entry.key;
                final addon = entry.value;
                final quantity = _addonQuantities[index] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: quantity > 0
                            ? () {
                                setState(() {
                                  final next = quantity - 1;
                                  if (next <= 0) {
                                    _addonQuantities.remove(index);
                                  } else {
                                    _addonQuantities[index] = next;
                                  }
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _addonQuantities[index] = quantity + 1;
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              addon.name,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '+${addon.price.toStringAsFixed(0)} د.ع',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.palette.primary.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 10),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 6),
            Text(
              'الإجمالي: ${finalPrice.toStringAsFixed(0)} د.ع',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: widget.palette.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        FilledButton(
          onPressed: () {
            final variant = _selectedVariant;
            widget.onAdd(
              selectedAddons: selectedAddons,
              selectedVariant: variant == null
                  ? null
                  : CartItemVariant.fromProductVariant(variant),
            );
            Navigator.of(context).pop();
          },
          child: const Text('إضافة إلى السلة'),
        ),
      ],
    );
  }
}

class _FixedPriceRow extends StatelessWidget {
  const _FixedPriceRow({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Text(
      'السعر: ${price.toStringAsFixed(0)} د.ع',
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _SizeSelectorSection extends StatelessWidget {
  const _SizeSelectorSection({
    required this.variants,
    required this.palette,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ProductVariant> variants;
  final TenantPalette palette;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'اختر الحجم',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: variants.asMap().entries.map((entry) {
            final index = entry.key;
            final variant = entry.value;
            final selected = index == selectedIndex;
            return ChoiceChip(
              label: Text(
                '${variant.name} — ${variant.price.toStringAsFixed(0)} د.ع',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              selected: selected,
              selectedColor: palette.primary.withValues(alpha: 0.18),
              checkmarkColor: palette.primary,
              side: BorderSide(
                color: selected
                    ? palette.primary
                    : palette.primary.withValues(alpha: 0.25),
              ),
              onSelected: (_) => onSelected(index),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}
