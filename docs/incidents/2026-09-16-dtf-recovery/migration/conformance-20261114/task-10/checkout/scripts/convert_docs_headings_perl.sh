#!/usr/bin/env bash
set -euo pipefail

# A more portable conversion script using perl to update inline labels to Markdown headings.
# Idempotent: if a file already contains the target heading it won't be duplicated.

DIR="docs/components"
tmpfile=""

for f in "$DIR"/*.md; do
  tmpfile=$(mktemp)
  perl -0777 -pe '
    # Skip if the exact heading already exists
    unless (/^#{1,6}\s*Intent/m) {
      s/^[ \t]*Intent[: \t]*(.*)$/## Intent\n- $1/mg;
      s/^## Intent\n-\s*$/## Intent/mg; # cleanup blank list
    }
    unless (/^#{1,6}\s*Proxy/m) {
      s/^[ \t]*-?[ \t]*Proxy[: \t]+(.*)$/## Proxy\n- $1/mg;
    }
    unless (/^#{1,6}\s*Facets/m) {
      s/^[ \t]*Facets[ \t\(\:].*$/## Facets/mg;
    }
    unless (/^#{1,6}\s*Trust boundaries/m) {
      s/^[ \t]*Trust boundaries?\s*(\(.*\))?[\s:-]*(.*)$/## Trust boundaries\n- $2/mg;
    }
    unless (/^#{1,6}\s*Initialization/m) {
      s/^[ \t]*Initialization[ \t\(].*$/## Initialization/mg;
      s/^[ \t]*initAccount\(\)[\s:-]*$/## Initialization (`initAccount()`)/mg;
    }
    unless (/^#{1,6}.*postDeploy/m) {
      s/^[ \t]*postDeploy\(\)[\s:-]*$/## postDeploy() \/ Post-deploy behavior/mg;
      s/^[ \t]*Post-deploy[\s:-]*$/## postDeploy() \/ Post-deploy behavior/mg;
    }
    unless (/^#{1,6}\s*Required tests/m) {
      s/^[ \t]*Required tests[: \t]*(.*)$/## Required tests\n- $1/mg;
    }
    unless (/^#{1,6}\s*Validation/m) {
      s/^[ \t]*Validation[: \t]*(.*)$/## Validation\n- $1/mg;
    }
  ' "$f" > "$tmpfile"

  mv "$tmpfile" "$f"
done

echo "Converted docs/components headings (perl best-effort)."
