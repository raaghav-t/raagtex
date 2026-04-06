#!/usr/bin/env bash
set -euo pipefail

echo "[build] Running Swift package build"
if ! swift build; then
  echo "[build] Build failed."
  echo "[build] If this is a first-run machine, ensure Xcode license/toolchain setup is complete."
  echo "[build] Try: sudo xcodebuild -license"
  exit 1
fi
