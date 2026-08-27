# Stage 03 — Weighted SE buffer hook → §15.12

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **03** |
| **This file is the sole implementation scope** | Weighted SE **buffer** hook tree only |
| **Depends on** | **00**. Prefer **01** green if shared ABI still moving |
| **Blocks** | **08** |
| **Product law** | PRD §15.12, §15.12.1, H4/H5, H8 (per-path synthetic; expansion all-legs-rich is DETF-side) |
| **Package** | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |

Same as Stage 01/02. `n ∈ [2, 8]`. `firstJoinMustBeFullBook() == true`. `requiredFirstBondTokens()` = full `tokens()`. Family weights stay on this package’s interface; **do not** duplicate §15.12 signatures.

**Do not** edit `contracts/hooks/uniswap/v4/weighted/` (non-SE weighted swap hook).

---

## Test match

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**' -vv
```

| # | Test |
|---|------|
| T3.1 | AddressSets disjoint; every non-DETF `tokens()[i]` has `standardExchangeOf != 0` |
| T3.2 | Full-book first join; single-asset before live reverts |
| T3.3 | After live, `joinSingleAssetExactIn` pair and share per external leg |
| T3.4 | Same-leg pair+share unbalanced reverts |
| T3.5 | `previewSynthetic(ctx, each pair)` |
| T3.6 | `previewBurnToToken`; H10 |
| T3.7 | Deleted `join*Flexible` / `depositSingle` selectors absent |
| T3.8 | Registry deploy; no `new` DFPkg |

---

## Acceptance

Implements shared ABI; match-path green; no other-family edits.
