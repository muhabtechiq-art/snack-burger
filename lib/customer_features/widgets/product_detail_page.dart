import 'package:flutter/material.dart';

import '../../core/theme/tenant_palette.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../theme/customer_menu_theme.dart';
import 'menu_product_image.dart';
import 'product_detail_dialog.dart';

/// صفحة تفاصيل المنتج — صورة كبيرة + بطاقة بيضاء + زر إضافة ثابت.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.palette,
    required this.onAdd,
  });

  final ProductModel product;
  final TenantPalette palette;
  final ProductDetailAddHandler onAdd;

  static Future<void> open(
    BuildContext context, {
    required ProductModel product,
    required TenantPalette palette,
    required ProductDetailAddHandler onAdd,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ProductDetailPage(
          product: product,
          palette: palette,
          onAdd: onAdd,
        ),
      ),
    );
  }

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final Map<int, int> _addonQuantities = <int, int>{};
  int? _selectedVariantIndex;
  int _quantity = 1;
  bool _favorite = false;

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

  double _unitTotal() {
    final basePrice =
        product.resolveBasePrice(selectedVariant: _selectedVariant);
    final addonsTotal = _buildSelectedAddons().fold<double>(
      0,
      (sum, addon) => sum + addon.lineTotal,
    );
    return basePrice + addonsTotal;
  }

  double get _lineTotal => _unitTotal() * _quantity;

  void _submitAdd() {
    final variant = _selectedVariant;
    final selectedAddons = _buildSelectedAddons();
    for (var i = 0; i < _quantity; i++) {
      widget.onAdd(
        selectedAddons: selectedAddons,
        selectedVariant: variant == null
            ? null
            : CartItemVariant.fromProductVariant(variant),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl?.trim();
    final topInset = MediaQuery.paddingOf(context).top;
    final imageHeight = MediaQuery.sizeOf(context).height * 0.38;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CustomerMenuTheme.surfaceWhite,
        bottomNavigationBar: _AddToCartBar(
          total: _lineTotal,
          onAdd: _submitAdd,
        ),
        body: Column(
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl == null || imageUrl.isEmpty)
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            CustomerMenuTheme.mustardSoft,
                            CustomerMenuTheme.mustardDeep,
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.fastfood_rounded,
                        size: 72,
                        color: CustomerMenuTheme.mutedRed
                            .withValues(alpha: 0.35),
                      ),
                    )
                  else
                    MenuProductImage(
                      imageUrl: imageUrl,
                      palette: widget.palette,
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      cacheHeight: 720,
                    ),
                  Positioned(
                    top: topInset + 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        _CircleIconButton(
                          icon: _favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: _favorite
                              ? CustomerMenuTheme.mutedRed
                              : CustomerMenuTheme.ink,
                          onPressed: () =>
                              setState(() => _favorite = !_favorite),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -CustomerMenuTheme.radiusXl),
                child: _ProductDetailSheet(
                  product: product,
                  palette: widget.palette,
                  hasVariants: _hasVariants,
                  selectedVariantIndex: _selectedVariantIndex ?? 0,
                  onVariantSelected: (index) {
                    setState(() => _selectedVariantIndex = index);
                  },
                  addonQuantities: _addonQuantities,
                  onAddonChanged: (index, quantity) {
                    setState(() {
                      if (quantity <= 0) {
                        _addonQuantities.remove(index);
                      } else {
                        _addonQuantities[index] = quantity;
                      }
                    });
                  },
                  quantity: _quantity,
                  onQuantityChanged: (value) {
                    setState(() => _quantity = value.clamp(1, 99));
                  },
                  unitTotal: _unitTotal(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = CustomerMenuTheme.ink,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatelessWidget {
  const _ProductDetailSheet({
    required this.product,
    required this.palette,
    required this.hasVariants,
    required this.selectedVariantIndex,
    required this.onVariantSelected,
    required this.addonQuantities,
    required this.onAddonChanged,
    required this.quantity,
    required this.onQuantityChanged,
    required this.unitTotal,
  });

  final ProductModel product;
  final TenantPalette palette;
  final bool hasVariants;
  final int selectedVariantIndex;
  final ValueChanged<int> onVariantSelected;
  final Map<int, int> addonQuantities;
  final void Function(int index, int quantity) onAddonChanged;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final double unitTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CustomerMenuTheme.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: CustomerMenuTheme.ink,
              ),
            ),
            if ((product.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                product.description!.trim(),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: CustomerMenuTheme.inkMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${unitTotal.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: CustomerMenuTheme.mutedRed,
                  ),
                ),
                _QuantityStepper(
                  value: quantity,
                  onChanged: onQuantityChanged,
                ),
              ],
            ),
            if (hasVariants) ...[
              const SizedBox(height: 18),
              const Text(
                'اختر الحجم',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CustomerMenuTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: product.variants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variant = entry.value;
                  final selected = index == selectedVariantIndex;
                  return ChoiceChip(
                    label: Text(
                      '${variant.name} — ${variant.price.toStringAsFixed(0)} د.ع',
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor:
                        CustomerMenuTheme.mutedRed.withValues(alpha: 0.14),
                    checkmarkColor: CustomerMenuTheme.mutedRed,
                    side: BorderSide(
                      color: selected
                          ? CustomerMenuTheme.mutedRed
                          : CustomerMenuTheme.mutedRed
                              .withValues(alpha: 0.2),
                    ),
                    onSelected: (_) => onVariantSelected(index),
                  );
                }).toList(growable: false),
              ),
            ],
            if (product.hasAddons) ...[
              const SizedBox(height: 18),
              const Text(
                'الإضافات',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CustomerMenuTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              ...product.addons.asMap().entries.map((entry) {
                final index = entry.key;
                final addon = entry.value;
                final qty = addonQuantities[index] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _QuantityStepper(
                        value: qty,
                        compact: true,
                        onChanged: (value) => onAddonChanged(index, value),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              addon.name,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CustomerMenuTheme.ink,
                              ),
                            ),
                            Text(
                              '+${addon.price.toStringAsFixed(0)} د.ع',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: CustomerMenuTheme.inkMuted
                                    .withValues(alpha: 0.9),
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
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 38.0;

    return Container(
      decoration: BoxDecoration(
        color: CustomerMenuTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CustomerMenuTheme.mutedRed.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            size: size,
            icon: Icons.remove_rounded,
            enabled: value > (compact ? 0 : 1),
            onPressed: () => onChanged(value - 1),
          ),
          SizedBox(
            width: compact ? 28 : 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: CustomerMenuTheme.ink,
              ),
            ),
          ),
          _StepperButton(
            size: size,
            icon: Icons.add_rounded,
            enabled: value < 99,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.size,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? CustomerMenuTheme.mutedRed
              : CustomerMenuTheme.inkMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.total,
    required this.onAdd,
  });

  final double total;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Text(
                '${total.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: CustomerMenuTheme.mutedRed,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: CustomerMenuTheme.mutedRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(CustomerMenuTheme.radiusMd),
                    ),
                  ),
                  child: const Text('Add to Cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
