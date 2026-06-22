import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/delivery_order_model.dart';
import '../../models/order_model.dart';
import '../../services/printer_preferences.dart';
import '../../services/receipt_escpos_builder.dart';
import '../../services/win32_raw_printer.dart';
import '../../services/windows_printer_bridge.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// إعدادات طباعة Windows — كاشير ومطبخ منفصلان (ESC/POS RAW).
class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key, required this.slug});

  final String slug;

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<String> _printerNames = const [];
  String? _selectedCashierPrinter;
  String? _selectedKitchenPrinter;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _statusMessage;

  bool get _samePrinter {
    final cashier = _selectedCashierPrinter?.trim().toLowerCase();
    final kitchen = _selectedKitchenPrinter?.trim().toLowerCase();
    if (cashier == null ||
        kitchen == null ||
        cashier.isEmpty ||
        kitchen.isEmpty) {
      return false;
    }
    return cashier == kitchen;
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadPrinters();
    } else {
      _loading = false;
    }
  }

  DeliveryOrder _sampleTestOrder() {
    return DeliveryOrder(
      id: 'test-print',
      restaurantId: widget.slug,
      slug: widget.slug,
      customerName: 'اختبار',
      customerPhone: '07701234567',
      address: 'اختبار الطباعة',
      items: const [
        CartItem(
          lineId: 'line-test',
          productId: 'p-test',
          name: 'برجر',
          quantity: 1,
          baseUnitPrice: 5000,
          unitPrice: 5000,
          selectedAddons: [],
        ),
      ],
      totalPrice: 5000,
      status: 'accepted',
      createdAt: DateTime.now(),
      businessDayOrderNumber: 1,
    );
  }

  String? _pickInstalledName(List<String> names, String preferred) {
    final trimmed = preferred.trim();
    if (trimmed.isEmpty) return names.isNotEmpty ? names.first : null;
    if (names.contains(trimmed)) return trimmed;
    final lower = trimmed.toLowerCase();
    for (final name in names) {
      if (name.toLowerCase().contains(lower)) return name;
    }
    return names.isNotEmpty ? names.first : trimmed;
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final names = await Win32RawPrinter.listPrinterNames();
      final savedCashier = await PrinterPreferences.getCashierPrinterName();
      final savedKitchen = await PrinterPreferences.getKitchenPrinterName();

      if (!mounted) return;
      setState(() {
        _printerNames = names;
        _selectedCashierPrinter = _pickInstalledName(names, savedCashier);
        _selectedKitchenPrinter = _pickInstalledName(names, savedKitchen);
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] _loadPrinters: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _onCashierPrinterChanged(String? name) async {
    if (name == null || name.isEmpty) return;
    setState(() => _selectedCashierPrinter = name);
    await PrinterPreferences.setCashierPrinterName(name);
  }

  Future<void> _onKitchenPrinterChanged(String? name) async {
    if (name == null || name.isEmpty) return;
    setState(() => _selectedKitchenPrinter = name);
    await PrinterPreferences.setKitchenPrinterName(name);
  }

  Future<void> _logToConsole() async {
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      await WindowsPrinterBridge.logInstalledPrintersToConsole();
      if (!mounted) return;
      setState(() => _statusMessage = 'تم — راجع الكونسول');
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] _logToConsole: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printCashierTest() async {
    final printer = _selectedCashierPrinter?.trim();
    if (printer == null || printer.isEmpty) {
      setState(() => _error = 'اختر طابعة الكاشير أولاً');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      const tag = '[PrinterSettingsPage] cashierTest';
      final bytes = await ReceiptEscPosBuilder.buildCashierReceiptBytes(
        _sampleTestOrder(),
      );
      debugPrint('$tag bytes.length=${bytes.length} → "$printer"');
      await Win32RawPrinter.printRawBytes(bytes, printerName: printer);

      if (!mounted) return;
      setState(() => _statusMessage = 'تم إرسال اختبار الكاشير');
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] فشل اختبار الكاشير: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = 'فشل اختبار الكاشير: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printKitchenTest() async {
    final printer = _selectedKitchenPrinter?.trim();
    if (printer == null || printer.isEmpty) {
      setState(() => _error = 'اختر طابعة المطبخ أولاً');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      const tag = '[PrinterSettingsPage] kitchenTest';
      final bytes = await ReceiptEscPosBuilder.buildKitchenReceiptBytes(
        _sampleTestOrder(),
      );
      debugPrint('$tag bytes.length=${bytes.length} → "$printer"');
      await Win32RawPrinter.printRawBytes(bytes, printerName: printer);

      if (!mounted) return;
      setState(() => _statusMessage = 'تم إرسال اختبار المطبخ');
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] فشل اختبار المطبخ: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = 'فشل اختبار المطبخ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildPrinterDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    if (_printerNames.isEmpty) {
      return const Text(
        'لا توجد طابعات',
        style: TextStyle(color: AdminPanelColors.textMuted, fontSize: 13),
      );
    }

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AdminPanelColors.cardCream.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AdminPanelColors.gold.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AdminPanelColors.gold.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: AdminPanelColors.charcoalLight,
          value: value != null && _printerNames.contains(value) ? value : null,
          hint: const Text(
            'اختر الطابعة',
            style: TextStyle(color: AdminPanelColors.textMuted, fontSize: 14),
          ),
          items: _printerNames
              .map(
                (name) => DropdownMenuItem(
                  value: name,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AdminPanelColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _busy ? null : onChanged,
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required String? selectedPrinter,
    required ValueChanged<String?> onChanged,
    required VoidCallback onTest,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPanelColors.cardCream.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminPanelColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AdminPanelColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrinterDropdown(value: selectedPrinter, onChanged: onChanged),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : onTest,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminPanelColors.gold,
              side: BorderSide(
                color: AdminPanelColors.gold.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('اختبار'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _loadPrinters,
          icon: const Icon(Icons.refresh, size: 18, color: AdminPanelColors.gold),
          label: const Text(
            'تحديث القائمة',
            style: TextStyle(color: AdminPanelColors.textMuted, fontSize: 13),
          ),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _logToConsole,
          icon: const Icon(Icons.terminal, size: 18, color: AdminPanelColors.gold),
          label: const Text(
            'الكونسول',
            style: TextStyle(color: AdminPanelColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return AdminPageScaffold(
        slug: widget.slug,
        title: 'إعدادات الطابعات',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Windows فقط',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminPanelColors.textMuted),
            ),
          ),
        ),
      );
    }

    return AdminPageScaffold(
      slug: widget.slug,
      title: 'إعدادات الطابعات',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildRoleCard(
                  title: 'طابعة الكاشير',
                  icon: Icons.point_of_sale_rounded,
                  selectedPrinter: _selectedCashierPrinter,
                  onChanged: _onCashierPrinterChanged,
                  onTest: _printCashierTest,
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  title: 'طابعة المطبخ',
                  icon: Icons.restaurant_rounded,
                  selectedPrinter: _selectedKitchenPrinter,
                  onChanged: _onKitchenPrinterChanged,
                  onTest: _printKitchenTest,
                ),
                if (_samePrinter) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'الكاشير والمطبخ على نفس الطابعة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AdminPanelColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildFooterActions(),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green.shade300,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
