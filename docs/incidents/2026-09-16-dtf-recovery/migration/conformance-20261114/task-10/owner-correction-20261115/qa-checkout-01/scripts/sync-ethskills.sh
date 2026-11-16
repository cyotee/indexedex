#!/usr/bin/env bash
# Mirror staged EthSkills from lib/ethskills/ into IndexedEx agent skill trees.
# Staging SoT: lib/ethskills/  (see lib/ethskills/SOURCE.md)
# Full Bankr catalog remains parent-workspace only (sync-bankr-skills.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/lib/ethskills"
DESTS=("$ROOT/.claude/skills" "$ROOT/.grok/skills" "$ROOT/.opencode/skills")

if [[ ! -d "$SRC" ]]; then
  echo "Missing $SRC" >&2
  exit 1
fi

for dest in "${DESTS[@]}"; do
  mkdir -p "$dest"
  for skill in "$SRC"/ethskills-*; do
    [[ -d "$skill" ]] || continue
    name="$(basename "$skill")"
    rm -rf "$dest/$name"
    cp -R "$skill" "$dest/$name"
    echo "synced $name -> $dest/"
  done
done
echo "Done. Staging SoT remains: lib/ethskills/"
