#!/usr/bin/env bash
set -euo pipefail

SAMPLE_DIR="$(cd "$(dirname "$0")/../Examples/SampleProject" && pwd)"

if ! command -v latexmk >/dev/null 2>&1; then
  echo "[sample-compile] latexmk not found. Install a TeX distribution first."
  exit 1
fi

echo "[sample-compile] Running latexmk on sample project..."
cd "$SAMPLE_DIR"
latexmk -pdf main.tex
