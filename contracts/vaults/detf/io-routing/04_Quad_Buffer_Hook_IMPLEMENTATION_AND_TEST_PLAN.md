# Stage 04 — Curve Quad SE buffer hook → §15.12

## Agent execution header

| Field | Value |
|-------|--------|
| **Stage ID** | **04** |
| **This file is the sole implementation scope** | Curve Quad SE buffer hook tree only |
| **Depends on** | **00**. Prefer **01** green if shared ABI still moving |
| **Blocks** | **08** |
| **Product law** | PRD §15.12, H4/H5/H10. `n = 4`. `baseAmp` stays family-only |
| **Package** | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` |

Same ABI migration as 01–03. `firstJoinMustBeFullBook() == true`. `requiredFirstBondTokens()` = all four `tokens()` addresses. After live, `joinSingleAssetExactIn` is allowed (PRD v0.14). Burn/redeem-to-token still **must not** use `exitSingleAsset*` / old `withdrawSingle`.

Do not edit `contracts/hooks/uniswap/v4/stable/quad/**` (non-SE quad) unless tests import it.

---

## Test match

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/**' -vv
```

| # | Test |
|---|------|
| T4.1 | `tokens().length == 4`; three SEs; AddressSets disjoint |
| T4.2 | Full-book first join; single-asset before live reverts |
| T4.3 | After live, single-asset join pair and share |
| T4.4 | `previewBurnToToken` uses prop exit + DETF rejoin; calling `exitSingleAsset*` from a DETF-shaped burn helper is not the production path |
| T4.5 | Deleted `withdrawSingle` on the required ABI (function may remain internally unused; must not be on `IUniswapV4SeBufferHook` wait: PRD §15.12 **keeps** `exitSingleAsset*` for ordinary LP). Assert old name `withdrawSingle` is gone; `exitSingleAssetExactBptIn` exists; DETF tests in 07/08 must not call it for burn |
| T4.6 | Registry deploy; no `new` DFPkg |

---

## Acceptance

Shared ABI; match-path green; no other-family edits.
