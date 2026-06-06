#!/usr/bin/env bash
# Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + index.html).
set -euo pipefail

out_dir="build/web"
source_index="web/index.html"
out_index="${out_dir}/index.html"
gh_base="${GITHUB_PAGES_BASE_HREF:-/snack-burger/}"

if [[ ! -f "${out_index}" ]]; then
  echo "Missing ${out_index} — run flutter build web first." >&2
  exit 1
fi

if [[ -f "${source_index}" ]]; then
  sed "s|\$FLUTTER_BASE_HREF|${gh_base}|g" "${source_index}" > "${out_index}"
  echo "GitHub Pages post-build: applied web/index.html"
else
  echo "GitHub Pages post-build: missing web/index.html — using Flutter output" >&2
fi

cp -f "${out_index}" "${out_dir}/404.html"
touch "${out_dir}/.nojekyll"

if [[ -f "${out_dir}/flutter_service_worker.js" ]]; then
  rm -f "${out_dir}/flutter_service_worker.js"
  echo "GitHub Pages post-build: removed flutter_service_worker.js"
fi

echo "GitHub Pages post-build: copied 404.html and wrote .nojekyll"
