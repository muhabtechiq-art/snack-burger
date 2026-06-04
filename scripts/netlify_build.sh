#!/usr/bin/env bash
# يُشغَّل على Netlify عند الربط بـ GitHub (Build command في netlify.toml)
set -euo pipefail

if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:$(pwd)/flutter/bin"
flutter config --enable-web
flutter pub get
flutter build web --release

if [ -f web/_redirects ]; then
  cp web/_redirects build/web/_redirects
fi

if [ -f build/web/flutter_service_worker.js ]; then
  rm -f build/web/flutter_service_worker.js
fi
