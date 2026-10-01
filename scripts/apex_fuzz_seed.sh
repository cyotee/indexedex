#!/usr/bin/env bash
# APEX 2026-09-17 / R11.6: run the APEX fuzz/invariant campaigns under a PINNED seed for
# reproducible evidence, and retain any counterexample from the gitignored cache/ trees.
# Default `forge test` stays unseeded (rotating) so hermetic runs keep exploring; the seed
# is pinned only here, at invocation, via the environment (never in foundry.toml).
#
# forge 1.5.1 REJECTS repeated --match-path on a single invocation, so each match-path glob
# is run as its own `forge test` invocation (one glob per invocation) under the same seed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
SEED="${APEX_FUZZ_SEED:-0x4150455832303236}"   # "APEX2026" — recorded in evidence
EV=docs/audits/apex-2026-09-17-evidence
mkdir -p "$EV/fuzz-counterexamples"
export FOUNDRY_FUZZ_SEED="$SEED"                # applies to fuzz AND invariant campaigns

# Invariant campaigns (property suites). Each entry is a single match-path glob run alone.
MATCH_PATHS=(
  'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/invariant/*_Invariant.t.sol'
  'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/invariants/*_Invariant.t.sol'
)

echo "== APEX fuzz/invariant campaign, seed=$SEED, $(forge --version | head -1)"
RC=0
for GLOB in "${MATCH_PATHS[@]}"; do
  # Slug for a per-glob log file name.
  SLUG=$(printf '%s' "$GLOB" | tr '/*.' '___' | tr -s '_')
  LOG="$EV/fuzz-invariant-${SEED}-${SLUG}.log"
  echo "== forge test --match-path '$GLOB'"
  set +e
  forge test --match-path "$GLOB" -vvv | tee "$LOG"
  GRC=${PIPESTATUS[0]}
  set -e
  [ "$GRC" -ne 0 ] && RC="$GRC"
done

# Retain replay/counterexample files (cache/ is gitignored) as committed evidence.
[ -d cache/fuzz ]      && rsync -a cache/fuzz/      "$EV/fuzz-counterexamples/fuzz/"      || true
[ -d cache/invariant ] && rsync -a cache/invariant/ "$EV/fuzz-counterexamples/invariant/" || true
echo "$SEED" > "$EV/fuzz-seed.txt"
echo "== done rc=$RC; counterexamples (if any) under $EV/fuzz-counterexamples/"
exit "$RC"
