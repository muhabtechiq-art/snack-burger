#!/usr/bin/env bash
# Post-build steps for GitHub Pages (SPA routing + Jekyll bypass + index.html).
set -euo pipefail

out_dir="build/web"
source_index="web/index.html"
out_index="${out_dir}/index.html"
gh_base="${GITHUB_PAGES_BASE_HREF:-/snack-burger/}"

resolve_cache_tag() {
  if [[ -n "${SNACK_BURGER_CACHE_TAG:-}" ]]; then
    echo "${SNACK_BURGER_CACHE_TAG}"
    return
  fi
  if [[ -n "${GITHUB_SHA:-}" ]]; then
    echo "${GITHUB_SHA:0:7}"
    return
  fi
  if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
    echo "build-${GITHUB_RUN_NUMBER}"
    return
  fi
  if command -v git &>/dev/null && git rev-parse --short HEAD &>/dev/null; then
    git rev-parse --short HEAD
    return
  fi
  date +%s
}

cache_tag="$(resolve_cache_tag)"

if [[ ! -f "${out_index}" ]]; then
  echo "Missing ${out_index} — run flutter build web first." >&2
  exit 1
fi

if [[ -f "${source_index}" ]]; then
  sed \
    -e "s|\$FLUTTER_BASE_HREF|${gh_base}|g" \
    -e "s|__CACHE_TAG__|${cache_tag}|g" \
    "${source_index}" > "${out_index}"
  echo "GitHub Pages post-build: applied web/index.html (cache tag=${cache_tag})"
else
  echo "GitHub Pages post-build: missing web/index.html — using Flutter output" >&2
fi

if [[ -f "${out_dir}/version.json" ]] && command -v node &>/dev/null; then
  node -e "
    const fs = require('fs');
    const p = '${out_dir}/version.json';
    const j = JSON.parse(fs.readFileSync(p, 'utf8'));
    j.deploy_tag = '${cache_tag}';
    fs.writeFileSync(p, JSON.stringify(j, null, 2));
  "
  echo "GitHub Pages post-build: version.json deploy_tag=${cache_tag}"
fi

cp -f "${out_index}" "${out_dir}/404.html"
touch "${out_dir}/.nojekyll"

if [[ -f "${out_dir}/flutter_service_worker.js" ]]; then
  rm -f "${out_dir}/flutter_service_worker.js"
  echo "GitHub Pages post-build: removed flutter_service_worker.js"
fi

echo "GitHub Pages post-build: copied 404.html and wrote .nojekyll"
