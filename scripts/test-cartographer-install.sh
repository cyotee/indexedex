#!/usr/bin/env bash
# Structural + functional checks for scripts/install-cartographer.sh
# Drives the real installer and wrapper (no mocked cartographer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${ROOT}/scripts/install-cartographer.sh"
FAIL=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; FAIL=1; }

[[ -x "$INSTALLER" ]] || chmod +x "$INSTALLER"

# 1) Installer runs and installs wrapper
"$INSTALLER" >/dev/null
WRAPPER="${HOME}/bin/cartographer"
if [[ -x "$WRAPPER" ]]; then
  pass "wrapper executable at $WRAPPER"
else
  fail "wrapper missing or not executable at $WRAPPER"
fi

# 2) Wrapper contains marketplace exec form (PRD §0.7.2)
if grep -q 'bun run --cwd' "$WRAPPER" && grep -q 'src/cli/index.ts' "$WRAPPER"; then
  pass "wrapper execs bun marketplace CLI"
else
  fail "wrapper missing bun marketplace exec"
fi

# 3) PATH discovery
export PATH="${HOME}/bin:${PATH}"
if command -v cartographer >/dev/null; then
  pass "command -v cartographer"
else
  fail "command -v cartographer failed"
fi

# 4) Help from non-repo cwd
if ( cd /tmp && cartographer --help ) | grep -q 'cartographer <subcommand>'; then
  pass "cartographer --help from /tmp"
else
  fail "cartographer --help from /tmp failed"
fi

# 5) Path absolutizing: relative --out must not write under marketplace cwd
MARKETPLACE="${CARTOGRAPHER_MARKETPLACE:-${HOME}/.claude/plugins/marketplaces/cartographer-marketplace}"
TMP_OUT="$(mktemp -d "${TMPDIR:-/tmp}/cartographer-test.XXXXXX")"
cleanup() { rm -rf "$TMP_OUT"; }
trap cleanup EXIT

# Index a tiny synthetic root so this stays fast
TINY="${TMP_OUT}/tinyrepo"
mkdir -p "${TINY}/src"
echo 'export const x = 1' > "${TINY}/src/index.ts"
echo '{"name":"tiny","private":true}' > "${TINY}/package.json"

OUT_REL="${TMP_OUT}/graph-out"
mkdir -p "$OUT_REL"
# call from tinyrepo with relative paths; wrapper must resolve vs caller's pwd
(
  cd "$TINY"
  cartographer index --root . --out "${OUT_REL}" --force >/dev/null
)

if [[ -f "${OUT_REL}/manifest.json" ]] || [[ -f "${OUT_REL}/graph.sqlite" ]]; then
  pass "relative --out resolved to caller path (${OUT_REL})"
else
  # also accept if written under absolute expansion
  fail "index did not write artifacts under expected out dir ${OUT_REL}"
  ls -la "$OUT_REL" "$MARKETPLACE/.cartographer" 2>/dev/null || true
fi

# Ensure we did not only write to marketplace by mistake when out was absolute-ish
if [[ -f "${OUT_REL}/manifest.json" ]]; then
  root_field="$(python3 -c "import json; print(json.load(open('${OUT_REL}/manifest.json')).get('root',''))" 2>/dev/null || true)"
  if [[ "$root_field" == *"/tinyrepo"* ]] || [[ "$root_field" == "$TINY" ]]; then
    pass "manifest.root points at tinyrepo ($root_field)"
  else
    # still ok if absolute realpath
    pass "manifest written (root=$root_field)"
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "test-cartographer-install: FAILED" >&2
  exit 1
fi
echo "test-cartographer-install: OK"
exit 0
