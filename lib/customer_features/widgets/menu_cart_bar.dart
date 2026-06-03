import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/location_feature_flags.dart';
import '../../../core/utils/iraqi_phone_validator.dart';
import '../../../core/theme/tenant_palette.dart';
import '../../../models/saved_delivery_location_model.dart';
import '../../../services/supabase_customer_location_service.dart';
import '../delivery/delivery_location_map_dialog.dart';
import '../delivery/saved_delivery_location_dialog.dart';
import '../../../models/order_model.dart';
import '../../../models/restaurant_model.dart';
import '../data/customer_order_repository.dart';
import '../services/customer_last_order_notifier.dart';
import '../../../state/cart_notifier.dart';
import '../../../state/delivery_location_notifier.dart';

/// شريط السلة السفلي + ورقة ملخص الطلب.
class MenuCartBar extends StatelessWidget {
  const MenuCartBar({
    super.key,
    required this.palette,
    required this.restaurant,
  });

  final TenantPalette palette;
  final RestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartNotifier>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();

        return Material(
          elevation: 12,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} عنصر',
                          style: TextStyle(
                            color: palette.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${cart.totalPrice.toStringAsFixed(0)} د.ع',
                          style: TextStyle(
                            color: palette.primary.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _openCartSheet(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('عرض السلة'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCartSheet(BuildContext context) {
    final cart = context.read<CartNotifier>();
    final location = context.read<DeliveryLocationNotifier>();
    location.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<CartNotifier>.value(value: cart),
            ChangeNotifierProvider<DeliveryLocationNotifier>.value(
              value: location,
            ),
          ],
          child: _CartOrderSheet(
            palette: palette,
            restaurant: restaurant,
          ),
        );
      },
    );
  }
}

class _CartOrderSheet extends StatefulWidget {
  const _CartOrderSheet({
    required this.palette,
    required this.restaurant,
  });

  final TenantPalette palette;
  final RestaurantModel restaurant;

  @override
  State<_CartOrderSheet> createState() => _CartOrderSheetState();
}

class _CartOrderSheetState extends State<_CartOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final CustomerOrderRepository _orderRepository = CustomerOrderRepository();

  bool _isSubmitting = false;
  bool _loadingSavedLocation = false;
  bool _locationChosen = false;
  SavedDeliveryLocation? _savedLocation;
  String? _lastLookupPhone;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPhoneFieldChanged();
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onPhoneFieldChanged() {
    if (!LocationFeatureFlags.enabled) return;

    final validation = IraqiPhoneValidator.validate(_phoneController.text);
    if (validation != null) {
      if (_savedLocation != null || _locationChosen || _loadingSavedLocation) {
        setState(() {
          _savedLocation = null;
          _locationChosen = false;
          _lastLookupPhone = null;
        });
        context.read<DeliveryLocationNotifier>().clear();
      }
      return;
    }

    final phone = IraqiPhoneValidator.normalize(_phoneController.text);
    if (phone == _lastLookupPhone) return;
    _lastLookupPhone = phone;
    unawaited(_lookupCustomerForCheckout(phone));
  }

  /// جلب بيانات الزبون عند إتمام الطلب (حسب رقم الهاتف).
  Future<void> _lookupCustomerForCheckout(String phone) async {
    setState(() {
      _loadingSavedLocation = true;
      _savedLocation = null;
      _locationChosen = false;
    });
    context.read<DeliveryLocationNotifier>().clear();

    final profile = await SupabaseCustomerLocationService.fetchCustomerByPhone(
      phoneNumber: phone,
    );

    if (!mounted) return;
    setState(() {
      _loadingSavedLocation = false;
      _savedLocation = profile?.savedLocation;
    });

    if (profile != null && profile.shouldConfirmSavedAddress) {
      await _showSavedLocationModal(profile.savedLocation!);
    }
  }

  Future<void> _showSavedLocationModal(SavedDeliveryLocation saved) async {
    final choice = await SavedDeliveryLocationDialog.show(
      context: context,
      saved: saved,
      palette: widget.palette,
    );

    if (!mounted) return;

    if (choice == true) {
      _useSavedLocation();
    } else if (choice == false) {
      await _changeLocation();
    }
  }

  void _useSavedLocation() {
    final saved = _savedLocation;
    if (saved == null) return;

    context.read<DeliveryLocationNotifier>().applySavedLocation(
          latitude: saved.latitude,
          longitude: saved.longitude,
        );

    final address = saved.address?.trim();
    if (address != null && address.isNotEmpty) {
      _addressController.text = address;
    }

    setState(() => _locationChosen = true);
  }

  Future<void> _changeLocation() async {
    final location = context.read<DeliveryLocationNotifier>();
    location.clear();
    setState(() => _locationChosen = false);

    final confirmed = await DeliveryLocationMapDialog.show(
      context: context,
      notifier: location,
      palette: widget.palette,
      startGpsOnOpen: true,
    );

    if (!mounted) return;
    if (confirmed == true && location.hasAcceptableLocation) {
      setState(() => _locationChosen = true);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: widget.palette.primary),
      filled: true,
      fillColor: widget.palette.surfaceTint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: widget.palette.primary.withValues(alpha: 0.15),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: widget.palette.primary.withValues(alpha: 0.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.palette.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _submitOrder({
    required CartNotifier cart,
    required DeliveryLocationNotifier location,
  }) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    if (LocationFeatureFlags.enabled) {
      if (!location.hasLocation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(LocationFeatureFlags.locationRequiredMessage),
          ),
        );
        return;
      }
      if (!location.hasAcceptableLocation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(LocationFeatureFlags.weakSignalMessage),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final orderId = await _orderRepository.submitOrder(
        restaurantId: widget.restaurant.id,
        slug: widget.restaurant.slug,
        customerName: _nameController.text.trim(),
        customerPhone: IraqiPhoneValidator.normalize(_phoneController.text),
        address: _addressController.text.trim(),
        latitude: LocationFeatureFlags.enabled ? location.latitude : null,
        longitude: LocationFeatureFlags.enabled ? location.longitude : null,
        items: cart.items,
        totalPrice: cart.totalPrice,
      );

      if (!mounted) return;

      await context.read<CustomerLastOrderNotifier>().recordOrder(orderId);

      if (!mounted) return;

      context.read<CartNotifier>().clearCart();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: widget.palette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'طلباتي',
            textColor: widget.palette.onPrimary,
            onPressed: () => context.pushNamed(
              'my-orders',
              pathParameters: {'slug': widget.restaurant.slug},
            ),
          ),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: widget.palette.onPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تم إرسال طلبك بنجاح، يرجى انتظار قبول المطعم',
                  style: TextStyle(
                    color: widget.palette.onPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            child: Consumer2<CartNotifier, DeliveryLocationNotifier>(
              builder: (context, cart, location, _) {
                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: widget.palette.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Text(
                                'سلة المشتريات',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: widget.palette.primary,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                title: 'المنتجات المضافة',
                                palette: widget.palette,
                                child: Column(
                                  children: [
                                    for (final entry in cart.items.asMap().entries) ...[
                                      _CartLineItem(
                                        item: entry.value,
                                        palette: widget.palette,
                                        onIncrement: () => cart.increment(entry.value.lineId),
                                        onDecrement: () => cart.decrement(entry.value.lineId),
                                        onIncrementAddon: (addonIndex) =>
                                            cart.incrementAddon(
                                              entry.value.lineId,
                                              addonIndex,
                                            ),
                                        onDecrementAddon: (addonIndex) =>
                                            cart.decrementAddon(
                                              entry.value.lineId,
                                              addonIndex,
                                            ),
                                      ),
                                      if (entry.key != cart.items.length - 1)
                                        Divider(
                                          height: 18,
                                          color: widget.palette.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                title: 'بيانات التوصيل',
                                palette: widget.palette,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _nameController,
                                      textAlign: TextAlign.right,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        label: 'اسم الزبون',
                                        icon: Icons.person_rounded,
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _phoneController,
                                      textAlign: TextAlign.right,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      maxLength: IraqiPhoneValidator.requiredLength,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: _inputDecoration(
                                        label: 'رقم الهاتف',
                                        icon: Icons.phone_rounded,
                                      ).copyWith(
                                        counterText: '',
                                        hintText: '07XXXXXXXXX',
                                      ),
                                      validator: IraqiPhoneValidator.validate,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _addressController,
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      textInputAction: TextInputAction.done,
                                      decoration: _inputDecoration(
                                        label: 'العنوان بالتفصيل',
                                        icon: Icons.home_rounded,
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                                    ),
                                    if (LocationFeatureFlags.enabled) ...[
                                      const SizedBox(height: 12),
                                      _DeliveryLocationSection(
                                        palette: widget.palette,
                                        loading: _loadingSavedLocation,
                                        locationChosen: _locationChosen,
                                        hasSavedProfile: _savedLocation != null,
                                        phoneValid: IraqiPhoneValidator.validate(
                                              _phoneController.text,
                                            ) ==
                                            null,
                                        location: location,
                                        onChangeLocation: _changeLocation,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: widget.palette.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.palette.primary.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${cart.totalPrice.toStringAsFixed(0)} د.ع',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: widget.palette.primary,
                                    fontSize: 20,
                                  ),
                                ),
                                const Text(
                                  'الإجمالي',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submitOrder(
                                          cart: cart,
                                          location: location,
                                        ),
                                icon: _isSubmitting
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: widget.palette.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.receipt_long_rounded),
                                label: Text(
                                  _isSubmitting
                                      ? 'جاري إرسال الطلب...'
                                      : 'إتمام وإرسال الطلب',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: widget.palette.primary,
                                  foregroundColor: widget.palette.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.palette,
    required this.child,
  });

  final String title;
  final TenantPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CartLineItem extends StatelessWidget {
  const _CartLineItem({
    required this.item,
    required this.palette,
    required this.onIncrement,
    required this.onDecrement,
    required this.onIncrementAddon,
    required this.onDecrementAddon,
  });

  final CartItem item;
  final TenantPalette palette;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onIncrementAddon;
  final ValueChanged<int> onDecrementAddon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Text(
              '${item.lineTotal.toStringAsFixed(0)} د.ع',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDecrement,
                  icon: Icon(Icons.remove_circle_outline, color: palette.primary),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onIncrement,
                  icon: Icon(Icons.add_circle_outline, color: palette.primary),
                ),
              ],
            ),
          ],
        ),
        if (item.selectedAddons.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Text(
                  'الإضافات',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.primary.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 2),
                ...item.selectedAddons.asMap().entries.map(
                  (entry) => Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onDecrementAddon(entry.key),
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: palette.primary.withValues(alpha: 0.9),
                          size: 18,
                        ),
                      ),
                      Text(
                        '${entry.value.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onIncrementAddon(entry.key),
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: palette.primary.withValues(alpha: 0.9),
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.value.name} (+${entry.value.price.toStringAsFixed(0)} د.ع)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.primary.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// حالة الموقع — الاعتماد على المحفوظ عبر Modal؛ GPS عند «تغيير الموقع» فقط.
class _DeliveryLocationSection extends StatelessWidget {
  const _DeliveryLocationSection({
    required this.palette,
    required this.loading,
    required this.locationChosen,
    required this.hasSavedProfile,
    required this.phoneValid,
    required this.location,
    required this.onChangeLocation,
  });

  final TenantPalette palette;
  final bool loading;
  final bool locationChosen;
  final bool hasSavedProfile;
  final bool phoneValid;
  final DeliveryLocationNotifier location;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    if (!phoneValid) {
      return Text(
        'أدخل رقم هاتفك لعرض عنوان التوصيل المحفوظ',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: palette.primary.withValues(alpha: 0.65),
          fontSize: 12,
        ),
      );
    }

    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'جاري البحث عن عنوانك المحفوظ...',
                style: TextStyle(
                  color: palette.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (locationChosen && location.hasLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: palette.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                location.displayLabel,
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: onChangeLocation,
              child: const Text('تغيير'),
            ),
          ],
        ),
      );
    }

    if (hasSavedProfile && !locationChosen) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'لم يُحفظ موقع سابق — حدّد موقع التوصيل لأول طلب',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.primary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onChangeLocation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: palette.primary.withValues(alpha: 0.35)),
            ),
            child: Text(
              'تحديد موقع التوصيل',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: palette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
