#!/usr/bin/env bash
# Build Flutter web for GitHub Pages (project site: /snack-burger/)
set -euo pipefail

BASE_HREF="${GITHUB_PAGES_BASE_HREF:-/snack-burger/}"

flutter pub get
flutter build web --release \
  --base-href "$BASE_HREF" \
  --no-wasm-dry-run \
  --pwa-strategy=none
bash scripts/post_build_gh_pages.sh

echo "GitHub Pages build complete (base-href=$BASE_HREF)"
