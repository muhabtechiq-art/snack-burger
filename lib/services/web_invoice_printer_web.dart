import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/delivery_order_model.dart';
import 'web_invoice_canvas.dart';

const _postLoadDelay = Duration(milliseconds: 400);
const _cleanupDelay = Duration(seconds: 2);

/// يرسم الفاتورة على Canvas كـ PNG ثم يطبع iframe يحتوي <img> فقط.
Future<void> printWebInvoice(DeliveryOrder order) async {
  final pngDataUrl = renderReceiptPngDataUrl(order);

  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.style.display = 'none';
  iframe.style.position = 'fixed';
  iframe.style.border = '0';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.visibility = 'hidden';

  final iframeLoaded = Completer<void>();
  iframe.onload = ((web.Event _) {
    if (!iframeLoaded.isCompleted) iframeLoaded.complete();
  }).toJS;

  iframe.srcdoc = buildPrintShellHtml().toJS;
  web.document.body?.appendChild(iframe);

  await iframeLoaded.future.timeout(
    const Duration(seconds: 2),
    onTimeout: () {},
  );

  final doc = iframe.contentDocument;
  final body = doc?.body;
  if (body == null) {
    iframe.remove();
    return;
  }

  var printed = false;
  final printDone = Completer<void>();

  void schedulePrint() {
    if (printed) return;
    printed = true;

    Future<void>.delayed(_postLoadDelay, () {
      iframe.contentWindow?.print();
      Future<void>.delayed(_cleanupDelay, () {
        iframe.remove();
        if (!printDone.isCompleted) printDone.complete();
      });
    });
  }

  final img = doc!.createElement('img') as web.HTMLImageElement;
  img.alt = 'receipt';
  img.style.width = '100%';
  img.style.maxWidth = '80mm';
  img.style.display = 'block';
  img.style.margin = '0 auto';

  img.onload = ((web.Event _) => schedulePrint()).toJS;
  img.onerror = ((web.Event _) => schedulePrint()).toJS;

  body.appendChild(img);
  img.src = pngDataUrl;

  if (img.complete && img.naturalWidth > 0) {
    schedulePrint();
  }

  await printDone.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      if (!printed) {
        iframe.contentWindow?.print();
      }
      iframe.remove();
    },
  );
}
