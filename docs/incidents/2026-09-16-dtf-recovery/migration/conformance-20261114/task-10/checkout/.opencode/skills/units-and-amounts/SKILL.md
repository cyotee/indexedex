---
name: units-and-amounts
description: "Convert token amounts exactly using token decimals and integer/decimal arithmetic before approvals, transfers or swaps."
---

## IndexedEx integration (2026-10-19)

Read the repository `CLAUDE.md` and the relevant Crane/IndexedEx skill before
using this topic. Current product law, registry/CREATE3 deployment, production-first
tests, build-before-test ordering and configured Foundry profiles override generic
examples. This archive-derived guide does not authorize broadcasts, dependency
installs, new product integrations or restoration of retired protocol families.
Use current deployment artifacts and the pinned frontend/tool versions; archived
addresses and API samples are not live verification. Resolve topic names through
`scripts/codex-skill-catalog.json` when they are grouped behind routers.

# Units and amounts (cast)

## Safety
Prefer read-only first; require user confirmation for any write.

## Verify
Re-check state after any write; confirm receipts when broadcasting.


## Goal
Convert between human-readable amounts and on-chain raw units.

## Recipes
```bash
cast to-wei 1.5 ether
cast from-wei 1500000000000000000

python3 - <<'PY'
from decimal import Decimal
decimals = 6
human = Decimal("12.5")
raw = human * (Decimal(10) ** decimals)
if raw != raw.to_integral_value():
    raise ValueError("Amount exceeds token precision")
print(int(raw))
PY
```

## Agent rules
1. Always read `decimals()` for the token.
2. Never pass human floats into cast send args without conversion.
3. Slippage mins use the same raw unit space as amounts out.
