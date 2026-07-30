#!/usr/bin/env bash
# Build DETF litepaper PDF (requires pandoc + xelatex).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

pandoc DETF_LITEPAPAPER.md \
  -o DETF_LITEPAPAPER.pdf \
  --pdf-engine=xelatex \
  -V documentclass=article \
  --toc \
  --toc-depth=2

echo "Wrote $ROOT/DETF_LITEPAPAPER.pdf"
ls -la DETF_LITEPAPAPER.pdf
