#!/usr/bin/env bash
set -euo pipefail

if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:$(pwd)/flutter/bin"
flutter config --enable-web
flutter pub get
