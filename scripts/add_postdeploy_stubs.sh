#!/usr/bin/env bash
set -euo pipefail

# Append a postDeploy() / Post-deploy behavior stub to docs/components/*.md
# when the heading is missing. Files are modified in-place. Idempotent.

DIR="docs/components"
for f in "$DIR"/*.md; do
  if ! grep -Eq '^#{1,6}[[:space:]]*postDeploy' "$f"; then
    printf "\n## postDeploy() / Post-deploy behavior\n- PENDING-MAINTAINER-REVIEW\n" >> "$f"
    echo "Added stub to: $(basename "$f")"
  fi
done

echo "Done. Added postDeploy stubs where missing."
