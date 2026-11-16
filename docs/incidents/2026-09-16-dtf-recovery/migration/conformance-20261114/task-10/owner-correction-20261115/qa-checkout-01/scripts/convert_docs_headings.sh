#!/usr/bin/env bash
set -eu

# Convert inline labels in docs/components/*.md into proper Markdown headings.
# This script rewrites files in-place. It is idempotent and makes a best-effort
# conversion for the reviewer-required section headings.

DIR="docs/components"
shopt -s nullglob

for f in "$DIR"/*.md; do
  tmp=$(mktemp)
  awk '
  function emit_header(h, rest) {
    # print header line
    print "## " h
    if (rest != "") {
      # if there is trailing content, print as a list item on the next line
      print "- " rest
    }
  }

  { line = $0 }

  # normalize checks: detect common inline labels and replace with headings
  if (match(line, /^[ \t]*Intent[: ]*$/)) {
    emit_header("Intent", "")
    next
  }
  if (match(line, /^[ \t]*Intent[: ]*(.*)$/)) {
    # catch rare cases with trailing text
    emit_header("Intent", substr(line, RSTART+RLENGTH-RLENGTH))
    next
  }
  if (match(line, /^[ \t]*Trust boundaries?([ \t\(].*)?$/)) {
    # keep the rest of the line (e.g. "(`processArgs()`)")
    rest = substr(line, RSTART+13)
    gsub(/^[ \t]+/, "", rest)
    emit_header("Trust boundaries" (rest?" "rest:""), "")
    next
  }
  if (match(line, /^[ \t]*Trust boundaries.*$/)) {
    emit_header("Trust boundaries", substr(line, RSTART+RLENGTH-RLENGTH))
    next
  }
  if (match(line, /^[ \t]*Initialization[ \t\(].*$/) || match(line, /^[ \t]*initAccount\(\)/)) {
    # print Initialization header
    # include the original parentheses if present
    hdr = "Initialization"
    if (match(line, /initAccount\(\)/)) hdr = hdr " (`initAccount()` )"
    print "## " hdr
    next
  }
  if (match(line, /^[ \t]*postDeploy\(\)/) || match(line, /^[ \t]*Post-deploy/)) {
    print "## postDeploy() / Post-deploy behavior"
    next
  }
  if (match(line, /^[ \t]*Required tests[: ]*$/)) {
    print "## Required tests"
    next
  }
  if (match(line, /^[ \t]*Validation[: ]*$/)) {
    print "## Validation"
    next
  }
  if (match(line, /^[ \t]*Facets([ \t\(].*)?$/) || match(line, /^[ \t]*Facets\s*[:]?/)) {
    # unify to 'Facets' header (preserve parenthetical suffix if present)
    m = line
    print "## Facets"
    next
  }
  if (match(line, /^[ \t]*-?[ \t]*Proxy[: ]+(.*)$/)) {
    # convert "- Proxy: X" into header + list item
    proxyRest = gensub(/^[ \t]*-?[ \t]*Proxy[: ]+(.*)$/, "\\1", 1, line)
    print "## Proxy"
    print "- " proxyRest
    next
  }

  { print line }

  ' "$f" > "$tmp"
  mv "$tmp" "$f"
done

echo "Converted docs/components headings (best-effort)."
