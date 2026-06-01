#!/usr/bin/env bash
set -euo pipefail

export PATH="$PATH:$(pwd)/flutter/bin"
flutter build web --release
