import 'dart:io';

import 'package:flutter/material.dart';

import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../../core/config/printer_config.dart';
import '../../services/printer_preferences.dart';
import '../../services/receipt_escpos_builder.dart';
import '../../services/win32_raw_printer.dart';
import '../../services/windows_printer_bridge.dart';

/// إعدادات طباعة Windows — ESC/POS RAW عبر WinSpooler.
class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key, required this.slug});

  final String slug;

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  List<String> _printerNames = const [];
  String? _selectedPrinter;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadPrinters();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final names = await Win32RawPrinter.listPrinterNames();
      final saved = await PrinterPreferences.getWindowsPrinterName();
      final resolved = await Win32RawPrinter.resolvePrinterName(
        preferred: saved,
      );

      if (!mounted) return;
      setState(() {
        _printerNames = names;
        _selectedPrinter = names.contains(resolved)
            ? resolved
            : (names.isNotEmpty ? names.first : saved);
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

  Future<void> _onPrinterChanged(String? name) async {
    if (name == null || name.isEmpty) return;
    setState(() => _selectedPrinter = name);
    await PrinterPreferences.setWindowsPrinterName(name);
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
      setState(() {
        _statusMessage = 'راجع كونسول flutter run لقائمة الطابعات';
      });
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] _logToConsole: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printTestReceipt() async {
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      const tag = '[PrinterSettingsPage] testPrint';
      final bytes = await ReceiptEscPosBuilder.buildTestReceiptBytes();
      final defaultName = await Win32RawPrinter.getDefaultPrinterName();

      debugPrint(
        '$tag bytes.length=${bytes.length} → default printer'
        '${defaultName != null ? ' ("$defaultName")' : ''}',
      );

      await Win32RawPrinter.printRawBytesToDefault(bytes);

      if (!mounted) return;
      final mode = PrinterConfig.useRasterReceipt ? 'صورة' : 'ESC t 22';
      final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
      setState(() {
        _statusMessage = defaultName != null
            ? 'تم الإرسال ($sizeKb KB، $mode) → $defaultName'
            : 'تم الإرسال ($sizeKb KB، $mode) → الطابعة الافتراضية';
      });
    } catch (e, stack) {
      debugPrint('[PrinterSettingsPage] فشل الاختبار: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = 'فشل الاختبار: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return AdminPageScaffold(
        slug: widget.slug,
        title: 'إعدادات الطابعة',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'الطباعة RAW متاحة على Windows فقط.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminPanelColors.textMuted),
            ),
          ),
        ),
      );
    }

    return AdminPageScaffold(
      slug: widget.slug,
      title: 'إعدادات الطابعة',
      body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'الطباعة التجريبية تُرسل فاتورة ESC/POS (CP864، ESC t 22) '
                    'إلى الطابعة الافتراضية في Windows.',
                    style: const TextStyle(
                      color: AdminPanelColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'اختر الطابعة',
                    style: const TextStyle(
                      color: AdminPanelColors.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_printerNames.isEmpty)
                    const Text('لا توجد طابعات — تأكد من تثبيت Generic / Text Only')
                  else
                    InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'اسم الطابعة في Windows',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedPrinter != null &&
                                  _printerNames.contains(_selectedPrinter)
                              ? _selectedPrinter
                              : null,
                          hint: const Text('اسم الطابعة في Windows'),
                          items: _printerNames
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: _busy ? null : _onPrinterChanged,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _printTestReceipt,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long),
                    label: const Text(
                      'طباعة تجريبية → الطابعة الافتراضية',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : _loadPrinters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث قائمة الطابعات'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : _logToConsole,
                    icon: const Icon(Icons.terminal),
                    label: const Text('طباعة القائمة في الكونسول'),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
    );
  }
}
