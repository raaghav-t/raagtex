#!/usr/bin/env bash
set -euo pipefail

bash -n Scripts/build.sh Scripts/test.sh Scripts/run-sample-compile.sh

echo "[test] Script syntax checks passed"

echo "[test] Running sample LaTeX compile smoke test"
Scripts/run-sample-compile.sh

echo "[test] Running Swift package tests"
if ! swift test; then
  echo "[test] Swift tests failed."
  echo "[test] If this is a first-run machine, ensure Xcode license/toolchain setup is complete."
  echo "[test] Try: sudo xcodebuild -license"
  exit 1
fi
