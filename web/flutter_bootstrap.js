{{flutter_js}}
{{flutter_build_config}}

(function () {
  'use strict';

  var initialVersionTag = null;
  var silentReloadScheduled = false;

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

  function scheduleSilentReload() {
    if (silentReloadScheduled) return;
    silentReloadScheduled = true;
    window.setTimeout(function () {
      window.location.reload();
    }, 250);
  }

  function bindServiceWorkerAutoReload() {
    if (!('serviceWorker' in navigator)) return;

    navigator.serviceWorker.addEventListener('controllerchange', function () {
      scheduleSilentReload();
    });

    navigator.serviceWorker.ready
      .then(function (registration) {
        registration.addEventListener('updatefound', function () {
          var newWorker = registration.installing;
          if (!newWorker) return;

          newWorker.addEventListener('statechange', function () {
            if (
              newWorker.state === 'installed' &&
              navigator.serviceWorker.controller
            ) {
              newWorker.postMessage({ type: 'SKIP_WAITING' });
            }
          });
        });

        return registration.update();
      })
      .catch(function (error) {
        console.warn('[snack_burger] service worker update check failed:', error);
      });
  }

  function probeRemoteVersion() {
    if (initialVersionTag == null) return;

    fetch('version.json?t=' + Date.now(), { cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) {
          throw new Error('version.json HTTP ' + response.status);
        }
        return response.json();
      })
      .then(function (json) {
        var remoteTag = buildCacheTag(json);
        if (remoteTag === initialVersionTag) return;

        if (!('serviceWorker' in navigator)) {
          scheduleSilentReload();
          return;
        }

        return navigator.serviceWorker.getRegistration().then(function (registration) {
          if (!registration) {
            scheduleSilentReload();
            return;
          }

          return registration.update().then(function () {
            if (registration.waiting) {
              registration.waiting.postMessage({ type: 'SKIP_WAITING' });
              return;
            }
            scheduleSilentReload();
          });
        });
      })
      .catch(function (error) {
        console.warn('[snack_burger] background version probe failed:', error);
      });
  }

  function bindBackgroundUpdateChecks() {
    window.addEventListener('focus', probeRemoteVersion);
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'visible') {
        probeRemoteVersion();
      }
    });
  }

  function startApp(tag) {
    initialVersionTag = tag;
    var encoded = applyCacheTag(tag);

    bindServiceWorkerAutoReload();
    bindBackgroundUpdateChecks();

    _flutter.loader.load({
      serviceWorkerSettings: {
        timeoutMillis: 40000,
        serviceWorkerUrl: 'flutter_service_worker.js?v=' + encoded,
        serviceWorkerVersion: {{flutter_service_worker_version}},
      },
      onEntrypointLoaded: function () {
        probeRemoteVersion();
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
