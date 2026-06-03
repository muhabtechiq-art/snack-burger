# Web cache busting (Snack Burger Flutter)

## How updates reach users

1. **`web/index.html`** loads `flutter_bootstrap.js?v=<timestamp>` on every visit so the bootstrap is never served from a stale browser cache (important on GitHub Pages, which has no custom cache headers).

2. **`web/flutter_bootstrap.js`** (processed at build time):
   - Fetches **`version.json`** with `cache: 'no-store'` and a timestamp query param.
   - Builds a tag from `version` + `build_number` in `pubspec.yaml` (e.g. `1.0.0+1`).
   - Appends `?v=<tag>` to **`main.dart.js`** and **`flutter_service_worker.js`** so each deploy gets unique URLs.

3. **`netlify.toml`** sets `Cache-Control: no-cache` on `index.html`, `flutter_bootstrap.js`, `main.dart.js`, `flutter_service_worker.js`, and `version.json`. Hashed assets under `/assets/` stay long-cached.

## After each release

Bump the version in **`pubspec.yaml`** so `version.json` changes, for example:

```yaml
version: 1.0.1+2
```

Then rebuild and deploy. Users get the new `version.json` tag and load fresh JS without a hard refresh.

## Local build

```bash
flutter build web --release
# GitHub Pages subpath:
flutter build web --release --base-href /snack-burger/
```

## Optional: disable the service worker

If you still see stale builds in some browsers, you can disable the PWA service worker entirely:

```bash
flutter build web --release --pwa-strategy=none
```

Add that flag to `scripts/netlify_build.sh` and `.github/workflows/deploy-github-pages.yml` if needed.
