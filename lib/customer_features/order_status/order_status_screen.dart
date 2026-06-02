import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/delivery_order_model.dart';
import '../../models/delivery_order_status.dart';
import '../../services/supabase_order_service.dart';
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

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with WidgetsBindingObserver {
  final CustomerOrderRepository _repository = CustomerOrderRepository();
  int _retrySeed = 0;
  String? _streamKey;
  Stream<DeliveryOrder?>? _orderStream;
  StreamHealth _streamHealth = StreamHealth.connecting;

  bool get _isLive => _streamHealth == StreamHealth.live;

  void _retry() {
    setState(() {
      _retrySeed++;
      _streamKey = null;
      _orderStream = null;
      _streamHealth = StreamHealth.connecting;
    });
  }

  void _onHealthChanged(StreamHealth health) {
    if (!mounted || _streamHealth == health) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() => _streamHealth = health);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _streamHealth == health) return;
      setState(() => _streamHealth = health);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamKey = '${widget.orderId}|$_retrySeed';
    if (_streamKey != streamKey || _orderStream == null) {
      _streamKey = streamKey;
      _orderStream = _repository.watchOrderById(
        orderId: widget.orderId,
        onHealthChanged: _onHealthChanged,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EF),
        appBar: AppBar(
          title: const Text('متابعة حالة الطلب'),
          centerTitle: true,
          backgroundColor: const Color(0xFFB70F1E),
          foregroundColor: const Color(0xFFD4AF37),
        ),
        body: StreamBuilder<DeliveryOrder?>(
          key: ValueKey('${widget.orderId}|$_retrySeed'),
          stream: _orderStream,
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

            return RefreshIndicator(
              onRefresh: () async => _retry(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _LiveBadge(health: _streamHealth),
                  if (!_isLive) ...[
                    const SizedBox(height: 10),
                    _ConnectionWarning(
                      health: _streamHealth,
                      onRetry: _retry,
                    ),
                  ],
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
  const _LiveBadge({required this.health});

  final StreamHealth health;

  @override
  Widget build(BuildContext context) {
    final isLive = health == StreamHealth.live;
    final title = switch (health) {
      StreamHealth.connecting => 'جاري الاتصال...',
      StreamHealth.live => 'اتصال مباشر',
      StreamHealth.reconnecting => 'جاري إعادة الاتصال...',
      StreamHealth.stale => 'البيانات متأخرة',
      StreamHealth.error => 'خطأ اتصال',
      StreamHealth.disposed => 'تم إيقاف التتبع',
    };
    return Row(
      children: [
        Icon(
          isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
          color: isLive ? const Color(0xFFB70F1E) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ConnectionWarning extends StatelessWidget {
  const _ConnectionWarning({
    required this.health,
    required this.onRetry,
  });

  final StreamHealth health;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = switch (health) {
      StreamHealth.reconnecting => 'جاري استعادة الاتصال تلقائياً...',
      StreamHealth.stale => 'قد تكون الحالة المعروضة قديمة قليلاً.',
      StreamHealth.error => 'تعذر تحديث حالة الطلب حالياً.',
      StreamHealth.connecting => 'تجهيز القناة المباشرة للطلب...',
      StreamHealth.live => '',
      StreamHealth.disposed => 'انتهت جلسة التتبع.',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('إعادة الاتصال'),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
      ),
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
    _StatusStep(
      value: DeliveryOrderStatus.pending,
      label: 'بانتظار التأكيد',
    ),
    _StatusStep(
      value: DeliveryOrderStatus.accepted,
      label: 'تم قبول الطلب وبدأ التحضير',
    ),
    _StatusStep(
      value: DeliveryOrderStatus.delivering,
      label: 'خرج الطلب مع الكابتن',
    ),
    _StatusStep(
      value: DeliveryOrderStatus.delivered,
      label: 'تم التوصيل بنجاح',
    ),
  ];

  int _statusIndex(String status) {
    if (status == DeliveryOrderStatus.preparing) return 1;
    final index = _steps.indexWhere((step) => step.value == status);
    if (index >= 0) return index;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _statusIndex(currentStatus);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
      ),
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
    final color = done ? const Color(0xFFB70F1E) : Colors.grey.shade400;
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
