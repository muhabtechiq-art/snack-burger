{{flutter_js}}
{{flutter_build_config}}

(function () {
  'use strict';

  function buildCacheTag(versionJson) {
    if (
      versionJson &&
      versionJson.version != null &&
      versionJson.build_number != null
    ) {
      return String(versionJson.version) + '+' + String(versionJson.build_number);
    }
    if (versionJson && versionJson.version != null) {
      return String(versionJson.version);
    }
    return String(Date.now());
  }

  function applyCacheTag(tag) {
    var encoded = encodeURIComponent(tag);
    var builds =
      window._flutter &&
      window._flutter.buildConfig &&
      window._flutter.buildConfig.builds;

    if (builds && builds.length) {
      for (var i = 0; i < builds.length; i++) {
        var build = builds[i];
        if (!build || build.compileTarget !== 'dart2js') continue;
        if (build.mainJsPath) {
          build.mainJsPath = build.mainJsPath.split('?')[0] + '?v=' + encoded;
        }
      }
    }
    return encoded;
  }

  function startApp(tag) {
    var encoded = applyCacheTag(tag);
    _flutter.loader.load({
      serviceWorkerSettings: {
        timeoutMillis: 40000,
        serviceWorkerUrl: 'flutter_service_worker.js?v=' + encoded,
        serviceWorkerVersion: {{flutter_service_worker_version}},
      },
    });
  }

  window.addEventListener('load', function () {
    fetch('version.json?t=' + Date.now(), { cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) {
          throw new Error('version.json HTTP ' + response.status);
        }
        return response.json();
      })
      .then(function (json) {
        startApp(buildCacheTag(json));
      })
      .catch(function (error) {
        console.warn('[snack_burger] version.json fetch failed:', error);
        startApp(String(Date.now()));
      });
  });
})();
