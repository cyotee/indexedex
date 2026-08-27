# Stage 05 — Dual SE CP hook → §15.12 (no DETF bind)

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **05** |
| **This file is the sole implementation scope** | Dual SE CP hook tree only |
| **Depends on** | **00**. Prefer **01** green if shared ABI still moving |
| **Blocks** | None for DETF. Stage **07** must still revert Dual as `PkgArgs.hook` |
| **Product law** | PRD §15.12, H12. `detfToken == address(0)`. `tokens()` has **no** DETF self-leg |
| **Package** | `contracts/hooks/uniswap/v4/standardExchange/dual/` |

---

## Goals

Same ABI as other hooks so a later DETF could bind. **This program does not bind it.** `requiredFirstBondTokens()` = both pair tokens. `firstJoinMustBeFullBook() == true`. `joinSingleAssetExactIn` reverts until `isLive()`.

`previewSynthetic` / `previewBurnToToken` still exist (ABI). With no DETF leg, `previewSynthetic` returns **0** if `ctx` names a DETF that is not in `tokens()` (H2). Do not invent Dual-as-DETF-reserve math here.

---

## Test match

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' -vv
```

| # | Test |
|---|------|
| T5.1 | `tokens()` has no DETF; two pairs; two SEs; AddressSets disjoint |
| T5.2 | Full-book first join both pairs; single-asset before live reverts |
| T5.3 | After live, single-asset join pair and share |
| T5.4 | Implements `IUniswapV4SeBufferHook` + `IDetfReserveQuote`; old names gone |
| T5.5 | Registry deploy; no `new` DFPkg |

DETF-bind revert is Stage **07** T7.x, not this stage.

---

## Acceptance

Shared ABI on Dual; match-path green; no DETF package edits.
