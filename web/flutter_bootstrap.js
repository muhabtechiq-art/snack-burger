{{flutter_js}}
{{flutter_build_config}}

(function () {
  'use strict';

  function appBase() {
    var base = window.__SNACK_BURGER_BASE__;
    if (base && typeof base === 'string') {
      return base.endsWith('/') ? base : base + '/';
    }
    var baseEl = document.querySelector('base');
    if (!baseEl || !baseEl.href) return '/';
    try {
      var url = new URL(baseEl.href, window.location.href);
      var path = url.pathname || '/';
      return path.endsWith('/') ? path : path + '/';
    } catch (e) {
      return '/';
    }
  }

  function assetUrl(relativePath) {
    var base = appBase();
    var path = relativePath.charAt(0) === '/' ? relativePath.slice(1) : relativePath;
    return base + path;
  }

  function resolveVersionTag(versionJson) {
    var pinned = window.__SNACK_BURGER_ASSET_VERSION__;
    if (pinned) return String(pinned);

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
          var pathOnly = build.mainJsPath.split('?')[0];
          build.mainJsPath = pathOnly + '?v=' + encoded;
        }
      }
    }
    return encoded;
  }

  function showBootstrapError(message) {
    var el = document.getElementById('snack-burger-loading');
    if (!el) return;
    el.innerHTML =
      '<p style="color:#b00020;font-family:sans-serif;text-align:center;padding:24px">' +
      message +
      '</p>';
  }

  function startApp(tag) {
    applyCacheTag(tag);

    _flutter.loader.load({
      onEntrypointLoaded: function (engineInitializer) {
        engineInitializer
          .initializeEngine()
          .then(function (appRunner) {
            return appRunner.runApp();
          })
          .then(function () {
            console.info('[snack_burger] Flutter app loaded (v=' + tag + ')');
            var loading = document.getElementById('snack-burger-loading');
            if (loading) loading.remove();
          })
          .catch(function (error) {
            console.error('[snack_burger] Flutter engine failed:', error);
            showBootstrapError('تعذّر تحميل التطبيق. حدّث الصفحة (Ctrl+Shift+R).');
          });
      },
    });
  }

  function runBootstrap() {
    fetch(assetUrl('version.json') + '?t=' + Date.now(), { cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) {
          throw new Error('version.json HTTP ' + response.status);
        }
        return response.json();
      })
      .then(function (json) {
        startApp(resolveVersionTag(json));
      })
      .catch(function (error) {
        console.warn('[snack_burger] version.json fetch failed:', error);
        startApp(resolveVersionTag(null));
      });
  }

  // Do not wait for window "load" — dynamic scripts often miss that event.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', runBootstrap);
  } else {
    runBootstrap();
  }
})();
