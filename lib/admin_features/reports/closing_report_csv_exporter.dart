import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/end_of_day_report_model.dart';

/// تصدير تقرير الإغلاق كملف CSV (متوافق مع Excel).
abstract final class ClosingReportCsvExporter {
  ClosingReportCsvExporter._();

  static String buildCsv(EndOfDayReport report) {
    final date = _formatDate(report.reportDate);
    final rows = <List<dynamic>>[
      ['تقرير إغلاق اليوم', date],
      [],
      ['Product Name', 'Quantity Sold', 'Unit Price', 'Total'],
      ...report.productLines.map(
        (line) => [
          line.productName,
          line.quantitySold,
          line.unitPrice.toStringAsFixed(0),
          line.lineTotal.toStringAsFixed(0),
        ],
      ),
      [],
      ['Order Count', report.orderCount],
      ['Total Sales', report.totalSales.toStringAsFixed(0)],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static void downloadCsv(EndOfDayReport report) {
    final csvText = buildCsv(report);
    final fileName =
        'closing_report_${_formatDate(report.reportDate).replaceAll('-', '')}.csv';

    if (kIsWeb) {
      final bytes = html.Blob([csvText], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(bytes);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    debugPrint(
      '[ClosingReportCsvExporter] CSV export is optimized for web. '
      'Length=${csvText.length} bytes, file=$fileName',
    );
    throw UnsupportedError(
      'تصدير CSV متاح من نسخة الويب. افتح لوحة الإدارة من المتصفح.',
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
