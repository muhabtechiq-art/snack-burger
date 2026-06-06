# Web cache busting (Snack Burger Flutter)

## How updates reach users

1. **`web/index.html`** (copied into `build/web/` after each build):
   - Unregisters all legacy service workers on load.
   - Resolves paths from `<base href="$FLUTTER_BASE_HREF">` (→ `/snack-burger/` on GitHub Pages).
   - Loads `flutter_bootstrap.js` with `?v=` from meta `snack-burger-asset-version` (default `1.1`).

2. **`web/flutter_bootstrap.js`** (processed at build time):
   - Does **not** register a service worker.
   - Fetches **`version.json`** with `cache: 'no-store'`.
   - Appends `?v=<version>` to **`main.dart.js`** (meta tag, or `version` + `build_number` from `pubspec.yaml`).

3. Post-build **removes** `flutter_service_worker.js` from `build/web/`.

4. **`netlify.toml`** sets `Cache-Control: no-cache` on entry HTML/JS files. Hashed assets under `/assets/` stay long-cached.

## After each release

Bump **both**:

- `pubspec.yaml` (updates `version.json` at build time), e.g. `version: 1.0.2+3`
- `<meta name="snack-burger-asset-version" content="1.2">` in `web/index.html` when you need to force clients off an old `main.dart.js` cache

Then rebuild and deploy.

## Local build

```powershell
flutter build web --release --base-href /snack-burger/
.\scripts\post_build_gh_pages.ps1
```

Or run the all-in-one script:

```powershell
.\scripts\github_pages_build.ps1
```

On CI (Linux), `node scripts/post_build_gh_pages.js` is used instead.
