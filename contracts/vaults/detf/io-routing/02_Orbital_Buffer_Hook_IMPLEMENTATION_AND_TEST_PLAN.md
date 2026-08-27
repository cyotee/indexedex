# Stage 02 — Orbital SE buffer hook → §15.12

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **02** |
| **This file is the sole implementation scope** | Orbital SE **buffer** hook tree only |
| **Depends on** | **00**. Prefer **01** green if shared ABI still moving |
| **Blocks** | **08** (DETF matrix) |
| **Product law** | PRD §15.12, §15.12.1, H4/H5 (full book), H8, H10 |
| **Package** | `contracts/hooks/uniswap/v4/standardExchange/orbital/` |

Same goals as Stage 01, for this package: `n = 3` (`tokens()` = DETF + two pairs), two `standardExchangeOf` values, disjoint AddressSets, no two pairs sharing one SE.

**Do not** edit `contracts/hooks/uniswap/v4/orbital/` (non-SE orbital swap hook) unless a test import forces it; this stage is the **SE buffer** package.

---

## Files

All product files under `contracts/hooks/uniswap/v4/standardExchange/orbital/`. Tests:

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/**' -vv
```

---

## Tests (minimum)

| # | Test |
|---|------|
| T2.1 | `tokens().length == 3`; two SEs; AddressSets disjoint |
| T2.2 | `firstJoinMustBeFullBook() == true`; `requiredFirstBondTokens()` = all three |
| T2.3 | `joinSingleAssetExactIn` before live reverts |
| T2.4 | First `joinUnbalanced` all legs (pair or share per external leg + DETF) → live |
| T2.5 | After live, single-asset join of pair0, pair1, share0, share1 |
| T2.6 | Same-leg pair+share in one unbalanced join reverts |
| T2.7 | `previewSynthetic(ctx, pair0)` and `(ctx, pair1)` (H8 per-path) |
| T2.8 | `previewBurnToToken` prop+rejoin DETF; no `exitSingleAsset*` on that path |
| T2.9 | Deleted `addLiquidity`/`removeLiquidity`/`depositSingle` selectors absent |
| T2.10 | Registry/hook-factory deploy; no `new` DFPkg |

---

## Acceptance

- [ ] Implements shared interfaces; old public names gone.
- [ ] Match-path tests green. Stage 00 still green.
- [ ] No CP/Weighted/Quad/Dual/DETF file edits.
