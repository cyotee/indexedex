#!/usr/bin/env bash
# Sync canonical Crane skills into IndexedEx agent skill directories.
# Source of truth: lib/crane/.claude/skills/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/lib/crane/.claude/skills"
SKILLS=(
  crane-testing
  crane-deployment
  crane-architecture
  crane-code-style
  crane-natspec
  crane-access
  crane-utilities
  crane-adversarial-testing
  forge-testing
  forge-fuzz-testing
)
# Also mirror into Grok skill dirs when present.
DESTS=("$ROOT/.claude/skills" "$ROOT/.opencode/skills" "$ROOT/.grok/skills")
if [[ -d "$ROOT/lib/crane/.opencode/skills" ]]; then
  DESTS+=("$ROOT/lib/crane/.opencode/skills")
fi
if [[ -d "$ROOT/lib/crane/.grok/skills" ]]; then
  DESTS+=("$ROOT/lib/crane/.grok/skills")
fi

if [[ ! -d "$CANON" ]]; then
  echo "Missing canonical skills at $CANON" >&2
  exit 1
fi

for dest in "${DESTS[@]}"; do
  mkdir -p "$dest"
  for skill in "${SKILLS[@]}"; do
    if [[ -d "$CANON/$skill" ]]; then
      rm -rf "$dest/$skill"
      cp -R "$CANON/$skill" "$dest/$skill"
      echo "synced $skill -> $dest/"
    fi
  done
done
echo "Done. Canonical source remains: lib/crane/.claude/skills/"
