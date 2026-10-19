---
name: defisaver-public-transient-store
description: "Audit DeFi Saver recipe temp stores, ratio checkers and callbacks for cross-transaction pollution and mid-call overwrites."
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

# DeFi Saver public transient stores

## When to use

- Auditing **recipe/strategy** executors that share temp storage across actions
- **Ratio checkers** that read start values written by triggers
- **Callback swappers** that read exchange data from a public bytes store

## Bug classes

1. **Cross-tx pollution** — if store is a normal mapping (not true EIP-1153 transient), leftover keys affect later txs.
2. **Mid-tx overwrite** — public `set*` allows nested calls (reentrancy/hooks) to poison keys before checkers/swappers run.
3. **Inconsistent clear** — L1 vs L2 actions differ on clearing price/ratio keys after use.

## Review checklist

- [ ] Is storage true `tstore`/`tload` or a public mapping?
- [ ] Who can write? (public / only executor)
- [ ] Which actions write which keys? Which read?
- [ ] Is there a reentrancy host (ERC777, callbacks, nested recipes)?
- [ ] Do production strategies always re-write keys before read?
- [ ] Compare L1 vs L2 variants for missing clears

## PoC hints

- Prefer a **callback token** or mock action that, mid-recipe, calls public `setBytes32` / `setBytesTransiently`.
- Show checker pass after health worsened, or swap fill at attacker `minPrice`.
- Kill if no path without already controlling the full recipe callData.

## References

- DFS `TransientStorage.sol`, `BytesTransientStorage.sol`
- Triggers + `*RatioCheck` actions; `LimitSell` / `LimitSellL2`
