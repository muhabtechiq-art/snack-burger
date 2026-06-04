'use strict';

// تفعيل فوري للنسخة الجديدة — يستبدل worker القديم دون انتظار إغلاق التبويبات.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('message', function (event) {
  var data = event.data;
  if (!data) return;
  if (data === 'skipWaiting' || (data && data.type === 'SKIP_WAITING')) {
    self.skipWaiting();
  }
});
