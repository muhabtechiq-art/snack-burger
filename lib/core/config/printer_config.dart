/// إعدادات الطباعة — Windows ESC/POS خام (CP864) عبر USB أو مُجمّع النظام.
abstract final class PrinterConfig {
  /// الاسم كما يظهر في Windows (مثلاً على منفذ USB001).
  static const String windowsSpoolerPrinterName = 'Generic / Text Only';

  /// منفذ USB كما يظهر في خصائص الطابعة (محاولة كتابة مباشرة).
  static const String windowsUsbDevicePath = r'\\.\USB001';

  /// مسارات USB المحتملة — تُجرَّب بالترتيب مع [File.writeAsBytesSync].
  static const List<String> windowsUsbDevicePaths = <String>[
    windowsUsbDevicePath,
    r'\\.\usb001',
  ];

  /// بروفايل ESC/POS — XP-N160I (CP864 على id=28) شائع في الطابعات الحرارية.
  static const String escPosCapabilityProfile = 'XP-N160I';

  static const List<String> escPosProfileFallbacks = <String>[
    escPosCapabilityProfile,
    'TP806L',
    'default',
  ];

  /// جدول CP864 — ESC t 22 (مُختبر على الطابعة).
  static const int arabicCodePageId = 22;

  /// طباعة الفاتورة كصورة نقطية — أفضل للعربية على Generic / Text Only.
  static const bool useRasterReceipt = true;

  /// تكبير خطوط ومحتوى الفاتورة (+200px نسبةً لعرض 576).
  static const double receiptRasterBoostPx = 200;

  /// اسم المطعم على الفاتورة.
  static const String restaurantDisplayName = 'Snack Burger';
}
