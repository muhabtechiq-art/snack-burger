import 'package:flutter/material.dart';

import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../data/customer_order_repository.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({
    super.key,
    required this.slug,
    required this.orderId,
  });

  final String slug;
  final String orderId;

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final CustomerOrderRepository _repository = CustomerOrderRepository();
  int _retrySeed = 0;

  void _retry() {
    setState(() => _retrySeed++);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _repository.watchOrderById(orderId: widget.orderId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('متابعة حالة الطلب'),
          centerTitle: true,
        ),
        body: StreamBuilder<DeliveryOrder?>(
          key: ValueKey('${widget.orderId}|$_retrySeed'),
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _OrderStatusErrorState(onRetry: _retry);
            }

            final order = snapshot.data;
            if (order == null) {
              return _OrderNotFoundState(onRetry: _retry);
            }

            final isLive = snapshot.connectionState == ConnectionState.active;
            return RefreshIndicator(
              onRefresh: () async => _retry(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _LiveBadge(isLive: isLive),
                  const SizedBox(height: 14),
                  _OrderSummaryCard(order: order),
                  const SizedBox(height: 14),
                  _StatusTimeline(currentStatus: order.status),
                  const SizedBox(height: 14),
                  _OrderItemsCard(order: order),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
          color: isLive ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          isLive ? 'اتصال مباشر' : 'جاري إعادة الاتصال...',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('رقم الطلب: ${order.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('الاسم: ${order.customerName}'),
            Text('الهاتف: ${order.customerPhone}'),
            Text('العنوان: ${order.address}'),
            const SizedBox(height: 8),
            Text(
              'الإجمالي: ${order.totalPrice.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تفاصيل الطلب',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (final item in order.items) ...[
              Row(
                children: [
                  Text(
                    '${item.lineTotal.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${item.quantity}x ${item.printableName}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus});

  final String currentStatus;

  static const List<_StatusStep> _steps = [
    _StatusStep(value: DeliveryOrderStatus.pending, label: 'قيد الانتظار'),
    _StatusStep(value: DeliveryOrderStatus.accepted, label: 'تم القبول'),
    _StatusStep(value: DeliveryOrderStatus.delivering, label: 'قيد التوصيل'),
    _StatusStep(value: DeliveryOrderStatus.delivered, label: 'تم التسليم'),
  ];

  int _statusIndex(String status) {
    final index = _steps.indexWhere((step) => step.value == status);
    if (index >= 0) return index;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _statusIndex(currentStatus);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حالة الطلب',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++)
              _StatusTile(
                label: _steps[i].label,
                done: i <= activeIndex,
                last: i == _steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.done,
    required this.last,
  });

  final String label;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green : Colors.grey.shade400;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: color),
            if (!last)
              Container(
                width: 2,
                height: 24,
                color: color,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: TextStyle(
                color: done ? Colors.black87 : Colors.grey.shade600,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderStatusErrorState extends StatelessWidget {
  const _OrderStatusErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('تعذر تحميل حالة الطلب'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة الاتصال'),
          ),
        ],
      ),
    );
  }
}

class _OrderNotFoundState extends StatelessWidget {
  const _OrderNotFoundState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('لم يتم العثور على الطلب'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _StatusStep {
  const _StatusStep({required this.value, required this.label});

  final String value;
  final String label;
}
