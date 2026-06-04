import 'package:flutter/material.dart';

import '../../../core/theme/tenant_palette.dart';
import '../../../models/delivery_order_model.dart';
import '../../data/admin_repositories.dart';
import 'order_item_receipt_lines.dart';

/// تفاصيل طلب مرفوض + حقل سبب الرفض.
class RejectedOrderReasonSheet extends StatefulWidget {
  const RejectedOrderReasonSheet({
    super.key,
    required this.order,
    required this.palette,
    this.orderRepository,
  });

  final DeliveryOrder order;
  final TenantPalette palette;
  final AdminOrderRepository? orderRepository;

  static Future<void> show({
    required BuildContext context,
    required DeliveryOrder order,
    required TenantPalette palette,
    AdminOrderRepository? orderRepository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RejectedOrderReasonSheet(
          order: order,
          palette: palette,
          orderRepository: orderRepository,
        ),
      ),
    );
  }

  @override
  State<RejectedOrderReasonSheet> createState() =>
      _RejectedOrderReasonSheetState();
}

class _RejectedOrderReasonSheetState extends State<RejectedOrderReasonSheet> {
  late final TextEditingController _reasonController;
  late final AdminOrderRepository _repository;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.orderRepository ?? AdminOrderRepository();
    _reasonController = TextEditingController(
      text: widget.order.rejectionReason ?? '',
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveReason() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _repository.updateRejectionReason(
        orderId: widget.order.id,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ سبب الرفض')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final palette = widget.palette;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'طلب مرفوض — ${order.customerName}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  if (order.needsRejectionReason)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'بانتظار السبب',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoLine(label: 'الهاتف', value: order.customerPhone),
                    _InfoLine(label: 'العنوان', value: order.address),
                    _InfoLine(
                      label: 'الإجمالي',
                      value: '${order.totalPrice.toStringAsFixed(0)} د.ع',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الوجبات',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderItemReceiptLines(
                          item: item,
                          primaryColor: palette.primary,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'سبب الرفض',
                        hintText: 'اكتب سبب رفض الطلب للأرشيف...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: palette.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveReason,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ سبب الرفض'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
