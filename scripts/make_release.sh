#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(date '+%Y.%m.%d.%H%M')}"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE="cabalm-mac-kit-$VERSION.zip"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$PACKAGE"

cd "$ROOT_DIR"
/usr/bin/zip -r "$DIST_DIR/$PACKAGE" \
  README.md README.zh-CN.md LICENSE install.sh config scripts \
  -x 'config/cabalm.env' \
  -x '*.DS_Store' \
  -x '*.log' \
  -x '*.png' \
  -x '*.jpg' \
  -x '*.jpeg' \
  -x '*.mp4' \
  -x '*.mov'

echo "$DIST_DIR/$PACKAGE"

